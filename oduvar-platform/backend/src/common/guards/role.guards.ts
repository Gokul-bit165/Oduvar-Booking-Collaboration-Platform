import { Request, Response, NextFunction } from 'express';
import { Role } from '@prisma/client';
import { ApiResponse } from '../dto/api-response';

export function requireRoles(...allowedRoles: Role[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      ApiResponse.error(res, 'AUTH_UNAUTHORIZED', 'Authentication is required', 401);
      return;
    }

    if (!allowedRoles.includes(req.user.role)) {
      ApiResponse.error(
        res,
        'AUTH_FORBIDDEN',
        `Access forbidden: required role [${allowedRoles.join(', ')}], got [${req.user.role}]`,
        403
      );
      return;
    }

    next();
  };
}

export const ClientGuard = requireRoles(Role.CLIENT);
export const OduvarGuard = requireRoles(Role.ODUVAR);
export const AdminGuard = requireRoles(Role.ADMIN);
export const ClientOrOduvarGuard = requireRoles(Role.CLIENT, Role.ODUVAR);
