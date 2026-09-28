import { PrismaClient, Role } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { PREDEFINED_SKILLS, PREDEFINED_INSTRUMENTS, PREDEFINED_SERVICES } from '../src/common/constants/reference-data';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding development data...');

  // ─── Phase 1: Users ─────────────────────────────────────────────────────────
  console.log('  → Seeding users...');
  const seedUsers = [
    {
      name: 'Sundar Devotee',
      email: 'client.dev@oduvar.local',
      phone: '+919876543210',
      passwordPlain: 'ClientDev#2026!',
      role: Role.CLIENT,
      profilePhoto: null,
    },
    {
      name: 'Oduvar Sivakumar Desikar',
      email: 'oduvar.dev@oduvar.local',
      phone: '+919876543211',
      passwordPlain: 'OduvarDev#2026!',
      role: Role.ODUVAR,
      profilePhoto: null,
    },
    {
      name: 'Platform Administrator',
      email: 'admin.dev@oduvar.local',
      phone: '+919876543212',
      passwordPlain: 'AdminDev#2026!',
      role: Role.ADMIN,
      profilePhoto: null,
    },
  ];

  for (const user of seedUsers) {
    const passwordHash = await bcrypt.hash(user.passwordPlain, 12);
    const upserted = await prisma.user.upsert({
      where: { email: user.email },
      update: { name: user.name, phone: user.phone, passwordHash, role: user.role },
      create: {
        name: user.name,
        email: user.email,
        phone: user.phone,
        passwordHash,
        role: user.role,
        profilePhoto: user.profilePhoto,
      },
    });
    console.log(`    ✓ ${upserted.role}: ${upserted.email}`);
  }

  // ─── Phase 2: Reference data ────────────────────────────────────────────────
  console.log('  → Seeding skills...');
  for (const skill of PREDEFINED_SKILLS) {
    await prisma.skill.upsert({
      where: { slug: skill.slug },
      update: { name: skill.name, sortOrder: skill.sortOrder },
      create: { name: skill.name, slug: skill.slug, sortOrder: skill.sortOrder, isPredefined: true },
    });
  }
  console.log(`    ✓ ${PREDEFINED_SKILLS.length} skills seeded`);

  console.log('  → Seeding instruments...');
  for (const inst of PREDEFINED_INSTRUMENTS) {
    await prisma.instrument.upsert({
      where: { slug: inst.slug },
      update: { name: inst.name, sortOrder: inst.sortOrder },
      create: { name: inst.name, slug: inst.slug, sortOrder: inst.sortOrder, isPredefined: true },
    });
  }
  console.log(`    ✓ ${PREDEFINED_INSTRUMENTS.length} instruments seeded`);

  // ─── Phase 3: Services ──────────────────────────────────────────────────────
  console.log('  → Seeding services...');
  for (const s of PREDEFINED_SERVICES) {
    await prisma.service.upsert({
      where: { name: s.name },
      update: { category: s.category, description: s.description, isActive: true },
      create: { name: s.name, category: s.category, description: s.description, isActive: true },
    });
  }
  console.log(`    ✓ ${PREDEFINED_SERVICES.length} services seeded`);

  // ─── Phase 5: OPTIONAL demo Oduvars for local discovery testing ─────────────
  // Off by default. Run with SEED_DEMO_ODUVARS=true. Refuses to run in production.
  if (process.env.SEED_DEMO_ODUVARS === 'true' && process.env.NODE_ENV !== 'production') {
    console.log('  → Seeding DEMO Oduvars (dev only)...');
    const demo = [
      { key: 'ravi', name: 'Ravi Shankar Oduvar', location: 'Salem', perf: ['VOCAL'], songs: ['THEVARAM'], transport: 'INCLUDED', instrument: 'harmonium', category: 'Thevaram' },
      { key: 'meena', name: 'Meenakshi Devi', location: 'Chennai', perf: ['BOTH'], songs: ['THIRUVASAGAM', 'THIRUPUGAZH'], transport: 'ADDITIONAL_FEE', instrument: 'veena', category: 'Thiruvasagam' },
      { key: 'karthik', name: 'Karthikeyan Pandaram', location: 'Madurai', perf: ['INSTRUMENTAL'], songs: ['THIRUPUGAZH'], transport: 'TO_BE_DISCUSSED', instrument: 'nadaswaram', category: 'Thirupugazh' },
    ] as const;
    for (const d of demo) {
      const passwordHash = await bcrypt.hash('DemoOduvar#2026!', 12);
      const user = await prisma.user.upsert({
        where: { email: `demo.${d.key}@oduvar.local` },
        update: {},
        create: { name: d.name, email: `demo.${d.key}@oduvar.local`, phone: '+919000000000', passwordHash, role: Role.ODUVAR },
      });
      const profile = await prisma.oduvarProfile.upsert({
        where: { userId: user.id },
        update: {},
        create: {
          userId: user.id, location: d.location, bio: `Demo profile for ${d.name}.`,
          performanceTypes: [...d.perf], songCategories: [...d.songs], transport: d.transport, isPublished: true,
        },
      });
      const inst = await prisma.instrument.findUnique({ where: { slug: d.instrument } });
      if (inst) {
        await prisma.oduvarProfileInstrument.upsert({
          where: { profileId_instrumentId: { profileId: profile.id, instrumentId: inst.id } },
          update: {}, create: { profileId: profile.id, instrumentId: inst.id },
        });
      }
      const base = await prisma.service.findFirst({ where: { category: d.category } });
      if (base) {
        await prisma.oduvarService.upsert({
          where: { profileId_serviceId: { profileId: profile.id, serviceId: base.id } },
          update: {}, create: { profileId: profile.id, serviceId: base.id },
        });
      }
    }
    console.log(`    ✓ ${demo.length} demo Oduvars (password: DemoOduvar#2026!)`);
  }

  console.log('✅ Seeding completed successfully.');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
