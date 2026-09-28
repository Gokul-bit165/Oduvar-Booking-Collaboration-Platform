import { Prisma, PrismaClient } from '@prisma/client';
import { prisma } from '../config/database';
import { AppError } from '../common/dto/api-response';

type Db = PrismaClient | Prisma.TransactionClient;

/**
 * Persistent in-app notifications only. No push provider is configured yet, so nothing here
 * pretends to deliver a push: rows are created and read through the API.
 */
export const NotificationType = {
  BOOKING_REQUEST_SENT: 'BOOKING_REQUEST_SENT', // to client
  BOOKING_REQUESTED: 'BOOKING_REQUESTED', // to Oduvar
  BOOKING_CONFIRMED: 'BOOKING_CONFIRMED', // to client
  BOOKING_REJECTED: 'BOOKING_REJECTED', // to client
  BOOKING_CANCELLED: 'BOOKING_CANCELLED', // to the other party
  BOOKING_COMPLETED: 'BOOKING_COMPLETED', // to client
} as const;

export class NotificationService {
  /** Pass a transaction client so the notification commits (or rolls back) with the booking change. */
  async create(db: Db, userId: string, type: string, title: string, body: string, data?: Prisma.InputJsonValue) {
    return db.notification.create({ data: { userId, type, title, body, data } });
  }

  private format(n: { id: string; type: string; title: string; body: string; readAt: Date | null; data: Prisma.JsonValue; createdAt: Date }) {
    return { id: n.id, type: n.type, title: n.title, body: n.body, isRead: n.readAt !== null, data: n.data, createdAt: n.createdAt };
  }

  async list(userId: string, page = 1, pageSize = 30, unreadOnly = false) {
    const where: Prisma.NotificationWhereInput = { userId, ...(unreadOnly ? { readAt: null } : {}) };
    const [items, total, unreadCount] = await Promise.all([
      prisma.notification.findMany({ where, orderBy: { createdAt: 'desc' }, skip: (page - 1) * pageSize, take: pageSize }),
      prisma.notification.count({ where }),
      prisma.notification.count({ where: { userId, readAt: null } }),
    ]);
    return { items: items.map((n) => this.format(n)), page, pageSize, total, unreadCount, hasNext: page * pageSize < total };
  }

  async markRead(userId: string, id: string) {
    const res = await prisma.notification.updateMany({ where: { id, userId, readAt: null }, data: { readAt: new Date() } });
    if (res.count === 0) {
      const exists = await prisma.notification.findFirst({ where: { id, userId } });
      if (!exists) throw new AppError('NOT_FOUND', 'Notification not found', 404);
    }
    return { id, isRead: true };
  }

  async markAllRead(userId: string) {
    const res = await prisma.notification.updateMany({ where: { userId, readAt: null }, data: { readAt: new Date() } });
    return { updated: res.count };
  }
}

export const notificationService = new NotificationService();
