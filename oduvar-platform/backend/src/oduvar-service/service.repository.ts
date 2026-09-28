import { prisma } from '../config/database';
import { CreateOduvarServiceInput, UpdateOduvarServiceInput, CreateServicePricingInput, UpdateServicePricingInput } from './service.dto';
import { Prisma } from '@prisma/client';

export class ServiceRepository {
  async findProfileByUserId(userId: string) {
    return prisma.oduvarProfile.findUnique({
      where: { userId },
    });
  }

  async ensureProfileExists(userId: string) {
    let profile = await prisma.oduvarProfile.findUnique({
      where: { userId },
    });
    if (!profile) {
      profile = await prisma.oduvarProfile.create({
        data: {
          userId,
          isPublished: false,
        },
      });
    }
    return profile;
  }

  async findBaseServiceById(serviceId: string) {
    return prisma.service.findUnique({
      where: { id: serviceId },
    });
  }

  async findOduvarServiceByProfileAndService(profileId: string, serviceId: string) {
    return prisma.oduvarService.findUnique({
      where: {
        profileId_serviceId: {
          profileId,
          serviceId,
        },
      },
    });
  }

  async findOduvarServiceById(id: string) {
    return prisma.oduvarService.findUnique({
      where: { id },
      include: {
        service: true,
        pricings: {
          orderBy: { durationMinutes: 'asc' },
        },
        profile: {
          select: { id: true, userId: true },
        },
      },
    });
  }

  async findServicesByProfileId(profileId: string) {
    return prisma.oduvarService.findMany({
      where: { profileId },
      include: {
        service: true,
        pricings: {
          orderBy: { durationMinutes: 'asc' },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async findPublicServicesByUserId(userId: string) {
    const profile = await prisma.oduvarProfile.findUnique({
      where: { userId },
    });
    if (!profile || !profile.isPublished) {
      return null;
    }

    return prisma.oduvarService.findMany({
      where: {
        profileId: profile.id,
        isActive: true,
      },
      include: {
        service: true,
        pricings: {
          where: { isActive: true },
          orderBy: { durationMinutes: 'asc' },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  async createOduvarService(profileId: string, input: CreateOduvarServiceInput) {
    return prisma.$transaction(async (tx) => {
      const oduvarService = await tx.oduvarService.create({
        data: {
          profileId,
          serviceId: input.serviceId,
          customDescription: input.customDescription,
          transport: input.transport,
          transportFee: input.transportFee !== undefined && input.transportFee !== null
            ? new Prisma.Decimal(input.transportFee)
            : null,
          isActive: true,
          pricings: {
            create: (input.pricings || []).map((p) => ({
              durationMinutes: p.durationMinutes,
              amount: new Prisma.Decimal(p.amount),
              currency: p.currency || 'INR',
              isActive: true,
            })),
          },
        },
        include: {
          service: true,
          pricings: {
            orderBy: { durationMinutes: 'asc' },
          },
        },
      });

      return oduvarService;
    });
  }

  async updateOduvarService(id: string, input: UpdateOduvarServiceInput) {
    const updateData: Prisma.OduvarServiceUpdateInput = {};

    if (input.customDescription !== undefined) {
      updateData.customDescription = input.customDescription;
    }
    if (input.transport !== undefined) {
      updateData.transport = input.transport;
    }
    if (input.transportFee !== undefined) {
      updateData.transportFee = input.transportFee !== null
        ? new Prisma.Decimal(input.transportFee)
        : null;
    }
    if (input.isActive !== undefined) {
      updateData.isActive = input.isActive;
    }

    return prisma.oduvarService.update({
      where: { id },
      data: updateData,
      include: {
        service: true,
        pricings: {
          orderBy: { durationMinutes: 'asc' },
        },
      },
    });
  }

  async deleteOduvarService(id: string) {
    return prisma.oduvarService.delete({
      where: { id },
    });
  }

  async findPricingById(pricingId: string) {
    return prisma.servicePricing.findUnique({
      where: { id: pricingId },
      include: {
        oduvarService: {
          include: {
            profile: {
              select: { id: true, userId: true },
            },
          },
        },
      },
    });
  }

  async findPricingByDuration(oduvarServiceId: string, durationMinutes: number) {
    return prisma.servicePricing.findUnique({
      where: {
        oduvarServiceId_durationMinutes: {
          oduvarServiceId,
          durationMinutes,
        },
      },
    });
  }

  async createPricing(oduvarServiceId: string, input: CreateServicePricingInput) {
    return prisma.servicePricing.create({
      data: {
        oduvarServiceId,
        durationMinutes: input.durationMinutes,
        amount: new Prisma.Decimal(input.amount),
        currency: input.currency || 'INR',
        isActive: true,
      },
    });
  }

  async updatePricing(pricingId: string, input: UpdateServicePricingInput) {
    const updateData: Prisma.ServicePricingUpdateInput = {};

    if (input.durationMinutes !== undefined) {
      updateData.durationMinutes = input.durationMinutes;
    }
    if (input.amount !== undefined) {
      updateData.amount = new Prisma.Decimal(input.amount);
    }
    if (input.currency !== undefined) {
      updateData.currency = input.currency;
    }
    if (input.isActive !== undefined) {
      updateData.isActive = input.isActive;
    }

    return prisma.servicePricing.update({
      where: { id: pricingId },
      data: updateData,
    });
  }

  async deletePricing(pricingId: string) {
    return prisma.servicePricing.delete({
      where: { id: pricingId },
    });
  }
}

export const serviceRepository = new ServiceRepository();
