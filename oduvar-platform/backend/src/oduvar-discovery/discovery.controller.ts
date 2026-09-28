import { Request, Response, NextFunction } from 'express';
import { ApiResponse } from '../common/dto/api-response';
import { discoveryQuerySchema } from './discovery.dto';
import { discoveryService } from './discovery.service';

export class DiscoveryController {
  // GET /api/oduvars  (public, read-only)
  async search(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const query = discoveryQuerySchema.parse(req.query);
      ApiResponse.success(res, await discoveryService.search(query));
    } catch (e) {
      next(e);
    }
  }
}

export const discoveryController = new DiscoveryController();
