import { Router } from 'express';
import { authController } from './auth.controller';
import { authMiddleware } from '../common/middleware/auth.middleware';
import {
  ClientGuard,
  OduvarGuard,
  AdminGuard,
} from '../common/guards/role.guards';
import { ApiResponse } from '../common/dto/api-response';

export const authRouter = Router();

// Public routes
authRouter.post('/register', (req, res, next) => authController.register(req, res, next));
authRouter.post('/login', (req, res, next) => authController.login(req, res, next));
authRouter.post('/refresh', (req, res, next) => authController.refresh(req, res, next));

// Authenticated routes
authRouter.get('/me', authMiddleware, (req, res, next) => authController.me(req, res, next));
authRouter.post('/logout', authMiddleware, (req, res, next) => authController.logout(req, res, next));

// Role-protected test verification routes
authRouter.get('/protected/client', authMiddleware, ClientGuard, (req, res) => {
  ApiResponse.success(res, {
    message: 'Welcome to Client Area',
    user: req.user,
  });
});

authRouter.get('/protected/oduvar', authMiddleware, OduvarGuard, (req, res) => {
  ApiResponse.success(res, {
    message: 'Welcome to Oduvar Dashboard',
    user: req.user,
  });
});

authRouter.get('/protected/admin', authMiddleware, AdminGuard, (req, res) => {
  ApiResponse.success(res, {
    message: 'Welcome to Admin Control Panel',
    user: req.user,
  });
});
