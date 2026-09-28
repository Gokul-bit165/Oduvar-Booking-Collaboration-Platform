import { DayOfWeek, OduvarProfile, OverrideType } from '@prisma/client';
import { prisma } from '../config/database';
import { AppError } from '../common/dto/api-response';
import {
  Interval,
  OverrideRule,
  formatTime,
  getAvailableSlots,
  parseTime,
  resolveWindowsForDate,
} from './availability.engine';
import { OverrideInput, UpdateWeeklyInput } from './availability.dto';

const DAYS: DayOfWeek[] = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];

/**
 * Calendar day states. PENDING and BOOKED are reserved for Phase 6 (bookings);
 * this phase only ever emits AVAILABLE / UNAVAILABLE.
 */
export type DayStatus = 'AVAILABLE' | 'UNAVAILABLE' | 'PENDING' | 'BOOKED';

/**
 * Hook for the future booking engine: return the intervals already occupied on
 * `date` (YYYY-MM-DD, Oduvar's schedule timezone) for this Oduvar. Phase 4 has no
 * bookings so nothing is occupied. Phase 6 replaces this with a real query.
 */
export type OccupiedIntervalProvider = (profileId: string, date: string) => Promise<Interval[]>;
let occupiedProvider: OccupiedIntervalProvider = async () => [];
export function setOccupiedIntervalProvider(p: OccupiedIntervalProvider) {
  occupiedProvider = p;
}

/** Day of week for a calendar date. The date is timezone-independent (a calendar date), so UTC math is safe. */
export function dayOfWeekFor(date: string): DayOfWeek {
  const d = new Date(`${date}T00:00:00Z`).getUTCDay(); // 0 = Sunday
  return DAYS[(d + 6) % 7];
}

/** "Now" as a calendar date + minute-of-day in the given IANA timezone. */
export function nowInZone(timezone: string, now: Date = new Date()): { date: string; minutes: number } {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const get = (t: string) => parts.find((p) => p.type === t)!.value;
  return {
    date: `${get('year')}-${get('month')}-${get('day')}`,
    minutes: Number(get('hour')) * 60 + Number(get('minute')),
  };
}

const toDbDate = (d: string) => new Date(`${d}T00:00:00Z`);
const fromDbDate = (d: Date) => d.toISOString().slice(0, 10);

interface WeeklyRow {
  dayOfWeek: DayOfWeek;
  startTime: string;
  endTime: string;
  isActive: boolean;
}
interface OverrideRow {
  id: string;
  date: Date;
  type: OverrideType;
  startTime: string | null;
  endTime: string | null;
  reason: string | null;
}

export class AvailabilityService {
  // ─── Profile helpers ──────────────────────────────────────────────────────

  private async ownProfile(userId: string): Promise<OduvarProfile> {
    const existing = await prisma.oduvarProfile.findUnique({ where: { userId } });
    if (existing) return existing;
    return prisma.oduvarProfile.create({ data: { userId, isPublished: false } });
  }

  private async publicProfile(oduvarUserId: string): Promise<OduvarProfile> {
    const profile = await prisma.oduvarProfile.findUnique({ where: { userId: oduvarUserId } });
    if (!profile || !profile.isPublished) {
      throw new AppError('NOT_FOUND', 'Oduvar profile not found or not published', 404);
    }
    return profile;
  }

  private rules(p: OduvarProfile) {
    return {
      minimumDurationMinutes: p.minimumDurationMinutes,
      maximumDurationMinutes: p.maximumDurationMinutes,
      bufferMinutes: p.bufferMinutes,
      timezone: p.timezone,
    };
  }

  // ─── Weekly schedule ──────────────────────────────────────────────────────

  private weeklyDays(rows: WeeklyRow[]) {
    return DAYS.map((day) => {
      const dayRows = rows
        .filter((r) => r.dayOfWeek === day)
        .sort((a, b) => parseTime(a.startTime) - parseTime(b.startTime));
      return {
        dayOfWeek: day,
        isActive: dayRows.length > 0 && dayRows.every((r) => r.isActive),
        windows: dayRows.map((r) => ({ startTime: r.startTime, endTime: r.endTime })),
      };
    });
  }

  async updateWeekly(userId: string, input: UpdateWeeklyInput) {
    const profile = await this.ownProfile(userId);

    const min = input.minimumDurationMinutes ?? profile.minimumDurationMinutes;
    const max = input.maximumDurationMinutes ?? profile.maximumDurationMinutes;
    if (max < min) {
      throw new AppError('VALIDATION_ERROR', 'Maximum duration must be greater than or equal to minimum duration', 400);
    }

    await prisma.$transaction(async (tx) => {
      await tx.oduvarProfile.update({
        where: { id: profile.id },
        data: {
          minimumDurationMinutes: min,
          maximumDurationMinutes: max,
          bufferMinutes: input.bufferMinutes ?? profile.bufferMinutes,
          timezone: input.timezone ?? profile.timezone,
        },
      });
      if (input.days) {
        await tx.oduvarWeeklyAvailability.deleteMany({
          where: { oduvarId: profile.id, dayOfWeek: { in: input.days.map((d) => d.dayOfWeek) } },
        });
        const data = input.days.flatMap((d) =>
          d.windows.map((w) => ({
            oduvarId: profile.id,
            dayOfWeek: d.dayOfWeek,
            startTime: w.startTime,
            endTime: w.endTime,
            isActive: d.isActive,
          }))
        );
        if (data.length) await tx.oduvarWeeklyAvailability.createMany({ data });
      }
    });

    return this.getMyAvailability(userId);
  }

  // ─── Overrides (owner CRUD) ───────────────────────────────────────────────

  private formatOverride(o: OverrideRow) {
    return {
      id: o.id,
      date: fromDbDate(o.date),
      type: o.type,
      startTime: o.startTime,
      endTime: o.endTime,
      reason: o.reason,
    };
  }

  async listOverrides(userId: string) {
    const profile = await this.ownProfile(userId);
    const rows = await prisma.oduvarAvailabilityOverride.findMany({
      where: { oduvarId: profile.id },
      orderBy: [{ date: 'asc' }, { startTime: 'asc' }],
    });
    return rows.map((r) => this.formatOverride(r));
  }

  async createOverride(userId: string, input: OverrideInput) {
    const profile = await this.ownProfile(userId);
    const row = await prisma.oduvarAvailabilityOverride.create({
      data: {
        oduvarId: profile.id,
        date: toDbDate(input.date),
        type: input.type,
        startTime: input.startTime ?? null,
        endTime: input.endTime ?? null,
        reason: input.reason ?? null,
      },
    });
    return this.formatOverride(row);
  }

  private async ownedOverride(userId: string, overrideId: string) {
    const profile = await this.ownProfile(userId);
    const found = await prisma.oduvarAvailabilityOverride.findFirst({
      where: { id: overrideId, oduvarId: profile.id },
    });
    if (!found) throw new AppError('NOT_FOUND', 'Override not found', 404);
    return found;
  }

  async updateOverride(userId: string, overrideId: string, input: OverrideInput) {
    await this.ownedOverride(userId, overrideId);
    const row = await prisma.oduvarAvailabilityOverride.update({
      where: { id: overrideId },
      data: {
        date: toDbDate(input.date),
        type: input.type,
        startTime: input.startTime ?? null,
        endTime: input.endTime ?? null,
        reason: input.reason ?? null,
      },
    });
    return this.formatOverride(row);
  }

  async deleteOverride(userId: string, overrideId: string) {
    await this.ownedOverride(userId, overrideId);
    await prisma.oduvarAvailabilityOverride.delete({ where: { id: overrideId } });
    return { message: 'Override deleted' };
  }

  // ─── Core computation ─────────────────────────────────────────────────────

  private validateDuration(profile: OduvarProfile, duration: number | undefined): number {
    const d = duration ?? profile.minimumDurationMinutes;
    if (d < profile.minimumDurationMinutes || d > profile.maximumDurationMinutes) {
      throw new AppError(
        'VALIDATION_ERROR',
        `Duration must be between ${profile.minimumDurationMinutes} and ${profile.maximumDurationMinutes} minutes for this Oduvar`,
        400
      );
    }
    return d;
  }

  /** Working windows after applying overrides (see availability.engine.ts for priority rules). */
  windowsForDate(date: string, weekly: WeeklyRow[], overrides: OverrideRow[]): Interval[] {
    const dow = dayOfWeekFor(date);
    const weeklyWindows: Interval[] = weekly
      .filter((w) => w.isActive && w.dayOfWeek === dow)
      .map((w) => ({ start: parseTime(w.startTime), end: parseTime(w.endTime) }));
    const rules: OverrideRule[] = overrides
      .filter((o) => fromDbDate(o.date) === date)
      .map((o) => ({
        type: o.type,
        start: o.startTime ? parseTime(o.startTime) : null,
        end: o.endTime ? parseTime(o.endTime) : null,
      }));
    return resolveWindowsForDate(weeklyWindows, rules);
  }

  private async computeDay(
    profile: OduvarProfile,
    weekly: WeeklyRow[],
    overrides: OverrideRow[],
    date: string,
    duration: number,
    withSlots: boolean,
    now: { date: string; minutes: number }
  ) {
    const windows = this.windowsForDate(date, weekly, overrides);
    const isPast = date < now.date;
    const occupied = isPast ? [] : await occupiedProvider(profile.id, date);
    const slots = isPast
      ? []
      : getAvailableSlots({
          windows,
          durationMinutes: duration,
          bufferMinutes: profile.bufferMinutes,
          occupied,
          earliestStart: date === now.date ? now.minutes : undefined,
        });
    const status: DayStatus = slots.length > 0 ? 'AVAILABLE' : 'UNAVAILABLE';
    return {
      date,
      isAvailable: status === 'AVAILABLE',
      status,
      workingWindows: isPast ? [] : windows.map((w) => ({ start: formatTime(w.start), end: formatTime(w.end) })),
      ...(withSlots ? { durationMinutes: duration, slots: slots.map(formatTime) } : {}),
    };
  }

  private async load(profile: OduvarProfile) {
    const [weekly, overrides] = await Promise.all([
      prisma.oduvarWeeklyAvailability.findMany({ where: { oduvarId: profile.id } }),
      prisma.oduvarAvailabilityOverride.findMany({ where: { oduvarId: profile.id }, orderBy: { date: 'asc' } }),
    ]);
    return { weekly, overrides };
  }

  private async resolveQuery(
    profile: OduvarProfile,
    query: { date?: string; month?: string; duration?: number },
    now: Date
  ) {
    const { weekly, overrides } = await this.load(profile);
    const nowZ = nowInZone(profile.timezone, now);
    const duration = this.validateDuration(profile, query.duration);
    const base = {
      timezone: profile.timezone,
      rules: this.rules(profile),
      weekly: this.weeklyDays(weekly),
    };

    if (query.date) {
      const day = await this.computeDay(profile, weekly, overrides, query.date, duration, true, nowZ);
      return { ...base, day };
    }
    if (query.month) {
      const [y, m] = query.month.split('-').map(Number);
      const count = new Date(Date.UTC(y, m, 0)).getUTCDate();
      const days = [];
      for (let i = 1; i <= count; i++) {
        const date = `${query.month}-${String(i).padStart(2, '0')}`;
        const d = await this.computeDay(profile, weekly, overrides, date, duration, false, nowZ);
        days.push({ date: d.date, status: d.status, isAvailable: d.isAvailable });
      }
      return { ...base, month: query.month, days };
    }
    return base;
  }

  // ─── Public entry points ──────────────────────────────────────────────────

  async getMyAvailability(
    userId: string,
    query: { date?: string; month?: string; duration?: number } = {},
    now: Date = new Date()
  ) {
    const profile = await this.ownProfile(userId);
    const result = await this.resolveQuery(profile, query, now);
    const overrides = await this.listOverrides(userId);
    return { ...result, overrides };
  }

  async getPublicAvailability(
    oduvarUserId: string,
    query: { date?: string; month?: string; duration?: number } = {},
    now: Date = new Date()
  ) {
    const profile = await this.publicProfile(oduvarUserId);
    return this.resolveQuery(profile, query, now);
  }

  /**
   * Reusable by the future booking engine: bookable start times for a date.
   * Callers may pass extra occupied intervals (e.g. confirmed bookings).
   */
  async getAvailableSlots(
    profileId: string,
    date: string,
    durationMinutes?: number,
    extraOccupied: Interval[] = [],
    now: Date = new Date()
  ): Promise<string[]> {
    const profile = await prisma.oduvarProfile.findUnique({ where: { id: profileId } });
    if (!profile) throw new AppError('NOT_FOUND', 'Oduvar profile not found', 404);
    const duration = this.validateDuration(profile, durationMinutes);
    const { weekly, overrides } = await this.load(profile);
    const nowZ = nowInZone(profile.timezone, now);
    if (date < nowZ.date) return [];
    const occupied = [...(await occupiedProvider(profile.id, date)), ...extraOccupied];
    return getAvailableSlots({
      windows: this.windowsForDate(date, weekly, overrides),
      durationMinutes: duration,
      bufferMinutes: profile.bufferMinutes,
      occupied,
      earliestStart: date === nowZ.date ? nowZ.minutes : undefined,
    }).map(formatTime);
  }
}

export const availabilityService = new AvailabilityService();
