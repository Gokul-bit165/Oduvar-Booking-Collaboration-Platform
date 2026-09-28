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
