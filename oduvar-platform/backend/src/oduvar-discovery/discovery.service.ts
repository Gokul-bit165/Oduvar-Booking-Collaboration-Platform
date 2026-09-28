import { OduvarProfile } from '@prisma/client';
import { availabilityService } from '../availability/availability.service';
import { CardRow, discoveryRepository } from './discovery.repository';
import { DiscoveryQuery } from './discovery.dto';

/** Upper bound on profiles materialised for availability / rating-sort flows. */
export const MAX_CANDIDATES = 2000;
const BIO_PREVIEW_LENGTH = 140;

type Ratings = Map<string, { avg: number; count: number }>;

/**
 * Public-safe search result. Never contains email, phone, password hash, tokens or
 * anything else from the User row beyond id / name / profile photo.
 * `id` is the Oduvar's USER id: the same id used by /oduvars/:oduvarId/{profile,services,availability}.
 */
export function toSearchItem(row: CardRow, ratings: Ratings) {
  const r = ratings.get(row.userId);
  const bio = row.bio ?? '';
  return {
    id: row.userId,
    profileId: row.id,
    name: row.user.name,
    profilePhoto: row.user.profilePhoto ?? row.photos[0]?.imageUrl ?? null,
    location: row.location,
    bioPreview: bio.length > BIO_PREVIEW_LENGTH ? `${bio.slice(0, BIO_PREVIEW_LENGTH).trimEnd()}…` : bio || null,
    skills: row.skills.map((s) => s.skill),
    performanceTypes: row.performanceTypes,
    songCategories: row.songCategories,
    eventTypes: row.eventTypes,
    instruments: row.instruments.map((i) => i.instrument),
    services: row.services.map((s) => s.service),
    transport: row.transport,
    collaborationEnabled: row.collaborationEnabled,
    // null / 0 when there are no reviews; never a fabricated value.
    rating: r ? Math.round(r.avg * 10) / 10 : null,
    reviewCount: r?.count ?? 0,
  };
}

export class DiscoveryService {
  async search(q: DiscoveryQuery, now: Date = new Date()) {
    const { page, pageSize } = q;

    // Rating filter: uses real review aggregates. With no reviews in the system it matches nobody.
    const ratedIds = q.minRating !== undefined ? await discoveryRepository.userIdsWithMinRating(q.minRating) : undefined;
    const where = discoveryRepository.buildWhere(q, ratedIds);
    const orderBy = discoveryRepository.orderBy(q.sort, !!q.search);

    const needsCandidatePass = q.availableDate !== undefined || q.sort === 'rating';
    let total: number;
    let rows: CardRow[];
    let ratings: Ratings;

    if (!needsCandidatePass) {
      // Plain path: pure SQL pagination, no availability work at all.
      const result = await discoveryRepository.page(where, orderBy, (page - 1) * pageSize, pageSize);
      total = result.total;
      rows = result.rows;
      ratings = await discoveryRepository.ratings(rows.map((r) => r.userId));
    } else {
      let candidates: OduvarProfile[] = await discoveryRepository.candidates(where, orderBy, MAX_CANDIDATES);

      if (q.availableDate) {
        // One batched call into the Phase 4 engine for ALL candidates (2 queries total).
        const ok = await availabilityService.filterAvailableProfiles(candidates, q.availableDate, q.availableDuration, now);
        candidates = candidates.filter((c) => ok.has(c.id));
      }

      ratings = await discoveryRepository.ratings(candidates.map((c) => c.userId));
      if (q.sort === 'rating') {
        // Rated Oduvars first (highest avg, then most reviews); unrated keep name order after them.
        candidates = candidates
          .map((c, i) => ({ c, i, r: ratings.get(c.userId) }))
          .sort((a, b) => {
            if (!!a.r !== !!b.r) return a.r ? -1 : 1;
            if (a.r && b.r) return b.r.avg - a.r.avg || b.r.count - a.r.count || a.i - b.i;
            return a.i - b.i;
          })
          .map((x) => x.c);
      }

      total = candidates.length;
      const pageIds = candidates.slice((page - 1) * pageSize, page * pageSize).map((c) => c.id);
      rows = await discoveryRepository.byIds(pageIds);
    }

    return {
      items: rows.map((row) => toSearchItem(row, ratings)),
      page,
      pageSize,
      total,
      hasNext: page * pageSize < total,
    };
  }
}

export const discoveryService = new DiscoveryService();
