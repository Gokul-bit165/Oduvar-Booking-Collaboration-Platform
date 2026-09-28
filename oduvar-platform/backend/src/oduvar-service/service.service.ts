import { serviceRepository } from './service.repository';
import { CreateOduvarServiceInput, UpdateOduvarServiceInput, CreateServicePricingInput, UpdateServicePricingInput } from './service.dto';
import { AppError } from '../common/dto/api-response';
import { TransportOption } from '@prisma/client';

export class ServiceService {
  private formatService(s: any) {
    return {
      id: s.id,
      profileId: s.profileId,
      serviceId: s.serviceId,
      name: s.service?.name,
      category: s.service?.category,
      baseDescription: s.service?.description,
      customDescription: s.customDescription,
      transport: s.transport,
      transportFee: s.transportFee !== null && s.transportFee !== undefined ? Number(s.transportFee) : null,
      isActive: s.isActive,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      pricings: (s.pricings || []).map((p: any) => ({
        id: p.id,
        oduvarServiceId: p.oduvarServiceId,
        durationMinutes: p.durationMinutes,
        amount: Number(p.amount),
        currency: p.currency,
        isActive: p.isActive,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      })),
    };
  }

  async getMyServices(userId: string) {
    const profile = await serviceRepository.ensureProfileExists(userId);
    const services = await serviceRepository.findServicesByProfileId(profile.id);
    return services.map(this.formatService);
  }

  async createService(userId: string, input: CreateOduvarServiceInput) {
    const profile = await serviceRepository.ensureProfileExists(userId);

    // Verify base service exists and is active
    const baseService = await serviceRepository.findBaseServiceById(input.serviceId);
    if (!baseService || !baseService.isActive) {
      throw new AppError('NOT_FOUND', 'Service not found or inactive', 404);
    }

    // Check if Oduvar already created this service
    const existing = await serviceRepository.findOduvarServiceByProfileAndService(profile.id, input.serviceId);
    if (existing) {
      throw new AppError('DUPLICATE_RESOURCE', 'You have already added this service to your profile', 409);
    }

    // Validate transport configuration
    if (input.transport === TransportOption.ADDITIONAL_FEE) {
      if (input.transportFee === undefined || input.transportFee === null || input.transportFee <= 0) {
        throw new AppError('VALIDATION_ERROR', 'Transport fee must be greater than zero when Additional Fee is selected', 400);
      }
    }

    // Validate durations
    if (input.pricings && input.pricings.length > 0) {
      const durations = new Set<number>();
      for (const p of input.pricings) {
        if (p.durationMinutes < 30) {
          throw new AppError('VALIDATION_ERROR', 'Minimum duration must be at least 30 minutes', 400);
        }
        if (p.amount <= 0) {
          throw new AppError('VALIDATION_ERROR', 'Amount must be greater than zero', 400);
        }
        if (durations.has(p.durationMinutes)) {
          throw new AppError('DUPLICATE_RESOURCE', `Duplicate duration ${p.durationMinutes} minutes is not allowed`, 409);
        }
        durations.add(p.durationMinutes);
      }
    }

    const created = await serviceRepository.createOduvarService(profile.id, input);
    return this.formatService(created);
  }

  async updateService(userId: string, serviceId: string, input: UpdateOduvarServiceInput) {
    const existing = await serviceRepository.findOduvarServiceById(serviceId);
    if (!existing) {
      throw new AppError('NOT_FOUND', 'Service not found', 404);
    }

    // Ownership check
    if (existing.profile.userId !== userId) {
      throw new AppError('FORBIDDEN', 'You do not own this service', 403);
    }

    const effectiveTransport = input.transport !== undefined ? input.transport : existing.transport;
    if (effectiveTransport === TransportOption.ADDITIONAL_FEE) {
      const fee = input.transportFee !== undefined ? input.transportFee : (existing.transportFee ? Number(existing.transportFee) : 0);
      if (fee === null || fee <= 0) {
        throw new AppError('VALIDATION_ERROR', 'Transport fee must be greater than zero when Additional Fee is selected', 400);
      }
    }

    const updated = await serviceRepository.updateOduvarService(serviceId, input);
    return this.formatService(updated);
  }

  async deleteService(userId: string, serviceId: string) {
    const existing = await serviceRepository.findOduvarServiceById(serviceId);
    if (!existing) {
      throw new AppError('NOT_FOUND', 'Service not found', 404);
    }

    // Ownership check
    if (existing.profile.userId !== userId) {
      throw new AppError('FORBIDDEN', 'You do not own this service', 403);
    }

    await serviceRepository.deleteOduvarService(serviceId);
    return { success: true, message: 'Service deleted successfully' };
  }

  async createPricing(userId: string, serviceId: string, input: CreateServicePricingInput) {
    const existing = await serviceRepository.findOduvarServiceById(serviceId);
    if (!existing) {
      throw new AppError('NOT_FOUND', 'Service not found', 404);
    }

    // Ownership check
    if (existing.profile.userId !== userId) {
      throw new AppError('FORBIDDEN', 'You do not own this service', 403);
    }

    // Rule: minimum duration 30 minutes
    if (input.durationMinutes < 30) {
      throw new AppError('VALIDATION_ERROR', 'Minimum duration must be at least 30 minutes', 400);
    }

    if (input.amount <= 0) {
      throw new AppError('VALIDATION_ERROR', 'Amount must be greater than zero', 400);
    }

    // Check duplicate duration
    const duplicate = await serviceRepository.findPricingByDuration(serviceId, input.durationMinutes);
    if (duplicate) {
      throw new AppError('DUPLICATE_RESOURCE', `Pricing for ${input.durationMinutes} minutes already exists for this service`, 409);
    }

    const created = await serviceRepository.createPricing(serviceId, input);
    return {
      id: created.id,
      oduvarServiceId: created.oduvarServiceId,
      durationMinutes: created.durationMinutes,
      amount: Number(created.amount),
      currency: created.currency,
      isActive: created.isActive,
      createdAt: created.createdAt,
      updatedAt: created.updatedAt,
    };
  }

  async updatePricing(userId: string, serviceId: string, pricingId: string, input: UpdateServicePricingInput) {
    const pricing = await serviceRepository.findPricingById(pricingId);
    if (!pricing || pricing.oduvarServiceId !== serviceId) {
      throw new AppError('NOT_FOUND', 'Pricing not found', 404);
    }

    // Ownership check
    if (pricing.oduvarService.profile.userId !== userId) {
      throw new AppError('FORBIDDEN', 'You do not own this service pricing', 403);
    }

    if (input.durationMinutes !== undefined) {
      if (input.durationMinutes < 30) {
        throw new AppError('VALIDATION_ERROR', 'Minimum duration must be at least 30 minutes', 400);
      }
      if (input.durationMinutes !== pricing.durationMinutes) {
        const duplicate = await serviceRepository.findPricingByDuration(serviceId, input.durationMinutes);
        if (duplicate && duplicate.id !== pricingId) {
          throw new AppError('DUPLICATE_RESOURCE', `Pricing for ${input.durationMinutes} minutes already exists`, 409);
        }
      }
    }

    if (input.amount !== undefined && input.amount <= 0) {
      throw new AppError('VALIDATION_ERROR', 'Amount must be greater than zero', 400);
    }

    const updated = await serviceRepository.updatePricing(pricingId, input);
    return {
      id: updated.id,
      oduvarServiceId: updated.oduvarServiceId,
      durationMinutes: updated.durationMinutes,
      amount: Number(updated.amount),
      currency: updated.currency,
      isActive: updated.isActive,
      createdAt: updated.createdAt,
      updatedAt: updated.updatedAt,
    };
  }

  async deletePricing(userId: string, serviceId: string, pricingId: string) {
    const pricing = await serviceRepository.findPricingById(pricingId);
    if (!pricing || pricing.oduvarServiceId !== serviceId) {
      throw new AppError('NOT_FOUND', 'Pricing not found', 404);
    }

    // Ownership check
    if (pricing.oduvarService.profile.userId !== userId) {
      throw new AppError('FORBIDDEN', 'You do not own this service pricing', 403);
    }

    await serviceRepository.deletePricing(pricingId);
    return { success: true, message: 'Pricing deleted successfully' };
  }

  async getPublicServices(oduvarUserId: string) {
    const services = await serviceRepository.findPublicServicesByUserId(oduvarUserId);
    if (!services) {
      throw new AppError('NOT_FOUND', 'Oduvar profile not found or not published', 404);
    }

    return services.map(this.formatService);
  }
}

export const serviceService = new ServiceService();
