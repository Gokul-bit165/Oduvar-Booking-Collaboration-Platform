import { z } from 'zod';
import { DayOfWeek, OverrideType } from '@prisma/client';

export const timeSchema = z
  .string({ required_error: 'Time is required' })
  .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Time must be in HH:mm (24h) format');

export const dateSchema = z
  .string({ required_error: 'Date is required' })
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be YYYY-MM-DD')
  .refine((d) => {
    const dt = new Date(`${d}T00:00:00Z`);
    return !isNaN(dt.getTime()) && dt.toISOString().slice(0, 10) === d;
  }, 'Invalid calendar date');

const toMin = (t: string) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));

const windowSchema = z
  .object({ startTime: timeSchema, endTime: timeSchema })
  .refine((w) => toMin(w.startTime) < toMin(w.endTime), {
    message: 'Start time must be before end time',
    path: ['endTime'],
  });

const daySchema = z
  .object({
    dayOfWeek: z.nativeEnum(DayOfWeek),
    isActive: z.boolean(),
    windows: z.array(windowSchema).max(4, 'At most 4 working windows per day'),
  })
  .superRefine((d, ctx) => {
    const sorted = [...d.windows].sort((a, b) => toMin(a.startTime) - toMin(b.startTime));
    for (let i = 1; i < sorted.length; i++) {
      if (toMin(sorted[i].startTime) < toMin(sorted[i - 1].endTime)) {
        ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['windows'], message: 'Working windows must not overlap' });
        return;
      }
    }
    if (d.isActive && d.windows.length === 0) {
      ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['windows'], message: 'An active day needs at least one window' });
    }
  });

export const updateWeeklySchema = z
  .object({
    days: z.array(daySchema).max(7).optional(),
    minimumDurationMinutes: z.number().int('Must be a whole number').min(30, 'Minimum duration cannot be below 30 minutes').optional(),
    maximumDurationMinutes: z.number().int('Must be a whole number').optional(),
    bufferMinutes: z.number().int('Must be a whole number').min(0, 'Buffer cannot be negative').optional(),
    timezone: z
      .string()
      .refine((tz) => {
        try {
          new Intl.DateTimeFormat('en-US', { timeZone: tz });
          return true;
        } catch {
          return false;
        }
      }, 'Invalid IANA timezone')
      .optional(),
  })
  .superRefine((d, ctx) => {
    if (d.days) {
      const seen = new Set<string>();
      for (const day of d.days) {
        if (seen.has(day.dayOfWeek)) {
          ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['days'], message: `Duplicate day ${day.dayOfWeek}` });
        }
        seen.add(day.dayOfWeek);
      }
    }
    if (
      d.minimumDurationMinutes !== undefined &&
      d.maximumDurationMinutes !== undefined &&
      d.maximumDurationMinutes < d.minimumDurationMinutes
    ) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['maximumDurationMinutes'],
        message: 'Maximum duration must be greater than or equal to minimum duration',
      });
    }
  });

const overrideBase = z.object({
  date: dateSchema,
  type: z.nativeEnum(OverrideType),
  startTime: timeSchema.optional().nullable(),
  endTime: timeSchema.optional().nullable(),
  reason: z.string().max(200).optional().nullable(),
});

function refineOverride(
  d: { type?: OverrideType; startTime?: string | null; endTime?: string | null },
  ctx: z.RefinementCtx
) {
  const hasStart = d.startTime != null;
  const hasEnd = d.endTime != null;
  if (hasStart !== hasEnd) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['endTime'], message: 'Provide both start and end time, or neither' });
    return;
  }
  if (hasStart && hasEnd && toMin(d.startTime!) >= toMin(d.endTime!)) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['endTime'], message: 'Start time must be before end time' });
  }
  if (d.type === 'AVAILABLE' && !hasStart) {
    ctx.addIssue({ code: z.ZodIssueCode.custom, path: ['startTime'], message: 'An AVAILABLE override requires a time range' });
  }
}

export const createOverrideSchema = overrideBase.superRefine(refineOverride);
export const updateOverrideSchema = overrideBase.superRefine(refineOverride);

export const availabilityQuerySchema = z.object({
  date: dateSchema.optional(),
  month: z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/, 'Month must be YYYY-MM').optional(),
  duration: z.coerce.number().int().positive().optional(),
});

export type UpdateWeeklyInput = z.infer<typeof updateWeeklySchema>;
export type OverrideInput = z.infer<typeof createOverrideSchema>;
