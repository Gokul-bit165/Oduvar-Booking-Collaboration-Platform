import { Request, Response, NextFunction } from 'express';
import { verifyAccessToken } from '../utils/jwt';
import { ApiResponse, AppError } from '../dto/api-response';
import { prisma } from '../../config/database';
import { Role } from '@prisma/client';

export interface AuthenticatedUser {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: Role;
  profilePhoto: string | null;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

export async function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    ApiResponse.error(res, 'AUTH_UNAUTHORIZED', 'Authentication token is required', 401);
    return;
  }

  const token = authHeader.substring(7).trim();

  try {
    const payload = verifyAccessToken(token);

    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        profilePhoto: true,
        tokenVersion: true,
      },
    });

    if (!user) {
      ApiResponse.error(res, 'AUTH_USER_NOT_FOUND', 'User does not exist', 401);
      return;
    }

    if (payload.tokenVersion !== undefined && user.tokenVersion !== payload.tokenVersion) {
      ApiResponse.error(res, 'AUTH_TOKEN_REVOKED', 'Session has been invalidated. Please log in again', 401);
      return;
    }

    req.user = {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      profilePhoto: user.profilePhoto,
    };

    next();
  } catch (error: any) {
    if (error.name === 'TokenExpiredError') {
      ApiResponse.error(res, 'AUTH_TOKEN_EXPIRED', 'Access token has expired', 401);
      return;
    }
    ApiResponse.error(res, 'AUTH_INVALID_TOKEN', 'Invalid authentication token', 401);
  }
}
