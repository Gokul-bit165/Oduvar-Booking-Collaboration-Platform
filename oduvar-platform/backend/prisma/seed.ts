import { PrismaClient, Role } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding development users...');

  // Development Seed Credentials (FAKE DEV ONLY)
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
      update: {
        name: user.name,
        phone: user.phone,
        passwordHash,
        role: user.role,
      },
      create: {
        name: user.name,
        email: user.email,
        phone: user.phone,
        passwordHash,
        role: user.role,
        profilePhoto: user.profilePhoto,
      },
    });

    console.log(` Created/Updated ${upserted.role}: ${upserted.email} (ID: ${upserted.id})`);
  }

  console.log(' Seeding completed successfully.');
}

main()
  .catch((e) => {
    console.error(' Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
