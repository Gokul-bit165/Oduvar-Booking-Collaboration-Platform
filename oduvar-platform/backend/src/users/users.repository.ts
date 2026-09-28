import { prisma } from '../config/database';
import { Prisma, User, Role } from '@prisma/client';

export class UsersRepository {
  async findByEmail(email: string): Promise<User | null> {
    return prisma.user.findUnique({
      where: { email: email.toLowerCase().trim() },
    });
  }

  async findById(id: string): Promise<User | null> {
    return prisma.user.findUnique({
      where: { id },
    });
  }

  async create(data: {
    name: string;
    email: string;
    phone: string;
    passwordHash: string;
    role: Role;
    profilePhoto?: string | null;
  }): Promise<User> {
    return prisma.user.create({
      data: {
        name: data.name.trim(),
        email: data.email.toLowerCase().trim(),
        phone: data.phone.trim(),
        passwordHash: data.passwordHash,
        role: data.role,
        profilePhoto: data.profilePhoto || null,
      },
    });
  }

  async incrementTokenVersion(id: string): Promise<User> {
    return prisma.user.update({
      where: { id },
      data: {
        tokenVersion: {
          increment: 1,
        },
      },
    });
  }
}

export const usersRepository = new UsersRepository();
