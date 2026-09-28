/**
 * TIMEZONE HANDLING FOR BOOKINGS
 *
 * A booking's date + startTime are WALL-CLOCK values in the Oduvar's schedule timezone
 * (OduvarProfile.timezone, default Asia/Kolkata), exactly as Phase 4 availability interprets them.
 * The booking stores:
 *   - date, startTime, endTime, duration : the intended wall-clock event (what people see)
 *   - timezone                           : the zone that was in force when the booking was made
 *   - startsAt / endsAt (UTC instants)   : derived from the above with the function below;
 *                                          used for "has the event started?", the 24h cancellation
 *                                          rule and the DB no-overlap constraint
 * The server's own timezone is never consulted.
 */

/** Offset (ms) of `timeZone` from UTC at the given instant. */
function zoneOffsetMs(instant: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(instant);
  const get = (t: string) => Number(parts.find((p) => p.type === t)!.value);
  const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour'), get('minute'), get('second'));
  return asUtc - Math.floor(instant.getTime() / 1000) * 1000;
}

/** Convert a wall-clock date ("YYYY-MM-DD") + minutes-from-midnight in `timeZone` to a UTC instant. */
export function zonedWallTimeToUtc(date: string, minutesFromMidnight: number, timeZone: string): Date {
  const [y, m, d] = date.split('-').map(Number);
  const guess = Date.UTC(y, m - 1, d, 0, minutesFromMidnight, 0);
  // Two passes so the result is right on either side of a DST change.
  let result = guess - zoneOffsetMs(new Date(guess), timeZone);
  result = guess - zoneOffsetMs(new Date(result), timeZone);
  return new Date(result);
}
