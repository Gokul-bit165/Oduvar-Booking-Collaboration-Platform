import { z } from 'zod';
import { TransportOption } from '@prisma/client';

export const pricingItemSchema = z.object({
  durationMinutes: z
    .number({ required_error: 'Duration is required' })
    .int('Duration must be a whole number of minutes')
    .min(30, 'Minimum duration is 30 minutes'),
  amount: z
    .number({ required_error: 'Amount is required' })
    .positive('Amount must be greater than zero'),
  currency: z.string().default('INR').optional(),
});

export const createOduvarServiceSchema = z
  .object({
    serviceId: z.string().uuid('Invalid service ID'),
    customDescription: z.string().max(1000, 'Description cannot exceed 1000 characters').optional(),
    transport: z.nativeEnum(TransportOption).optional().default(TransportOption.TO_BE_DISCUSSED),
    transportFee: z.number().min(0, 'Transport fee cannot be negative').optional().nullable(),
    pricings: z.array(pricingItemSchema).optional().default([]),
  })
  .superRefine((data, ctx) => {
    if (data.transport === TransportOption.ADDITIONAL_FEE) {
      if (data.transportFee === undefined || data.transportFee === null || data.transportFee <= 0) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['transportFee'],
          message: 'Transport fee is required and must be greater than zero when Additional Fee is selected',
        });
      }
    }
    // Check duplicate durations in pricings
    if (data.pricings && data.pricings.length > 0) {
      const durations = new Set<number>();
      for (const p of data.pricings) {
        if (durations.has(p.durationMinutes)) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['pricings'],
            message: `Duplicate duration ${p.durationMinutes} minutes is not allowed for the same service`,
          });
          break;
        }
        durations.add(p.durationMinutes);
      }
    }
  });

export type CreateOduvarServiceInput = z.infer<typeof createOduvarServiceSchema>;

export const updateOduvarServiceSchema = z
  .object({
    customDescription: z.string().max(1000, 'Description cannot exceed 1000 characters').optional().nullable(),
    transport: z.nativeEnum(TransportOption).optional(),
    transportFee: z.number().min(0, 'Transport fee cannot be negative').optional().nullable(),
    isActive: z.boolean().optional(),
  })
  .superRefine((data, ctx) => {
    if (data.transport === TransportOption.ADDITIONAL_FEE) {
      if (data.transportFee === undefined || data.transportFee === null || data.transportFee <= 0) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['transportFee'],
          message: 'Transport fee is required and must be greater than zero when Additional Fee is selected',
        });
      }
    }
  });

export type UpdateOduvarServiceInput = z.infer<typeof updateOduvarServiceSchema>;

export const createServicePricingSchema = z.object({
  durationMinutes: z
    .number({ required_error: 'Duration is required' })
    .int('Duration must be a whole number of minutes')
    .min(30, 'Minimum duration is 30 minutes'),
  amount: z
    .number({ required_error: 'Amount is required' })
    .positive('Amount must be greater than zero'),
  currency: z.string().default('INR').optional(),
});

export type CreateServicePricingInput = z.infer<typeof createServicePricingSchema>;

export const updateServicePricingSchema = z.object({
  durationMinutes: z
    .number()
    .int('Duration must be a whole number of minutes')
    .min(30, 'Minimum duration is 30 minutes')
    .optional(),
  amount: z.number().positive('Amount must be greater than zero').optional(),
  currency: z.string().optional(),
  isActive: z.boolean().optional(),
});

export type UpdateServicePricingInput = z.infer<typeof updateServicePricingSchema>;
