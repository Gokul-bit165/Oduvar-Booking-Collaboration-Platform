import { Request, Response, NextFunction } from 'express';
import { serviceService } from './service.service';
import { ApiResponse } from '../common/dto/api-response';
import {
  createOduvarServiceSchema,
  updateOduvarServiceSchema,
  createServicePricingSchema,
  updateServicePricingSchema,
} from './service.dto';

export class ServiceController {
  // GET /api/oduvars/me/services
  async getMyServices(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const services = await serviceService.getMyServices(req.user!.id);
      ApiResponse.success(res, { services });
    } catch (e) {
      next(e);
    }
  }

  // POST /api/oduvars/me/services
  async createService(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const input = createOduvarServiceSchema.parse(req.body);
      const service = await serviceService.createService(req.user!.id, input);
      ApiResponse.success(res, { service }, 201);
    } catch (e) {
      next(e);
    }
  }

  // PUT /api/oduvars/me/services/:serviceId
  async updateService(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const input = updateOduvarServiceSchema.parse(req.body);
      const service = await serviceService.updateService(req.user!.id, req.params.serviceId as string, input);
      ApiResponse.success(res, { service });
    } catch (e) {
      next(e);
    }
  }

  // DELETE /api/oduvars/me/services/:serviceId
  async deleteService(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await serviceService.deleteService(req.user!.id, req.params.serviceId as string);
      ApiResponse.success(res, result);
    } catch (e) {
      next(e);
    }
  }

  // POST /api/oduvars/me/services/:serviceId/pricing
  async createPricing(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const input = createServicePricingSchema.parse(req.body);
      const pricing = await serviceService.createPricing(req.user!.id, req.params.serviceId as string, input);
      ApiResponse.success(res, { pricing }, 201);
    } catch (e) {
      next(e);
    }
  }

  // PUT /api/oduvars/me/services/:serviceId/pricing/:pricingId
  async updatePricing(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const input = updateServicePricingSchema.parse(req.body);
      const pricing = await serviceService.updatePricing(
        req.user!.id,
        req.params.serviceId as string,
        req.params.pricingId as string,
        input
      );
      ApiResponse.success(res, { pricing });
    } catch (e) {
      next(e);
    }
  }

  // DELETE /api/oduvars/me/services/:serviceId/pricing/:pricingId
  async deletePricing(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await serviceService.deletePricing(
        req.user!.id,
        req.params.serviceId as string,
        req.params.pricingId as string
      );
      ApiResponse.success(res, result);
    } catch (e) {
      next(e);
    }
  }

  // GET /api/oduvars/:oduvarId/services
  async getPublicServices(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const services = await serviceService.getPublicServices(req.params.oduvarId as string);
      ApiResponse.success(res, { services });
    } catch (e) {
      next(e);
    }
  }
}

export const serviceController = new ServiceController();
