import { Request, Response, NextFunction } from 'express';
import { authService } from './auth.service';
import { registerSchema, loginSchema, refreshSchema } from './auth.dto';
import { ApiResponse } from '../common/dto/api-response';

export class AuthController {
  async register(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const validated = registerSchema.parse(req.body);
      const result = await authService.register(validated);
      ApiResponse.success(res, result, 201);
    } catch (error) {
      next(error);
    }
  }

  async login(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const validated = loginSchema.parse(req.body);
      const result = await authService.login(validated);
      ApiResponse.success(res, result, 200);
    } catch (error) {
      next(error);
    }
  }

  async refresh(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const validated = refreshSchema.parse(req.body);
      const result = await authService.refreshTokens(validated.refreshToken);
      ApiResponse.success(res, result, 200);
    } catch (error) {
      next(error);
    }
  }

  async logout(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) {
        ApiResponse.error(res, 'AUTH_UNAUTHORIZED', 'Authentication is required', 401);
        return;
      }
      const result = await authService.logout(req.user.id);
      ApiResponse.success(res, result, 200);
    } catch (error) {
      next(error);
    }
  }

  async me(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      if (!req.user) {
        ApiResponse.error(res, 'AUTH_UNAUTHORIZED', 'Authentication is required', 401);
        return;
      }
      const user = await authService.getMe(req.user.id);
      ApiResponse.success(res, { user }, 200);
    } catch (error) {
      next(error);
    }
  }
}

export const authController = new AuthController();
