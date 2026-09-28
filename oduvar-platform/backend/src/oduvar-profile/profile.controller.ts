import { Request, Response, NextFunction } from 'express';
import { profileService } from './profile.routes';
import { createOrUpdateProfileSchema, reorderPhotosSchema } from './profile.dto';
import { ApiResponse } from '../common/dto/api-response';

export class ProfileController {
  // GET /api/oduvars/me/profile
  async getMyProfile(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const profile = await profileService.getMyProfile(req.user!.id);
      ApiResponse.success(res, { profile });
    } catch (e) {
      next(e);
    }
  }

  // POST /api/oduvars/me/profile
  async createProfile(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const input = createOrUpdateProfileSchema.parse(req.body);
      const profile = await profileService.createProfile(req.user!.id, input);
      ApiResponse.success(res, { profile }, 201);
    } catch (e) {
      next(e);
    }
  }

  // PUT /api/oduvars/me/profile
  async updateProfile(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const input = createOrUpdateProfileSchema.parse(req.body);
      const profile = await profileService.updateProfile(req.user!.id, input);
      ApiResponse.success(res, { profile });
    } catch (e) {
      next(e);
    }
  }

  // DELETE /api/oduvars/me/profile
  async deleteProfile(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await profileService.deleteProfile(req.user!.id);
      ApiResponse.success(res, result);
    } catch (e) {
      next(e);
    }
  }

  // POST /api/oduvars/me/profile/photos
  async uploadPhoto(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.file) {
        ApiResponse.error(res, 'PHOTO_MISSING', 'No image file provided', 400);
        return;
      }
      const photo = await profileService.uploadPhoto(
        req.user!.id,
        req.file.buffer,
        req.file.originalname,
        req.file.mimetype
      );
      ApiResponse.success(res, { photo }, 201);
    } catch (e) {
      next(e);
    }
  }

  // DELETE /api/oduvars/me/profile/photos/:photoId
  async deletePhoto(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await profileService.deletePhoto(req.user!.id, req.params.photoId as string);
      ApiResponse.success(res, result);
    } catch (e) {
      next(e);
    }
  }

  // PUT /api/oduvars/me/profile/photos/reorder
  async reorderPhotos(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const input = reorderPhotosSchema.parse(req.body);
      const result = await profileService.reorderPhotos(req.user!.id, input);
      ApiResponse.success(res, result);
    } catch (e) {
      next(e);
    }
  }

  // GET /api/oduvars/:oduvarId/profile  (public)
  async getPublicProfile(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const profile = await profileService.getPublicProfile(req.params.oduvarId as string);
      ApiResponse.success(res, { profile });
    } catch (e) {
      next(e);
    }
  }
}

export const profileController = new ProfileController();
