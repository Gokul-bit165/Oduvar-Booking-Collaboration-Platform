import { z } from 'zod';
import { TransportOption } from '@prisma/client';
import { EVENT_TYPES } from '../common/constants/reference-data';
import { dateSchema, timeSchema } from '../availability/availability.dto';

/** Strip spaces, dashes, dots and brackets; allow an optional leading +; require 10-15 digits. */
export function normalizePhone(raw: string): string {
  return raw.replace(/[\s\-().]/g, '');
}
export const phoneSchema = z
  .string({ required_error: 'Phone number is required' })
  .transform(normalizePhone)
  .refine((v) => /^\+?[0-9]{10,15}$/.test(v), 'Enter a valid phone number (10-15 digits)');

const eventTypeKeys = EVENT_TYPES.map((e) => e.key) as [string, ...string[]];

/**
 * `.strict()`: any extra key (serviceAmount, totalAmount, transportFee, price, amount, ...) makes the
 * request a 400. The client can only SELECT what the Oduvar published; it can never state a price.
 */
export const createBookingSchema = z
  .object({
    oduvarId: z.string().uuid('Invalid Oduvar id'),
    oduvarServiceId: z.string().uuid('Invalid service id'),
    servicePricingId: z.string().uuid('Invalid pricing id'),
    date: dateSchema,
    startTime: timeSchema,
    durationMinutes: z.number({ required_error: 'Duration is required' }).int().min(30),
    eventType: z.enum(eventTypeKeys, { errorMap: () => ({ message: 'Invalid event type' }) }),
    songType: z.string().trim().max(100).optional().nullable(),
    description: z.string({ required_error: 'Description is required' }).trim().min(3, 'Please describe the event').max(1000),
    eventLocation: z.string({ required_error: 'Event location is required' }).trim().min(3, 'Event location is required').max(300),
    phone1: phoneSchema,
    phone2: phoneSchema.optional().nullable().or(z.literal('').transform(() => null)),
    // The transport option the client saw and accepted. Must match the Oduvar's current option, else 409.
    transport: z.nativeEnum(TransportOption),
  })
  .strict();

export const reasonSchema = z.object({ reason: z.string().trim().max(500).optional() }).strict();

export const BOOKING_STATUSES = ['PENDING', 'CONFIRMED', 'REJECTED', 'CANCELLED', 'COMPLETED'] as const;

export const listBookingsQuerySchema = z.object({
  status: z
    .string()
    .optional()
    .transform((v) => (v ? v.split(',').map((s) => s.trim().toUpperCase()).filter(Boolean) : undefined))
    .refine((v) => !v || v.every((s) => (BOOKING_STATUSES as readonly string[]).includes(s)), 'Invalid status'),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(50),
});

export type CreateBookingInput = z.infer<typeof createBookingSchema>;
