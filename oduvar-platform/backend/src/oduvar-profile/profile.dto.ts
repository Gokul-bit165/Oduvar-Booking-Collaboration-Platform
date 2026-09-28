import { z } from 'zod';
import { TransportOption } from '@prisma/client';
import { PERFORMANCE_TYPES, SONG_CATEGORIES } from '../../common/constants/reference-data';

const performanceTypeValues = PERFORMANCE_TYPES as unknown as [string, ...string[]];
const songCategoryKeys = SONG_CATEGORIES.map((c) => c.key) as [string, ...string[]];
const transportValues = Object.values(TransportOption) as [string, ...string[]];

export const createOrUpdateProfileSchema = z.object({
  bio: z.string().max(1000, 'Bio must not exceed 1000 characters').optional(),
  location: z.string().max(200, 'Location must not exceed 200 characters').optional(),
  performanceTypes: z
    .array(z.enum(performanceTypeValues))
    .max(3, 'Maximum 3 performance types')
    .optional()
    .default([]),
  songCategories: z
    .array(z.enum(songCategoryKeys))
    .max(10, 'Too many song categories')
    .optional()
    .default([]),
  transport: z.enum(transportValues).optional().default('TO_BE_DISCUSSED'),
  collaborationEnabled: z.boolean().optional().default(true),
  isPublished: z.boolean().optional().default(false),
  skillIds: z.array(z.string().uuid('Invalid skill ID')).optional().default([]),
  instrumentIds: z.array(z.string().uuid('Invalid instrument ID')).optional().default([]),
});

export type CreateOrUpdateProfileInput = z.infer<typeof createOrUpdateProfileSchema>;

export const reorderPhotosSchema = z.object({
  photos: z
    .array(
      z.object({
        id: z.string().uuid('Invalid photo ID'),
        displayOrder: z
          .number()
          .int()
          .min(1, 'Display order must be at least 1')
          .max(5, 'Display order must not exceed 5'),
      })
    )
    .min(1)
    .max(5),
});

export type ReorderPhotosInput = z.infer<typeof reorderPhotosSchema>;
