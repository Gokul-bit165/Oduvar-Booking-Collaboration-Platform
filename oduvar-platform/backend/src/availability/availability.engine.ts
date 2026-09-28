/**
 * Pure availability algorithm (no DB, no clock, no timezone lookups).
 *
 * TIME MODEL
 *   All times are wall-clock minutes-from-midnight in the Oduvar's schedule
 *   timezone (OduvarProfile.timezone, default Asia/Kolkata). "HH:mm" strings are
 *   parsed with parseTime(). Nothing here converts between zones.
 *
 * OVERRIDE PRIORITY (resolveWindowsForDate)
 *   1. Date-specific overrides
 *        a. If the date has any AVAILABLE override(s), the weekly schedule is
 *           REPLACED for that date by the union of the AVAILABLE windows.
 *        b. UNAVAILABLE overrides are then subtracted (no times => whole day off).
 *           UNAVAILABLE always beats AVAILABLE where they overlap.
 *   2. Weekly availability (active rows for that weekday; several rows = split shifts)
 *   3. No schedule => unavailable (empty window list)
 *
 * CONFLICTS / BUFFER
 *   A candidate [s, s+d) is rejected if it lies outside every working window, or if it
 *   comes within `buffer` minutes of any occupied interval (buffer applies on both
 *   sides). E.g. occupied 10:00-11:00, buffer 30 => next usable start is 11:30.
 *   Future bookings pass their intervals via `occupied`.
 */

export interface Interval {
  start: number; // minutes from midnight
  end: number;
}

export interface OverrideRule {
  type: 'AVAILABLE' | 'UNAVAILABLE';
  start: number | null;
  end: number | null;
}

export const SLOT_STEP_MINUTES = 30;

export function parseTime(t: string): number {
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(t);
  if (!m) throw new Error(`Invalid time "${t}"`);
  return Number(m[1]) * 60 + Number(m[2]);
}

export function formatTime(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

/** Sort and merge overlapping/touching intervals. */
export function mergeIntervals(intervals: Interval[]): Interval[] {
  const sorted = intervals
    .filter((i) => i.end > i.start)
    .map((i) => ({ ...i }))
    .sort((a, b) => a.start - b.start);
  const out: Interval[] = [];
  for (const i of sorted) {
    const last = out[out.length - 1];
    if (last && i.start <= last.end) last.end = Math.max(last.end, i.end);
    else out.push(i);
  }
  return out;
}

/** Remove `cut` intervals from `base` intervals. */
export function subtractIntervals(base: Interval[], cut: Interval[]): Interval[] {
  let result = mergeIntervals(base);
  for (const c of mergeIntervals(cut)) {
    const next: Interval[] = [];
    for (const r of result) {
      if (c.end <= r.start || c.start >= r.end) {
        next.push(r);
        continue;
      }
      if (c.start > r.start) next.push({ start: r.start, end: c.start });
      if (c.end < r.end) next.push({ start: c.end, end: r.end });
    }
    result = next;
  }
  return result;
}

/** Apply the override priority rules documented at the top of this file. */
export function resolveWindowsForDate(weekly: Interval[], overrides: OverrideRule[]): Interval[] {
  const available = overrides.filter((o) => o.type === 'AVAILABLE' && o.start !== null && o.end !== null);
  const base: Interval[] =
    available.length > 0
      ? available.map((o) => ({ start: o.start as number, end: o.end as number }))
      : weekly;

  const cuts: Interval[] = overrides
    .filter((o) => o.type === 'UNAVAILABLE')
    .map((o) => (o.start === null || o.end === null ? { start: 0, end: 24 * 60 } : { start: o.start, end: o.end }));

  return subtractIntervals(base, cuts);
}

export interface SlotQuery {
  windows: Interval[];
  durationMinutes: number;
  bufferMinutes?: number;
  occupied?: Interval[];
  stepMinutes?: number;
  /** Exclude starts before this minute-of-day (used for "today"). */
  earliestStart?: number;
}

/**
 * Generate valid start times (minutes from midnight). Starts are aligned to
 * `stepMinutes` from each window's start, so split shifts are handled independently.
 */
export function getAvailableSlots(q: SlotQuery): number[] {
  const step = q.stepMinutes ?? SLOT_STEP_MINUTES;
  const buffer = Math.max(0, q.bufferMinutes ?? 0);
  const occupied = mergeIntervals(q.occupied ?? []);
  const slots: number[] = [];

  for (const w of mergeIntervals(q.windows)) {
    for (let s = w.start; s + q.durationMinutes <= w.end; s += step) {
      if (q.earliestStart !== undefined && s < q.earliestStart) continue;
      const e = s + q.durationMinutes;
      const conflict = occupied.some((o) => s < o.end + buffer && e + buffer > o.start);
      if (!conflict) slots.push(s);
    }
  }
  return slots;
}
