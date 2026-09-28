import { BookingStatus, Prisma, Role } from '@prisma/client';
import { prisma } from '../config/database';
import { AppError } from '../common/dto/api-response';
import { availabilityService, nowInZone } from '../availability/availability.service';
import { formatTime, parseTime } from '../availability/availability.engine';
import { CreateBookingInput, normalizePhone } from './booking.dto';
import { computePrice } from './booking.money';
import { zonedWallTimeToUtc } from './booking.time';
import { NotificationType, notificationService } from '../notifications/notification.service';

/**
 * BOOKING STATE MACHINE
 *
 *   PENDING   -> CONFIRMED | REJECTED | CANCELLED
 *   CONFIRMED -> CANCELLED | COMPLETED
 *   REJECTED, CANCELLED, COMPLETED are terminal.
 *
 * Every transition is a compare-and-set (UPDATE ... WHERE id AND status = <expected>), so two
 * concurrent actions on one booking cannot both succeed.
 *
 * CANCELLATION RULES (MVP, documented):
 *   - The client may cancel a PENDING booking at any time.
 *   - The client may cancel a CONFIRMED booking only while the event starts MORE than
 *     CANCELLATION_WINDOW_HOURS (24h) from now; inside that window the request is refused (409) and
 *     the client must contact the Oduvar.
 *   - CANCELLED is terminal: a cancelled booking can never become CONFIRMED again.
 *   - Oduvars decline requests with "reject" (PENDING only). Oduvar-initiated cancellation of a
 *     confirmed booking is not part of this phase.
 *
 * DOUBLE-BOOKING PROTECTION
 *   PENDING bookings occupy nothing. Only CONFIRMED bookings block time. Confirming runs in one
 *   transaction that (1) takes a per-Oduvar Postgres advisory lock, (2) re-reads the booking and
 *   asserts it is still PENDING, (3) re-runs the Phase 4 availability engine (working hours,
 *   overrides, buffer, other CONFIRMED bookings), and (4) flips the status. The lock serialises
 *   concurrent accepts for the same Oduvar, so the loser sees the winner's committed booking and fails
 *   with 409. A partial exclusion constraint on bookings (see the phase 6 migration) is the last
 *   line of defence at the database level.
 */
export const CANCELLATION_WINDOW_HOURS = 24;

const TRANSITIONS: Record<BookingStatus, BookingStatus[]> = {
  PENDING: ['CONFIRMED', 'REJECTED', 'CANCELLED'],
  CONFIRMED: ['CANCELLED', 'COMPLETED'],
  REJECTED: [],
  CANCELLED: [],
  COMPLETED: [],
};

export function assertTransition(from: BookingStatus, to: BookingStatus) {
  if (!TRANSITIONS[from].includes(to)) {
    throw new AppError('INVALID_STATUS_TRANSITION', `A ${from} booking cannot become ${to}`, 409);
  }
}

const bookingInclude = {
  client: { select: { id: true, name: true } },
  oduvar: { select: { id: true, name: true, profilePhoto: true } },
} as const;
type BookingRow = Prisma.BookingGetPayload<{ include: typeof bookingInclude }>;

const dateKey = (d: Date) => d.toISOString().slice(0, 10);
const num = (d: Prisma.Decimal | null) => (d === null ? null : Number(d));

/**
 * Serialised booking. Display values come ONLY from the stored snapshot, never from the Oduvar's
 * current service/pricing. phone1/phone2 are private: this DTO is only ever returned to the booking's
 * own client or Oduvar (see the ownership checks below) and never by public/discovery APIs.
 */
export function toBookingDto(b: BookingRow) {
  const total = b.totalAmountSnapshot;
  return {
    id: b.id,
    status: b.status,
    statusReason: b.statusReason,
    oduvar: { id: b.oduvar.id, name: b.oduvar.name, profilePhoto: b.oduvar.profilePhoto },
    client: { id: b.client.id, name: b.client.name },
    service: { id: b.oduvarServiceId, name: b.serviceNameSnapshot },
    date: dateKey(b.date),
    startTime: b.startTime,
    endTime: b.endTime,
    durationMinutes: b.durationSnapshot ?? b.duration,
    timezone: b.timezone,
    eventType: b.eventType,
    songType: b.songType,
    description: b.description,
    eventLocation: b.location,
    phone1: b.phone1,
    phone2: b.phone2,
    transport: { option: b.transportSnapshot ?? b.transport, fee: num(b.transportFeeSnapshot) },
    price: {
      serviceAmount: num(b.serviceAmountSnapshot),
      transportFee: num(b.transportFeeSnapshot),
      totalAmount: num(total),
      totalKnown: total !== null,
      currency: b.currencySnapshot ?? 'INR',
    },
    createdAt: b.createdAt,
    updatedAt: b.updatedAt,
    confirmedAt: b.confirmedAt,
    rejectedAt: b.rejectedAt,
    cancelledAt: b.cancelledAt,
    completedAt: b.completedAt,
  };
}

function isOverlapViolation(e: unknown): boolean {
  const msg = String((e as { message?: string })?.message ?? '');
  return msg.includes('bookings_no_overlapping_confirmed') || msg.includes('23P01');
}

const whenLabel = (b: { date: Date; startTime: string }) => `${dateKey(b.date)} at ${b.startTime}`;

export class BookingService {
  // ─── Create ───────────────────────────────────────────────────────────────

  async create(clientId: string, input: CreateBookingInput, now: Date = new Date()) {
    // 1. Oduvar exists and is published
    const profile = await prisma.oduvarProfile.findFirst({
      where: { userId: input.oduvarId, isPublished: true, user: { role: Role.ODUVAR } },
    });
    if (!profile) throw new AppError('NOT_FOUND', 'Oduvar not found or not accepting bookings', 404);

    // 2. Service belongs to this Oduvar and is active
    const oduvarService = await prisma.oduvarService.findFirst({
      where: { id: input.oduvarServiceId, profileId: profile.id },
      include: { service: true },
    });
    if (!oduvarService) throw new AppError('SERVICE_NOT_FOUND', 'This Oduvar does not offer that service', 400);
    if (!oduvarService.isActive || !oduvarService.service.isActive) {
      throw new AppError('SERVICE_INACTIVE', 'This service is not currently available for booking', 400);
    }

    // 3. Pricing belongs to that service and is active; duration must match it exactly
    const pricing = await prisma.servicePricing.findFirst({
      where: { id: input.servicePricingId, oduvarServiceId: oduvarService.id },
    });
    if (!pricing) throw new AppError('PRICING_NOT_FOUND', 'That price option does not belong to the selected service', 400);
    if (!pricing.isActive) throw new AppError('PRICING_INACTIVE', 'That price option is no longer offered', 400);
    if (pricing.durationMinutes !== input.durationMinutes) {
      throw new AppError('INVALID_DURATION', 'Duration does not match the selected price option', 400);
    }

    // 4. The transport terms the client saw must still be the Oduvar's current terms
    if (input.transport !== oduvarService.transport) {
      throw new AppError('TRANSPORT_TERMS_CHANGED', 'The Oduvar has changed the transport terms. Please review and try again.', 409);
    }

    // 5. Date / time validity in the Oduvar's timezone
    const nowZ = nowInZone(profile.timezone, now);
    if (input.date < nowZ.date) throw new AppError('PAST_DATE', 'The event date is in the past', 400);
    const startMin = parseTime(input.startTime);
    const endMin = startMin + input.durationMinutes;

    // 6. Availability: working hours / overrides / buffer (base), then confirmed bookings
    const baseSlots = await availabilityService.getAvailableSlots(profile.id, input.date, input.durationMinutes, [], now, {
      ignoreBookings: true,
    });
    if (!baseSlots.includes(input.startTime)) {
      throw new AppError('SLOT_NOT_AVAILABLE', 'The Oduvar is not available at that date and time', 400);
    }
    const openSlots = await availabilityService.getAvailableSlots(profile.id, input.date, input.durationMinutes, [], now);
    if (!openSlots.includes(input.startTime)) {
      throw new AppError('BOOKING_CONFLICT', 'That time is no longer available (another booking is confirmed nearby)', 409);
    }

    // 7. The same client may not stack a second active request on the same Oduvar for an overlapping time
    const sameDay = await prisma.booking.findMany({
      where: {
        clientId,
        oduvarId: input.oduvarId,
        date: new Date(`${input.date}T00:00:00Z`),
        status: { in: ['PENDING', 'CONFIRMED'] },
      },
      select: { startTime: true, duration: true },
    });
    if (sameDay.some((b) => parseTime(b.startTime) < endMin && startMin < parseTime(b.startTime) + b.duration)) {
      throw new AppError('DUPLICATE_BOOKING', 'You already have an active request with this Oduvar at that time', 409);
    }

    // 8. Price comes ONLY from server-side rows
    const price = computePrice(pricing.amount, oduvarService.transport, oduvarService.transportFee, pricing.currency);

    const startsAt = zonedWallTimeToUtc(input.date, startMin, profile.timezone);
    const endsAt = zonedWallTimeToUtc(input.date, endMin, profile.timezone);
    const eventDate = new Date(`${input.date}T00:00:00Z`);

    return prisma.$transaction(async (tx) => {
      const booking = await tx.booking.create({
        data: {
          clientId,
          oduvarId: input.oduvarId,
          serviceId: oduvarService.serviceId,
          pricingId: pricing.id,
          oduvarServiceId: oduvarService.id,
          // price snapshot
          serviceNameSnapshot: oduvarService.service.name,
          durationSnapshot: pricing.durationMinutes,
          serviceAmountSnapshot: price.serviceAmount,
          transportSnapshot: oduvarService.transport,
          transportFeeSnapshot: price.transportFee,
          totalAmountSnapshot: price.totalAmount,
          currencySnapshot: price.currency,
          serviceAmount: price.serviceAmount,
          transportFee: price.transportFee,
          totalAmount: price.totalAmount,
          currency: price.currency,
          // when
          date: eventDate,
          startTime: input.startTime,
          endTime: formatTime(endMin),
          duration: input.durationMinutes,
          timezone: profile.timezone,
          startsAt,
          endsAt,
          blocksUntil: new Date(endsAt.getTime() + profile.bufferMinutes * 60_000),
          // details
          songType: input.songType?.trim() || oduvarService.service.category,
          eventType: input.eventType,
          description: input.description,
          location: input.eventLocation,
          phone1: normalizePhone(input.phone1),
          phone2: input.phone2 ? normalizePhone(input.phone2) : null,
          transport: oduvarService.transport,
          status: 'PENDING',
        },
        include: bookingInclude,
      });
      const data = { bookingId: booking.id };
      await notificationService.create(tx, clientId, NotificationType.BOOKING_REQUEST_SENT, 'Booking request sent',
        `Your request for ${oduvarService.service.name} on ${whenLabel(booking)} was sent to ${booking.oduvar.name}.`, data);
      await notificationService.create(tx, input.oduvarId, NotificationType.BOOKING_REQUESTED, 'New booking request',
        `${booking.client.name} requested ${oduvarService.service.name} on ${whenLabel(booking)}.`, data);
      return toBookingDto(booking);
    });
  }

  // ─── Reads ────────────────────────────────────────────────────────────────

  private async list(where: Prisma.BookingWhereInput, statuses: string[] | undefined, page: number, pageSize: number) {
    const w: Prisma.BookingWhereInput = { ...where, ...(statuses ? { status: { in: statuses as BookingStatus[] } } : {}) };
    const [items, total] = await Promise.all([
      prisma.booking.findMany({
        where: w,
        include: bookingInclude,
        orderBy: [{ date: 'desc' }, { startTime: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      prisma.booking.count({ where: w }),
    ]);
    return { items: items.map(toBookingDto), page, pageSize, total, hasNext: page * pageSize < total };
  }

  listForClient(clientId: string, statuses: string[] | undefined, page: number, pageSize: number) {
    return this.list({ clientId }, statuses, page, pageSize);
  }

  listForOduvar(oduvarUserId: string, statuses: string[] | undefined, page: number, pageSize: number) {
    return this.list({ oduvarId: oduvarUserId }, statuses, page, pageSize);
  }

  async getForClient(clientId: string, bookingId: string) {
    const b = await prisma.booking.findFirst({ where: { id: bookingId, clientId }, include: bookingInclude });
    if (!b) throw new AppError('NOT_FOUND', 'Booking not found', 404); // 404, not 403: don't reveal others' bookings
    return toBookingDto(b);
  }

  async getForOduvar(oduvarUserId: string, bookingId: string) {
    const b = await prisma.booking.findFirst({ where: { id: bookingId, oduvarId: oduvarUserId }, include: bookingInclude });
    if (!b) throw new AppError('NOT_FOUND', 'Booking not found', 404);
    return toBookingDto(b);
  }

  // ─── Oduvar: accept (atomic, re-checks availability) ──────────────────────

  async accept(oduvarUserId: string, bookingId: string, now: Date = new Date()) {
    const existing = await prisma.booking.findFirst({ where: { id: bookingId, oduvarId: oduvarUserId } });
    if (!existing) throw new AppError('NOT_FOUND', 'Booking not found', 404);
    const profile = await prisma.oduvarProfile.findUnique({ where: { userId: oduvarUserId } });
    if (!profile) throw new AppError('NOT_FOUND', 'Oduvar profile not found', 404);

    try {
      return await prisma.$transaction(
        async (tx) => {
          // Serialise every accept for this Oduvar. Released automatically at commit/rollback.
          await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${'booking-confirm:' + profile.id}))`;

          const fresh = await tx.booking.findUniqueOrThrow({ where: { id: bookingId } });
          assertTransition(fresh.status, 'CONFIRMED');

          // Re-check with the Phase 4 engine against everything committed so far (incl. other CONFIRMED bookings).
          const dateStr = dateKey(fresh.date);
          const slots = await availabilityService.getAvailableSlots(profile.id, dateStr, fresh.duration, [], now);
          if (!slots.includes(fresh.startTime)) {
            throw new AppError('BOOKING_CONFLICT', 'This time is no longer available: it conflicts with another confirmed booking or the current schedule', 409);
          }

          const startMin = parseTime(fresh.startTime);
          const startsAt = zonedWallTimeToUtc(dateStr, startMin, profile.timezone);
          const endsAt = zonedWallTimeToUtc(dateStr, startMin + fresh.duration, profile.timezone);
          const res = await tx.booking.updateMany({
            where: { id: bookingId, status: 'PENDING' },
            data: {
              status: 'CONFIRMED',
              confirmedAt: now,
              timezone: profile.timezone,
              startsAt,
              endsAt,
              blocksUntil: new Date(endsAt.getTime() + profile.bufferMinutes * 60_000),
            },
          });
          if (res.count !== 1) throw new AppError('INVALID_STATUS_TRANSITION', 'The booking is no longer pending', 409);

          const b = await tx.booking.findUniqueOrThrow({ where: { id: bookingId }, include: bookingInclude });
          await notificationService.create(tx, b.clientId, NotificationType.BOOKING_CONFIRMED, 'Booking confirmed',
            `${b.oduvar.name} accepted your booking on ${whenLabel(b)}.`, { bookingId });
          return toBookingDto(b);
        },
        { timeout: 15_000, maxWait: 15_000 }
      );
    } catch (e) {
      if (isOverlapViolation(e)) throw new AppError('BOOKING_CONFLICT', 'This time overlaps another confirmed booking', 409);
      throw e;
    }
  }

  // ─── Generic compare-and-set transition ───────────────────────────────────

  private async transition(
    where: Prisma.BookingWhereInput,
    bookingId: string,
    to: BookingStatus,
    extra: Prisma.BookingUpdateManyMutationInput,
    guard: (b: Prisma.BookingGetPayload<object>) => void,
    notify: (tx: Prisma.TransactionClient, b: BookingRow) => Promise<void>
  ) {
    const found = await prisma.booking.findFirst({ where: { id: bookingId, ...where } });
    if (!found) throw new AppError('NOT_FOUND', 'Booking not found', 404);
    assertTransition(found.status, to);
    guard(found);
    return prisma.$transaction(async (tx) => {
      const res = await tx.booking.updateMany({ where: { id: bookingId, status: found.status }, data: { status: to, ...extra } });
      if (res.count !== 1) throw new AppError('INVALID_STATUS_TRANSITION', 'The booking status changed; please refresh', 409);
      const b = await tx.booking.findUniqueOrThrow({ where: { id: bookingId }, include: bookingInclude });
      await notify(tx, b);
      return toBookingDto(b);
    });
  }

  reject(oduvarUserId: string, bookingId: string, reason?: string, now: Date = new Date()) {
    return this.transition(
      { oduvarId: oduvarUserId }, bookingId, 'REJECTED', { rejectedAt: now, statusReason: reason ?? null }, () => {},
      async (tx, b) => {
        await notificationService.create(tx, b.clientId, NotificationType.BOOKING_REJECTED, 'Booking declined',
          `${b.oduvar.name} could not accept your booking on ${whenLabel(b)}.${reason ? ` Reason: ${reason}` : ''}`, { bookingId });
      }
    );
  }

  complete(oduvarUserId: string, bookingId: string, now: Date = new Date()) {
    return this.transition(
      { oduvarId: oduvarUserId }, bookingId, 'COMPLETED', { completedAt: now },
      (b) => {
        // "Completed" means the event has happened: only once its start time has passed.
        if (b.startsAt && b.startsAt.getTime() > now.getTime()) {
          throw new AppError('EVENT_NOT_STARTED', 'A booking can only be completed after the event has started', 409);
        }
      },
      async (tx, b) => {
        await notificationService.create(tx, b.clientId, NotificationType.BOOKING_COMPLETED, 'Booking completed',
          `Your booking with ${b.oduvar.name} on ${whenLabel(b)} is complete.`, { bookingId });
      }
    );
  }

  cancelByClient(clientId: string, bookingId: string, reason?: string, now: Date = new Date()) {
    return this.transition(
      { clientId }, bookingId, 'CANCELLED', { cancelledAt: now, statusReason: reason ?? null },
      (b) => {
        if (b.status === 'CONFIRMED') {
          const limit = CANCELLATION_WINDOW_HOURS * 3_600_000;
          if (!b.startsAt || b.startsAt.getTime() - now.getTime() <= limit) {
            throw new AppError(
              'CANCELLATION_WINDOW_CLOSED',
              `A confirmed booking can only be cancelled more than ${CANCELLATION_WINDOW_HOURS} hours before it starts. Please contact the Oduvar.`,
              409
            );
          }
        }
      },
      async (tx, b) => {
        await notificationService.create(tx, b.oduvarId, NotificationType.BOOKING_CANCELLED, 'Booking cancelled by client',
          `${b.client.name} cancelled the booking on ${whenLabel(b)}.`, { bookingId });
        await notificationService.create(tx, b.clientId, NotificationType.BOOKING_CANCELLED, 'Booking cancelled',
          `You cancelled your booking with ${b.oduvar.name} on ${whenLabel(b)}.`, { bookingId });
      }
    );
  }
}

export const bookingService = new BookingService();
