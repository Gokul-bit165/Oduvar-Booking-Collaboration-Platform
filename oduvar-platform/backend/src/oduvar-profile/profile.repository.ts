import { prisma } from '../config/database';
import { CreateOrUpdateProfileInput, ReorderPhotosInput } from './profile.dto';
import { AppError } from '../common/dto/api-response';

const MAX_GALLERY_PHOTOS = 5;

// ─── Prisma include shape ─────────────────────────────────────────────────────
const profileInclude = {
  user: {
    select: {
      id: true,
      name: true,
      email: true,
      phone: true,
      profilePhoto: true,
      role: true,
    },
  },
  photos: {
    orderBy: { displayOrder: 'asc' as const },
  },
  skills: {
    include: { skill: true },
  },
  instruments: {
    include: { instrument: true },
  },
} as const;

export class ProfileRepository {
  // ─── Read ───────────────────────────────────────────────────────────────────

  async findByUserId(userId: string) {
    return prisma.oduvarProfile.findUnique({
      where: { userId },
      include: profileInclude,
    });
  }

  async findById(id: string) {
    return prisma.oduvarProfile.findUnique({
      where: { id },
      include: profileInclude,
    });
  }

  async findPublicById(oduvarUserId: string) {
    // Public fetch by the Oduvar USER id, only if published
    return prisma.oduvarProfile.findFirst({
      where: { userId: oduvarUserId, isPublished: true },
      include: profileInclude,
    });
  }

  // ─── Create ─────────────────────────────────────────────────────────────────

  async create(userId: string, data: CreateOrUpdateProfileInput) {
    const { skillIds = [], instrumentIds = [], ...profileData } = data;

    return prisma.oduvarProfile.create({
      data: {
        userId,
        ...profileData,
        skills: {
          create: skillIds.map((sid) => ({ skillId: sid })),
        },
        instruments: {
          create: instrumentIds.map((iid) => ({ instrumentId: iid })),
        },
      },
      include: profileInclude,
    });
  }

  // ─── Update ─────────────────────────────────────────────────────────────────

  async update(profileId: string, data: CreateOrUpdateProfileInput) {
    const { skillIds = [], instrumentIds = [], ...profileData } = data;

    return prisma.$transaction(async (tx) => {
      // Delete existing many-many links and replace
      await tx.oduvarProfileSkill.deleteMany({ where: { profileId } });
      await tx.oduvarProfileInstrument.deleteMany({ where: { profileId } });

      return tx.oduvarProfile.update({
        where: { id: profileId },
        data: {
          ...profileData,
          skills: {
            create: skillIds.map((sid) => ({ skillId: sid })),
          },
          instruments: {
            create: instrumentIds.map((iid) => ({ instrumentId: iid })),
          },
        },
        include: profileInclude,
      });
    });
  }

  // ─── Delete ─────────────────────────────────────────────────────────────────

  async delete(profileId: string) {
    return prisma.oduvarProfile.delete({ where: { id: profileId } });
  }

  // ─── Photos ─────────────────────────────────────────────────────────────────

  async countPhotos(profileId: string): Promise<number> {
    return prisma.oduvarPhoto.count({ where: { profileId } });
  }

  async addPhoto(profileId: string, imageUrl: string, displayOrder: number) {
    const count = await this.countPhotos(profileId);
    if (count >= MAX_GALLERY_PHOTOS) {
      throw new AppError(
        'PROFILE_PHOTO_LIMIT',
        `Maximum ${MAX_GALLERY_PHOTOS} gallery photos allowed`,
        422
      );
    }
    return prisma.oduvarPhoto.create({
      data: { profileId, imageUrl, displayOrder },
    });
  }

  async deletePhoto(photoId: string, profileId: string) {
    const photo = await prisma.oduvarPhoto.findFirst({
      where: { id: photoId, profileId },
    });
    if (!photo) {
      throw new AppError('PHOTO_NOT_FOUND', 'Photo not found or access denied', 404);
    }
    return prisma.oduvarPhoto.delete({ where: { id: photoId } });
  }

  async reorderPhotos(profileId: string, input: ReorderPhotosInput) {
    return prisma.$transaction(
      input.photos.map((p) =>
        prisma.oduvarPhoto.update({
          where: { id: p.id },
          data: { displayOrder: p.displayOrder },
        })
      )
    );
  }

  async findPhotoById(photoId: string) {
    return prisma.oduvarPhoto.findUnique({ where: { id: photoId } });
  }
}

export const profileRepository = new ProfileRepository();
