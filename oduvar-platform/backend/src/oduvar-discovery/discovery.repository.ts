import { Prisma, TransportOption } from '@prisma/client';
import { prisma } from '../config/database';
import { DiscoveryQuery } from './discovery.dto';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ci = (v: string) => ({ contains: v, mode: 'insensitive' as const });

/** Public-safe projection: no email, phone, password hash, tokens. */
const cardInclude = {
  user: { select: { id: true, name: true, profilePhoto: true } },
  photos: { orderBy: { displayOrder: 'asc' as const }, take: 1, select: { imageUrl: true } },
  skills: { select: { skill: { select: { id: true, name: true, slug: true } } } },
  instruments: { select: { instrument: { select: { id: true, name: true, slug: true } } } },
  services: {
    where: { isActive: true, service: { isActive: true } },
    select: { service: { select: { id: true, name: true, category: true } } },
  },
} satisfies Prisma.OduvarProfileInclude;

export type CardRow = Prisma.OduvarProfileGetPayload<{ include: typeof cardInclude }>;

export class DiscoveryRepository {
  /** All filters that can be expressed in SQL. Only published profiles are ever matched. */
  buildWhere(q: DiscoveryQuery, ratedUserIds?: string[]): Prisma.OduvarProfileWhereInput {
    const and: Prisma.OduvarProfileWhereInput[] = [];

    if (q.search) {
      and.push({ OR: [{ user: { name: ci(q.search) } }, { location: ci(q.search) }] });
    }
    if (q.location) and.push({ location: ci(q.location) });

    if (q.service) {
      // Only ACTIVE offerings of ACTIVE catalogue services qualify (Phase 3 data).
      const matchers: Prisma.ServiceWhereInput[] = [
        { category: { equals: q.service, mode: 'insensitive' } },
        { name: ci(q.service) },
      ];
      if (UUID_RE.test(q.service)) matchers.push({ id: q.service });
      and.push({ services: { some: { isActive: true, service: { isActive: true, OR: matchers } } } });
    }

    if (q.instrument) {
      const matchers: Prisma.InstrumentWhereInput[] = [
        { slug: { equals: q.instrument, mode: 'insensitive' } },
        { name: { equals: q.instrument, mode: 'insensitive' } },
      ];
      if (UUID_RE.test(q.instrument)) matchers.push({ id: q.instrument });
      and.push({ instruments: { some: { instrument: { OR: matchers } } } });
    }

    if (q.songCategory) and.push({ songCategories: { has: q.songCategory } });
    if (q.eventType) and.push({ eventTypes: { has: q.eventType } });

    if (q.performanceType) {
      // BOTH-profiles can do either; a BOTH filter means specifically "both".
      const accepted = q.performanceType === 'BOTH' ? ['BOTH'] : [q.performanceType, 'BOTH'];
      and.push({ performanceTypes: { hasSome: accepted } });
    }
    if (q.transport) and.push({ transport: q.transport as TransportOption });
    if (ratedUserIds) and.push({ userId: { in: ratedUserIds } });

    return { isPublished: true, ...(and.length ? { AND: and } : {}) };
  }

  orderBy(sort: DiscoveryQuery['sort'], hasSearch: boolean): Prisma.OduvarProfileOrderByWithRelationInput[] {
    switch (sort) {
      case 'name':
        return [{ user: { name: 'asc' } }, { id: 'asc' }];
      case 'location':
        return [{ location: { sort: 'asc', nulls: 'last' } }, { user: { name: 'asc' } }, { id: 'asc' }];
      case 'rating': // final ordering applied in the service once aggregates are known
        return [{ user: { name: 'asc' } }, { id: 'asc' }];
      default: // relevance
        return hasSearch
          ? [{ user: { name: 'asc' } }, { id: 'asc' }]
          : [{ updatedAt: 'desc' }, { id: 'asc' }];
    }
  }

  async page(
    where: Prisma.OduvarProfileWhereInput,
    orderBy: Prisma.OduvarProfileOrderByWithRelationInput[],
    skip: number,
    take: number
  ) {
    const [total, rows] = await Promise.all([
      prisma.oduvarProfile.count({ where }),
      prisma.oduvarProfile.findMany({ where, orderBy, skip, take, include: cardInclude }),
    ]);
    return { total, rows };
  }

  /** Lightweight candidate list (no relations) for flows that post-filter/re-sort (availability, rating sort). */
  candidates(
    where: Prisma.OduvarProfileWhereInput,
    orderBy: Prisma.OduvarProfileOrderByWithRelationInput[],
    limit: number
  ) {
    return prisma.oduvarProfile.findMany({ where, orderBy, take: limit });
  }

  async byIds(ids: string[]): Promise<CardRow[]> {
    if (ids.length === 0) return [];
    const rows = await prisma.oduvarProfile.findMany({ where: { id: { in: ids } }, include: cardInclude });
    const byId = new Map(rows.map((r) => [r.id, r]));
    return ids.map((id) => byId.get(id)).filter((r): r is CardRow => !!r);
  }

  /** Real review aggregates keyed by Oduvar USER id (one grouped query). */
  async ratings(userIds: string[]): Promise<Map<string, { avg: number; count: number }>> {
    const map = new Map<string, { avg: number; count: number }>();
    if (userIds.length === 0) return map;
    const groups = await prisma.review.groupBy({
      by: ['oduvarId'],
      where: { oduvarId: { in: userIds } },
      _avg: { rating: true },
      _count: { _all: true },
    });
    for (const g of groups) {
      if (g._avg.rating !== null) map.set(g.oduvarId, { avg: g._avg.rating, count: g._count._all });
    }
    return map;
  }

  async userIdsWithMinRating(min: number): Promise<string[]> {
    const groups = await prisma.review.groupBy({
      by: ['oduvarId'],
      _avg: { rating: true },
      having: { rating: { _avg: { gte: min } } },
    });
    return groups.map((g) => g.oduvarId);
  }
}

export const discoveryRepository = new DiscoveryRepository();
