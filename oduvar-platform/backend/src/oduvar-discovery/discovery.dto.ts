import { z } from 'zod';
import { TransportOption } from '@prisma/client';
import { EVENT_TYPES, PERFORMANCE_TYPES, SONG_CATEGORIES } from '../common/constants/reference-data';
import { dateSchema } from '../availability/availability.dto';

export const MAX_PAGE_SIZE = 50;
export const DEFAULT_PAGE_SIZE = 20;
export const SORT_OPTIONS = ['relevance', 'name', 'rating', 'location'] as const;
export type SortOption = typeof SORT_OPTIONS[number];

// Blank query params (?search=) are treated as "not provided".
const blankToUndefined = (v: unknown) => (typeof v === 'string' && v.trim() === '' ? undefined : v);
const text = z.preprocess(blankToUndefined, z.string().trim().max(100).optional());
const upperEnum = <T extends [string, ...string[]]>(values: T) =>
  z.preprocess(
    (v) => (typeof v === 'string' ? (v.trim() === '' ? undefined : v.trim().toUpperCase()) : v),
    z.enum(values).optional()
  );
const optInt = (min: number, max: number) =>
  z.preprocess(blankToUndefined, z.coerce.number().int().min(min).max(max).optional());

export const discoveryQuerySchema = z
  .object({
    search: text,
    location: text,
    service: text, // service id, category (e.g. "Thevaram") or service name
    instrument: text, // instrument id, slug or name
    songCategory: upperEnum(SONG_CATEGORIES.map((c) => c.key) as [string, ...string[]]),
    eventType: upperEnum(EVENT_TYPES.map((e) => e.key) as [string, ...string[]]),
    performanceType: upperEnum([...PERFORMANCE_TYPES] as [string, ...string[]]),
    transport: upperEnum(Object.values(TransportOption) as [string, ...string[]]),
    minRating: z.preprocess(blankToUndefined, z.coerce.number().min(1).max(5).optional()),
    availableDate: z.preprocess(blankToUndefined, dateSchema.optional()),
    availableDuration: optInt(30, 24 * 60),
    page: z.preprocess(blankToUndefined, z.coerce.number().int().min(1).max(100000).default(1)),
    pageSize: z.preprocess(blankToUndefined, z.coerce.number().int().min(1).max(MAX_PAGE_SIZE).default(DEFAULT_PAGE_SIZE)),
    sort: z.preprocess(
      (v) => (typeof v === 'string' ? (v.trim() === '' ? undefined : v.trim().toLowerCase()) : v),
      z.enum(SORT_OPTIONS).default('relevance')
    ),
  })
  .superRefine((q, ctx) => {
    if (q.availableDuration !== undefined && q.availableDate === undefined) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['availableDate'],
        message: 'availableDate is required when availableDuration is provided',
      });
    }
  });

export type DiscoveryQuery = z.infer<typeof discoveryQuerySchema>;
