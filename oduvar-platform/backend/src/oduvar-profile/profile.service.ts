import { profileRepository } from './profile.repository';
import { CreateOrUpdateProfileInput, ReorderPhotosInput } from './profile.dto';
import { AppError } from '../common/dto/api-response';
import { ImageStorage } from '../common/storage/image-storage';
import path from 'path';

// ─── Serialized public/private shapes ────────────────────────────────────────

function toPublicProfile(raw: any) {
  if (!raw) return null;
  const { user, photos, skills, instruments, ...profile } = raw;
  return {
    id: profile.id,
    isPublished: profile.isPublished,
    bio: profile.bio,
    location: profile.location,
    performanceTypes: profile.performanceTypes,
    songCategories: profile.songCategories,
    eventTypes: profile.eventTypes ?? [],
    transport: profile.transport,
    collaborationEnabled: profile.collaborationEnabled,
    createdAt: profile.createdAt,
    updatedAt: profile.updatedAt,
    // User public fields only – never expose passwordHash, tokenVersion, etc.
    owner: {
      id: user.id,
      name: user.name,
      profilePhoto: user.profilePhoto,
    },
    photos: photos.map((p: any) => ({
      id: p.id,
      imageUrl: p.imageUrl,
      displayOrder: p.displayOrder,
    })),
    skills: skills.map((s: any) => ({
      id: s.skill.id,
      name: s.skill.name,
      slug: s.skill.slug,
    })),
    instruments: instruments.map((i: any) => ({
      id: i.instrument.id,
      name: i.instrument.name,
      slug: i.instrument.slug,
    })),
  };
}

function toPrivateProfile(raw: any) {
  if (!raw) return null;
  const pub = toPublicProfile(raw);
  if (!pub) return null;
  return {
    ...pub,
    // Authenticated owner also sees phone (for own profile only)
    owner: {
      ...pub.owner,
      phone: raw.user.phone,
    },
  };
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class ProfileService {
  constructor(private readonly storage: ImageStorage) {}

  async getMyProfile(userId: string) {
    const profile = await profileRepository.findByUserId(userId);
    return toPrivateProfile(profile);
  }

  async createProfile(userId: string, input: CreateOrUpdateProfileInput) {
    const existing = await profileRepository.findByUserId(userId);
    if (existing) {
      throw new AppError('PROFILE_EXISTS', 'Profile already exists. Use PUT to update.', 409);
    }
    const created = await profileRepository.create(userId, input);
    return toPrivateProfile(created);
  }

  async updateProfile(userId: string, input: CreateOrUpdateProfileInput) {
    const profile = await profileRepository.findByUserId(userId);
    if (!profile) {
      throw new AppError('PROFILE_NOT_FOUND', 'Profile not found. Use POST to create.', 404);
    }
    const updated = await profileRepository.update(profile.id, input);
    return toPrivateProfile(updated);
  }

  async deleteProfile(userId: string) {
    const profile = await profileRepository.findByUserId(userId);
    if (!profile) {
      throw new AppError('PROFILE_NOT_FOUND', 'Profile not found', 404);
    }
    await profileRepository.delete(profile.id);
    return { message: 'Profile deleted successfully' };
  }

  async getPublicProfile(oduvarUserId: string) {
    const profile = await profileRepository.findPublicById(oduvarUserId);
    if (!profile) {
      throw new AppError('PROFILE_NOT_FOUND', 'Oduvar profile not found or is not public', 404);
    }
    return toPublicProfile(profile);
  }

  // ─── Photos ────────────────────────────────────────────────────────────────

  async uploadPhoto(
    userId: string,
    buffer: Buffer,
    originalName: string,
    mimetype: string
  ) {
    const profile = await profileRepository.findByUserId(userId);
    if (!profile) {
      throw new AppError('PROFILE_NOT_FOUND', 'Create a profile before uploading photos', 404);
    }

    const count = await profileRepository.countPhotos(profile.id);
    if (count >= 5) {
      throw new AppError('PROFILE_PHOTO_LIMIT', 'Maximum 5 gallery photos allowed', 422);
    }

    const { url } = await this.storage.save(buffer, originalName, mimetype);
    const photo = await profileRepository.addPhoto(profile.id, url, count + 1);
    return photo;
  }

  async deletePhoto(userId: string, photoId: string) {
    const profile = await profileRepository.findByUserId(userId);
    if (!profile) {
      throw new AppError('PROFILE_NOT_FOUND', 'Profile not found', 404);
    }

    // Get photo to extract filename for file deletion
    const photo = await profileRepository.findPhotoById(photoId);
    if (photo && photo.profileId !== profile.id) {
      throw new AppError('PHOTO_FORBIDDEN', 'You do not own this photo', 403);
    }

    await profileRepository.deletePhoto(photoId, profile.id);

    // Try to delete local file if applicable (best-effort)
    if (photo) {
      try {
        const filename = path.basename(photo.imageUrl);
        await this.storage.delete(filename);
      } catch {
        // Non-fatal: file may not exist locally
      }
    }

    return { message: 'Photo deleted successfully' };
  }

  async reorderPhotos(userId: string, input: ReorderPhotosInput) {
    const profile = await profileRepository.findByUserId(userId);
    if (!profile) {
      throw new AppError('PROFILE_NOT_FOUND', 'Profile not found', 404);
    }

    // Ensure all photos belong to this profile
    const owned = profile.photos.map((p) => p.id);
    for (const item of input.photos) {
      if (!owned.includes(item.id)) {
        throw new AppError('PHOTO_FORBIDDEN', `Photo ${item.id} does not belong to your profile`, 403);
      }
    }

    await profileRepository.reorderPhotos(profile.id, input);
    return { message: 'Photos reordered successfully' };
  }
}
