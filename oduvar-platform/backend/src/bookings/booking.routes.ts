import { Router, Request, Response, NextFunction } from 'express';
import { authMiddleware } from '../common/middleware/auth.middleware';
import { ClientGuard, OduvarGuard } from '../common/guards/role.guards';
import { ApiResponse } from '../common/dto/api-response';
import { bookingService } from './booking.service';
import { createBookingSchema, listBookingsQuerySchema, reasonSchema } from './booking.dto';
import { notificationService } from '../notifications/notification.service';

/** Client-facing: /api/bookings */
export const bookingRouter = Router();
/** Oduvar-facing: mounted under /api/oduvars (…/me/bookings) */
export const oduvarBookingRouter = Router();
/** Any authenticated user: /api/notifications */
export const notificationRouter = Router();

type Handler = (req: Request, res: Response) => Promise<void>;
const wrap = (fn: Handler) => (req: Request, res: Response, next: NextFunction) => fn(req, res).catch(next);
const id = (req: Request, name = 'bookingId') => req.params[name] as string;

// ─── Client ──────────────────────────────────────────────────────────────────

bookingRouter.post('/', authMiddleware, ClientGuard, wrap(async (req, res) => {
  const input = createBookingSchema.parse(req.body);
  ApiResponse.success(res, { booking: await bookingService.create(req.user!.id, input) }, 201);
}));

bookingRouter.get('/', authMiddleware, ClientGuard, wrap(async (req, res) => {
  const q = listBookingsQuerySchema.parse(req.query);
  ApiResponse.success(res, await bookingService.listForClient(req.user!.id, q.status, q.page, q.pageSize));
}));

bookingRouter.get('/:bookingId', authMiddleware, ClientGuard, wrap(async (req, res) => {
  ApiResponse.success(res, { booking: await bookingService.getForClient(req.user!.id, id(req)) });
}));

bookingRouter.post('/:bookingId/cancel', authMiddleware, ClientGuard, wrap(async (req, res) => {
  const { reason } = reasonSchema.parse(req.body ?? {});
  ApiResponse.success(res, { booking: await bookingService.cancelByClient(req.user!.id, id(req), reason) });
}));

// ─── Oduvar ──────────────────────────────────────────────────────────────────

oduvarBookingRouter.get('/me/bookings', authMiddleware, OduvarGuard, wrap(async (req, res) => {
  const q = listBookingsQuerySchema.parse(req.query);
  ApiResponse.success(res, await bookingService.listForOduvar(req.user!.id, q.status, q.page, q.pageSize));
}));

oduvarBookingRouter.get('/me/bookings/:bookingId', authMiddleware, OduvarGuard, wrap(async (req, res) => {
  ApiResponse.success(res, { booking: await bookingService.getForOduvar(req.user!.id, id(req)) });
}));

oduvarBookingRouter.post('/me/bookings/:bookingId/accept', authMiddleware, OduvarGuard, wrap(async (req, res) => {
  ApiResponse.success(res, { booking: await bookingService.accept(req.user!.id, id(req)) });
}));

oduvarBookingRouter.post('/me/bookings/:bookingId/reject', authMiddleware, OduvarGuard, wrap(async (req, res) => {
  const { reason } = reasonSchema.parse(req.body ?? {});
  ApiResponse.success(res, { booking: await bookingService.reject(req.user!.id, id(req), reason) });
}));

oduvarBookingRouter.post('/me/bookings/:bookingId/complete', authMiddleware, OduvarGuard, wrap(async (req, res) => {
  ApiResponse.success(res, { booking: await bookingService.complete(req.user!.id, id(req)) });
}));

// ─── In-app notifications (any authenticated user, own rows only) ────────────

notificationRouter.get('/', authMiddleware, wrap(async (req, res) => {
  const page = Math.max(1, Number(req.query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(req.query.pageSize) || 30));
  ApiResponse.success(res, await notificationService.list(req.user!.id, page, pageSize, req.query.unreadOnly === 'true'));
}));

notificationRouter.post('/read-all', authMiddleware, wrap(async (req, res) => {
  ApiResponse.success(res, await notificationService.markAllRead(req.user!.id));
}));

notificationRouter.post('/:notificationId/read', authMiddleware, wrap(async (req, res) => {
  ApiResponse.success(res, await notificationService.markRead(req.user!.id, id(req, 'notificationId')));
}));
