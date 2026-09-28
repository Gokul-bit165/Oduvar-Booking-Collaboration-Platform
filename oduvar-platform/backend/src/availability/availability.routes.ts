import { Router, Request, Response, NextFunction } from 'express';
import { authMiddleware } from '../common/middleware/auth.middleware';
import { OduvarGuard } from '../common/guards/role.guards';
import { ApiResponse } from '../common/dto/api-response';
import { availabilityService } from './availability.service';
import {
  availabilityQuerySchema,
  createOverrideSchema,
  updateOverrideSchema,
  updateWeeklySchema,
} from './availability.dto';

export const availabilityRouter = Router();
export const availabilityPublicRouter = Router();

type Handler = (req: Request, res: Response) => Promise<void>;
const wrap = (fn: Handler) => (req: Request, res: Response, next: NextFunction) => fn(req, res).catch(next);

// ─── Owner (ODUVAR only) ─────────────────────────────────────────────────────

availabilityRouter.get(
  '/me/availability',
  authMiddleware,
  OduvarGuard,
  wrap(async (req, res) => {
    const query = availabilityQuerySchema.parse(req.query);
    ApiResponse.success(res, await availabilityService.getMyAvailability(req.user!.id, query));
  })
);

availabilityRouter.put(
  '/me/availability/weekly',
  authMiddleware,
  OduvarGuard,
  wrap(async (req, res) => {
    const input = updateWeeklySchema.parse(req.body);
    ApiResponse.success(res, await availabilityService.updateWeekly(req.user!.id, input));
  })
);

availabilityRouter.get(
  '/me/availability/overrides',
  authMiddleware,
  OduvarGuard,
  wrap(async (req, res) => {
    ApiResponse.success(res, { overrides: await availabilityService.listOverrides(req.user!.id) });
  })
);

availabilityRouter.post(
  '/me/availability/overrides',
  authMiddleware,
  OduvarGuard,
  wrap(async (req, res) => {
    const input = createOverrideSchema.parse(req.body);
    ApiResponse.success(res, { override: await availabilityService.createOverride(req.user!.id, input) }, 201);
  })
);

availabilityRouter.put(
  '/me/availability/overrides/:overrideId',
  authMiddleware,
  OduvarGuard,
  wrap(async (req, res) => {
    const input = updateOverrideSchema.parse(req.body);
    const override = await availabilityService.updateOverride(req.user!.id, req.params.overrideId as string, input);
    ApiResponse.success(res, { override });
  })
);

availabilityRouter.delete(
  '/me/availability/overrides/:overrideId',
  authMiddleware,
  OduvarGuard,
  wrap(async (req, res) => {
    ApiResponse.success(res, await availabilityService.deleteOverride(req.user!.id, req.params.overrideId as string));
  })
);

// ─── Public (read-only) ──────────────────────────────────────────────────────
// GET /api/oduvars/:oduvarId/availability[?month=YYYY-MM | ?date=YYYY-MM-DD][&duration=minutes]

availabilityPublicRouter.get(
  '/:oduvarId/availability',
  wrap(async (req, res) => {
    const query = availabilityQuerySchema.parse(req.query);
    ApiResponse.success(res, await availabilityService.getPublicAvailability(req.params.oduvarId as string, query));
  })
);
