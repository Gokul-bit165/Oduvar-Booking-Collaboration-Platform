// Phase 2: Reference data — Predefined skills for seeding
export const PREDEFINED_SKILLS = [
  { name: 'Thevaram', slug: 'thevaram', sortOrder: 1 },
  { name: 'Thiruvasagam', slug: 'thiruvasagam', sortOrder: 2 },
  { name: 'Thirupugazh', slug: 'thirupugazh', sortOrder: 3 },
  { name: 'Temple Performances', slug: 'temple-performances', sortOrder: 4 },
  { name: 'Funeral Services', slug: 'funeral-services', sortOrder: 5 },
  { name: 'Hospital Visits', slug: 'hospital-visits', sortOrder: 6 },
  { name: 'Bedridden Patient Services', slug: 'bedridden-patient-services', sortOrder: 7 },
  { name: 'Functions', slug: 'functions', sortOrder: 8 },
  { name: 'General Devotional Performances', slug: 'general-devotional-performances', sortOrder: 9 },
  { name: 'Other', slug: 'other', sortOrder: 10 },
] as const;

export const PREDEFINED_INSTRUMENTS = [
  { name: 'Mridangam', slug: 'mridangam', sortOrder: 1 },
  { name: 'Harmonium', slug: 'harmonium', sortOrder: 2 },
  { name: 'Veena', slug: 'veena', sortOrder: 3 },
  { name: 'Nadaswaram', slug: 'nadaswaram', sortOrder: 4 },
  { name: 'Thavil', slug: 'thavil', sortOrder: 5 },
  { name: 'Violin', slug: 'violin', sortOrder: 6 },
  { name: 'Flute', slug: 'flute', sortOrder: 7 },
  { name: 'Tabla', slug: 'tabla', sortOrder: 8 },
  { name: 'Ghatam', slug: 'ghatam', sortOrder: 9 },
  { name: 'Kanjira', slug: 'kanjira', sortOrder: 10 },
] as const;

export const PERFORMANCE_TYPES = ['VOCAL', 'INSTRUMENTAL', 'BOTH'] as const;
export type PerformanceType = typeof PERFORMANCE_TYPES[number];

export const SONG_CATEGORIES = [
  { key: 'THEVARAM', label: 'Thevaram' },
  { key: 'THIRUVASAGAM', label: 'Thiruvasagam' },
  { key: 'THIRUPUGAZH', label: 'Thirupugazh' },
  { key: 'OTHER', label: 'Other' },
] as const;
export type SongCategory = typeof SONG_CATEGORIES[number]['key'];
