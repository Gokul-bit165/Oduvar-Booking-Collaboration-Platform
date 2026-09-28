import { Router, Request, Response } from 'express';
import { prisma } from '../config/database';
import { ApiResponse } from '../common/dto/api-response';
import { PERFORMANCE_TYPES, SONG_CATEGORIES } from '../common/constants/reference-data';

export const referenceRouter = Router();

// GET /api/skills
referenceRouter.get('/skills', async (_req: Request, res: Response) => {
  try {
    const skills = await prisma.skill.findMany({
      orderBy: { sortOrder: 'asc' },
      select: { id: true, name: true, slug: true, isPredefined: true },
    });
    ApiResponse.success(res, { skills });
  } catch (e: any) {
    ApiResponse.error(res, 'FETCH_ERROR', 'Failed to fetch skills', 500);
  }
});

// GET /api/instruments
referenceRouter.get('/instruments', async (_req: Request, res: Response) => {
  try {
    const instruments = await prisma.instrument.findMany({
      orderBy: { sortOrder: 'asc' },
      select: { id: true, name: true, slug: true, isPredefined: true },
    });
    ApiResponse.success(res, { instruments });
  } catch (e: any) {
    ApiResponse.error(res, 'FETCH_ERROR', 'Failed to fetch instruments', 500);
  }
});

// GET /api/performance-types
referenceRouter.get('/performance-types', (_req: Request, res: Response) => {
  ApiResponse.success(res, {
    performanceTypes: PERFORMANCE_TYPES.map((t) => ({ key: t, label: t.charAt(0) + t.slice(1).toLowerCase() })),
  });
});

// GET /api/song-categories
referenceRouter.get('/song-categories', (_req: Request, res: Response) => {
  ApiResponse.success(res, { songCategories: SONG_CATEGORIES });
});

// GET /api/services
referenceRouter.get('/services', async (_req: Request, res: Response) => {
  try {
    const services = await prisma.service.findMany({
      where: { isActive: true },
      orderBy: { createdAt: 'asc' },
      select: { id: true, name: true, category: true, description: true, isActive: true },
    });
    ApiResponse.success(res, { services });
  } catch (e: any) {
    ApiResponse.error(res, 'FETCH_ERROR', 'Failed to fetch services', 500);
  }
});

