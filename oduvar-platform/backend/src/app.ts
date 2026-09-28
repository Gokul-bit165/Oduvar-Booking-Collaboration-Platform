import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import path from 'path';
import { env } from './config/environment';
import { authRouter } from './auth/auth.routes';
import { oduvarProfileRouter, oduvarPublicRouter } from './oduvar-profile/profile.routes';
import { oduvarServiceRouter, oduvarServicePublicRouter } from './oduvar-service/service.routes';
import { availabilityRouter, availabilityPublicRouter } from './availability/availability.routes';
import { discoveryRouter } from './oduvar-discovery/discovery.routes';
import { bookingRouter, oduvarBookingRouter, notificationRouter } from './bookings/booking.routes';
import { registerBookingOccupiedProviders } from './bookings/booking.occupied';
import { referenceRouter } from './reference/reference.routes';
import { errorHandler } from './common/middleware/error.middleware';
import { ApiResponse } from './common/dto/api-response';

export function createApp(): Application {
  const app = express();

  // Phase 6: confirmed bookings feed the Phase 4 availability engine.
  registerBookingOccupiedProviders();

  // Basic CORS configuration
  app.use(
    cors({
      origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(','),
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    })
  );

  // Body parser
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  // Serve uploaded images (development only)
  app.use('/uploads', express.static(path.resolve(process.cwd(), 'uploads')));

  // Health check endpoint
  app.get('/health', (req: Request, res: Response) => {
    ApiResponse.success(res, {
      status: 'OK',
      timestamp: new Date().toISOString(),
      service: 'Online Oduvar Booking & Collaboration Platform API',
      version: '6.0.0-phase6',
    });
  });

  // Mount API modules
  app.use('/api/auth', authRouter);
  app.use('/api/oduvars', oduvarProfileRouter);
  app.use('/api/oduvars', oduvarPublicRouter);
  app.use('/api/oduvars', oduvarServiceRouter);
  app.use('/api/oduvars', oduvarServicePublicRouter);
  app.use('/api/oduvars', oduvarBookingRouter); // /me/bookings must precede the /:oduvarId routes
  app.use('/api/oduvars', discoveryRouter);
  app.use('/api/oduvars', availabilityRouter);
  app.use('/api/oduvars', availabilityPublicRouter);
  app.use('/api/bookings', bookingRouter);
  app.use('/api/notifications', notificationRouter);
  app.use('/api', referenceRouter);

  // 404 handler
  app.use((req: Request, res: Response) => {
    ApiResponse.error(res, 'NOT_FOUND', `Route ${req.method} ${req.originalUrl} not found`, 404);
  });

  // Global Error Handler
  app.use(errorHandler);

  return app;
}
