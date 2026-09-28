import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import { profileController } from './profile.controller';
import { authMiddleware } from '../common/middleware/auth.middleware';
import { OduvarGuard } from '../common/guards/role.guards';
import { ProfileService } from './profile.service';
import { LocalImageStorage } from '../common/storage/image-storage';

// ─── Storage setup (swap LocalImageStorage → S3Storage in production) ─────────
const uploadsDir = path.resolve(process.cwd(), 'uploads');
const baseUrl = process.env.BASE_URL || 'http://localhost:5000';
const imageStorage = new LocalImageStorage(uploadsDir, baseUrl);
export const profileService = new ProfileService(imageStorage);

// ─── Multer (memory storage so we hand buffer to our abstraction) ─────────────
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
  fileFilter(_req, file, cb) {
    const allowed = ['image/jpeg', 'image/png', 'image/webp'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG, and WebP images are allowed'));
    }
  },
});

export const oduvarProfileRouter = Router();
export const oduvarPublicRouter = Router();

// ─── Private routes (Oduvar only) ────────────────────────────────────────────
oduvarProfileRouter.get(
  '/me/profile',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => profileController.getMyProfile(req, res, next)
);

oduvarProfileRouter.post(
  '/me/profile',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => profileController.createProfile(req, res, next)
);

oduvarProfileRouter.put(
  '/me/profile',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => profileController.updateProfile(req, res, next)
);

oduvarProfileRouter.delete(
  '/me/profile',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => profileController.deleteProfile(req, res, next)
);

// Photos – reorder before :photoId to avoid route collision
oduvarProfileRouter.put(
  '/me/profile/photos/reorder',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => profileController.reorderPhotos(req, res, next)
);

oduvarProfileRouter.post(
  '/me/profile/photos',
  authMiddleware,
  OduvarGuard,
  upload.single('photo'),
  (req, res, next) => profileController.uploadPhoto(req, res, next)
);

oduvarProfileRouter.delete(
  '/me/profile/photos/:photoId',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => profileController.deletePhoto(req, res, next)
);

// ─── Public routes (no auth required) ────────────────────────────────────────
oduvarPublicRouter.get(
  '/:oduvarId/profile',
  (req, res, next) => profileController.getPublicProfile(req, res, next)
);
