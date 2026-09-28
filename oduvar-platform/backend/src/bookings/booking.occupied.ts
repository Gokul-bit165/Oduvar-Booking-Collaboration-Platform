import { prisma } from '../config/database';
import { Interval, parseTime } from '../availability/availability.engine';
import { setOccupiedBatchProvider, setOccupiedIntervalProvider } from '../availability/availability.service';

/**
 * Connects real bookings to the Phase 4 availability engine.
 *
 * ONLY CONFIRMED bookings occupy time:
 *   PENDING / REJECTED / CANCELLED never block a slot; COMPLETED is history (an event that has
 *   happened no longer matters for future availability).
 *
 * The engine itself (availability.engine.ts) applies the Oduvar's buffer around each interval, so
 * this provider returns the raw [start, start + duration) interval of each confirmed booking.
 * There is no second conflict algorithm: booking creation, acceptance and the public calendar all
 * go through availabilityService.getAvailableSlots().
 */
const toInterval = (startTime: string, duration: number): Interval => {
  const start = parseTime(startTime);
  return { start, end: start + duration };
};

export function registerBookingOccupiedProviders() {
  setOccupiedIntervalProvider(async (profileId, date) => {
    const rows = await prisma.booking.findMany({
      where: { status: 'CONFIRMED', date: new Date(`${date}T00:00:00Z`), oduvar: { oduvarProfile: { id: profileId } } },
      select: { startTime: true, duration: true },
    });
    return rows.map((r) => toInterval(r.startTime, r.duration));
  });

  // One query for many Oduvars (discovery's availability filter).
  setOccupiedBatchProvider(async (profileIds, date) => {
    const rows = await prisma.booking.findMany({
      where: { status: 'CONFIRMED', date: new Date(`${date}T00:00:00Z`), oduvar: { oduvarProfile: { id: { in: profileIds } } } },
      select: { startTime: true, duration: true, oduvar: { select: { oduvarProfile: { select: { id: true } } } } },
    });
    const map = new Map<string, Interval[]>();
    for (const r of rows) {
      const pid = r.oduvar.oduvarProfile?.id;
      if (!pid) continue;
      map.set(pid, [...(map.get(pid) ?? []), toInterval(r.startTime, r.duration)]);
    }
    return map;
  });
}
