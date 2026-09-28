import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { ApiResponse, AppError } from '../dto/api-response';
import { Prisma } from '@prisma/client';

export function errorHandler(
  err: any,
  req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  next: NextFunction
): void {
  if (err instanceof AppError) {
    ApiResponse.error(res, err.code, err.message, err.statusCode, err.details);
    return;
  }

  if (err instanceof ZodError) {
    const formattedErrors = err.errors.map((e) => ({
      field: e.path.join('.'),
      message: e.message,
    }));
    ApiResponse.error(
      res,
      'VALIDATION_ERROR',
      'One or more validation errors occurred',
      400,
      formattedErrors
    );
    return;
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === 'P2002') {
      const target = (err.meta?.target as string[]) || [];
      const field = target.join(', ') || 'field';
      ApiResponse.error(
        res,
        'DUPLICATE_RESOURCE',
        `A record with this ${field} already exists`,
        409
      );
      return;
    }
  }

  console.error('[Unhandled Error]', err);
  ApiResponse.error(
    res,
    'INTERNAL_SERVER_ERROR',
    'An unexpected internal server error occurred',
    500
  );
}
