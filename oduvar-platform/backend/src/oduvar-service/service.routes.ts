import { Router } from 'express';
import { serviceController } from './service.controller';
import { authMiddleware } from '../common/middleware/auth.middleware';
import { OduvarGuard } from '../common/guards/role.guards';

export const oduvarServiceRouter = Router();
export const oduvarServicePublicRouter = Router();

// ─── Private routes (Oduvar only) ────────────────────────────────────────────

// Services management
oduvarServiceRouter.get(
  '/me/services',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => serviceController.getMyServices(req, res, next)
);

oduvarServiceRouter.post(
  '/me/services',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => serviceController.createService(req, res, next)
);

oduvarServiceRouter.put(
  '/me/services/:serviceId',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => serviceController.updateService(req, res, next)
);

oduvarServiceRouter.delete(
  '/me/services/:serviceId',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => serviceController.deleteService(req, res, next)
);

// Granular Pricing management
oduvarServiceRouter.post(
  '/me/services/:serviceId/pricing',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => serviceController.createPricing(req, res, next)
);

oduvarServiceRouter.put(
  '/me/services/:serviceId/pricing/:pricingId',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => serviceController.updatePricing(req, res, next)
);

oduvarServiceRouter.delete(
  '/me/services/:serviceId/pricing/:pricingId',
  authMiddleware,
  OduvarGuard,
  (req, res, next) => serviceController.deletePricing(req, res, next)
);

// ─── Public routes ───────────────────────────────────────────────────────────

oduvarServicePublicRouter.get(
  '/:oduvarId/services',
  (req, res, next) => serviceController.getPublicServices(req, res, next)
);
