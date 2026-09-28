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

// Phase 3: Reference data — Service categories and predefined services
export const SERVICE_CATEGORIES = ['Thevaram', 'Thiruvasagam', 'Thirupugazh', 'Other'] as const;
export type ServiceCategory = typeof SERVICE_CATEGORIES[number];

export const PREDEFINED_SERVICES = [
  {
    name: 'Thevaram Recital',
    category: 'Thevaram',
    description: 'Devotional recital of Thirumurai hymns composed by Appar, Sambandar, and Sundarar.',
  },
  {
    name: 'Thiruvasagam Recital',
    category: 'Thiruvasagam',
    description: 'Deep, soulful rendering of Manikkavacakar’s profound devotional verses.',
  },
  {
    name: 'Thirupugazh Rendition',
    category: 'Thirupugazh',
    description: 'Complex rhythmic and poetic devotional hymns praising Lord Murugan.',
  },
  {
    name: 'Temple Pooja & Festival Service',
    category: 'Other',
    description: 'Special pooja, kumbhabhishekam, and annual festival vocal and instrumental music.',
  },
  {
    name: 'Home Devotional Concert',
    category: 'Other',
    description: 'Auspicious occasions, family gatherings, and spiritual poojas at private residences.',
  },
] as const;


// Phase 5: Event types an Oduvar can declare support for (stored on OduvarProfile.eventTypes).
// No Oduvar is pre-assigned any event type; the profile owner opts in.
export const EVENT_TYPES = [
  { key: 'HOSPITAL', label: 'Hospital' },
  { key: 'BEDRIDDEN_PATIENT', label: 'Bedridden Patient' },
  { key: 'GENERAL', label: 'General' },
  { key: 'FUNCTION', label: 'Function' },
  { key: 'TEMPLE', label: 'Temple' },
  { key: 'FUNERAL', label: 'Funeral' },
  { key: 'OTHER', label: 'Other' },
] as const;
export type EventType = typeof EVENT_TYPES[number]['key'];
