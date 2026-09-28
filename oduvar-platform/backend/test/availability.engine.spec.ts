import {
  getAvailableSlots,
  resolveWindowsForDate,
  formatTime,
  parseTime,
  Interval,
} from '../src/availability/availability.engine';
import { dayOfWeekFor, nowInZone } from '../src/availability/availability.service';

const w = (s: string, e: string): Interval => ({ start: parseTime(s), end: parseTime(e) });
const slots = (q: Parameters<typeof getAvailableSlots>[0]) => getAvailableSlots(q).map(formatTime);

describe('Phase 4: availability engine (pure)', () => {
  test('CASE A: 09:00-18:00 / 30min => half-hour starts, last is 17:30', () => {
    const r = slots({ windows: [w('09:00', '18:00')], durationMinutes: 30 });
    expect(r[0]).toBe('09:00');
    expect(r[1]).toBe('09:30');
    expect(r[r.length - 1]).toBe('17:30');
    expect(r).toHaveLength(18);
  });

  test('CASE B: 09:00-10:00 / 2h => no slots', () => {
    expect(slots({ windows: [w('09:00', '10:00')], durationMinutes: 120 })).toEqual([]);
  });

  test('CASE C: 09:00-12:00 / 1h => only slots that fully fit', () => {
    expect(slots({ windows: [w('09:00', '12:00')], durationMinutes: 60 })).toEqual(['09:00', '09:30', '10:00', '10:30', '11:00']);
  });

  test('CASE D: blocked 12:00-14:00 / 1h => no slot crosses the block', () => {
    const windows = resolveWindowsForDate([w('09:00', '18:00')], [
      { type: 'UNAVAILABLE', start: parseTime('12:00'), end: parseTime('14:00') },
    ]);
    const r = slots({ windows, durationMinutes: 60 });
    expect(r).toContain('11:00');
    expect(r).not.toContain('11:30');
    expect(r).not.toContain('12:00');
    expect(r).not.toContain('13:30');
    expect(r).toContain('14:00');
  });

  test('CASE E: weekly window + all-day UNAVAILABLE override => unavailable', () => {
    const windows = resolveWindowsForDate([w('09:00', '18:00')], [{ type: 'UNAVAILABLE', start: null, end: null }]);
    expect(windows).toEqual([]);
    expect(slots({ windows, durationMinutes: 30 })).toEqual([]);
  });

  test('CASE F: no weekly schedule + AVAILABLE override => available', () => {
    const windows = resolveWindowsForDate([], [{ type: 'AVAILABLE', start: parseTime('18:00'), end: parseTime('21:00') }]);
    expect(slots({ windows, durationMinutes: 60 })).toEqual(['18:00', '18:30', '19:00', '19:30', '20:00']);
  });

  test('AVAILABLE override replaces (not extends) the weekly window', () => {
    const windows = resolveWindowsForDate([w('09:00', '18:00')], [
      { type: 'AVAILABLE', start: parseTime('19:00'), end: parseTime('21:00') },
    ]);
    expect(windows).toEqual([w('19:00', '21:00')]);
  });

  test('CASE G: split shifts are generated independently per window', () => {
    const r = slots({ windows: [w('09:00', '12:00'), w('17:00', '20:00')], durationMinutes: 60 });
    expect(r).toEqual(['09:00', '09:30', '10:00', '10:30', '11:00', '17:00', '17:30', '18:00', '18:30', '19:00']);
    expect(r).not.toContain('11:30'); // would run past 12:00 / into the gap
  });

  test('occupied 10:00-11:00 with 30min buffer => next usable start is 11:30 (1h)', () => {
    const r = slots({
      windows: [w('09:00', '18:00')],
      durationMinutes: 60,
      bufferMinutes: 30,
      occupied: [w('10:00', '11:00')],
    });
    expect(r).not.toContain('11:00');
    expect(r).not.toContain('09:00'); // 09:00-10:00 touches the booking, buffer violated
    expect(r).not.toContain('10:30');
    expect(r).toContain('11:30');
  });

  test('occupied without buffer allows back-to-back', () => {
    const r = slots({ windows: [w('09:00', '12:00')], durationMinutes: 60, occupied: [w('10:00', '11:00')] });
    expect(r).toEqual(['09:00', '11:00']);
  });

  test('earliestStart drops past starts', () => {
    const r = slots({ windows: [w('09:00', '11:00')], durationMinutes: 30, earliestStart: parseTime('10:00') });
    expect(r).toEqual(['10:00', '10:30']);
  });

  test('day of week and timezone helpers', () => {
    expect(dayOfWeekFor('2035-01-01')).toBe('MONDAY');
    expect(dayOfWeekFor('2035-01-07')).toBe('SUNDAY');
    // 2026-10-20T20:00Z is 01:30 on Oct 21 in Asia/Kolkata (UTC+5:30), still Oct 20 in UTC
    expect(nowInZone('Asia/Kolkata', new Date('2026-10-20T20:00:00Z'))).toEqual({ date: '2026-10-21', minutes: 90 });
    expect(nowInZone('UTC', new Date('2026-10-20T20:00:00Z'))).toEqual({ date: '2026-10-20', minutes: 1200 });
  });
});
