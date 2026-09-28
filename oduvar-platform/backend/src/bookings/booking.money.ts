import { Prisma, TransportOption } from '@prisma/client';

/**
 * Booking price calculation. Uses Prisma.Decimal (arbitrary-precision) end to end, the same
 * Decimal(10,2) representation as Phase 3 pricing. No floating point arithmetic.
 *
 * The client never supplies any of these numbers; they come from the Oduvar's server-side
 * service + pricing rows at the moment the booking is created.
 *
 *   INCLUDED         total = service amount, transport shown as "Included" (fee null)
 *   NOT_INCLUDED     total = service amount, client arranges transport (fee null)
 *   ADDITIONAL_FEE   total = service amount + the Oduvar's transport fee
 *   TO_BE_DISCUSSED  total UNKNOWN (null): never invent a number
 */
export interface PriceBreakdown {
  serviceAmount: Prisma.Decimal;
  transportFee: Prisma.Decimal | null;
  totalAmount: Prisma.Decimal | null;
  currency: string;
}

export function computePrice(
  serviceAmount: Prisma.Decimal.Value,
  transport: TransportOption,
  transportFee: Prisma.Decimal.Value | null | undefined,
  currency = 'INR'
): PriceBreakdown {
  const service = new Prisma.Decimal(serviceAmount);
  switch (transport) {
    case TransportOption.ADDITIONAL_FEE: {
      if (transportFee === null || transportFee === undefined) {
        // Misconfigured offering: refuse to guess a total.
        return { serviceAmount: service, transportFee: null, totalAmount: null, currency };
      }
      const fee = new Prisma.Decimal(transportFee);
      return { serviceAmount: service, transportFee: fee, totalAmount: service.plus(fee), currency };
    }
    case TransportOption.TO_BE_DISCUSSED:
      return { serviceAmount: service, transportFee: null, totalAmount: null, currency };
    default: // INCLUDED, NOT_INCLUDED
      return { serviceAmount: service, transportFee: null, totalAmount: service, currency };
  }
}
