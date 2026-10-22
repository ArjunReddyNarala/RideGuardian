import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';

import { Notification } from './entities/notification.entity.js';
import { UsersService } from '../users/users.service.js';

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,

    private readonly usersService: UsersService,
  ) {}

  /**
   * Resolve the authenticated Firebase user to the database user.
   */
  private async getDatabaseUser(firebaseUid: string) {
    const user =
      await this.usersService.getUserByFirebaseUid(firebaseUid);

    if (!user) {
      throw new NotFoundException(
        'User profile not found. Please register first.',
      );
    }

    return user;
  }

  /**
   * GET /api/v1/notifications
   *
   * Returns notifications belonging to the logged-in user.
   */
  async getNotifications(
    firebaseUid: string,
    page = 1,
    limit = 20,
  ) {
    const user = await this.getDatabaseUser(firebaseUid);

    const safePage = Math.max(1, page);
    const safeLimit = Math.min(100, Math.max(1, limit));

    const [notifications, total] =
      await this.notificationRepository.findAndCount({
        where: {
          userId: user.id,
        },
        order: {
          createdAt: 'DESC',
        },
        skip: (safePage - 1) * safeLimit,
        take: safeLimit,
      });

    return {
      data: notifications,
      pagination: {
        page: safePage,
        limit: safeLimit,
        total,
        totalPages: Math.ceil(total / safeLimit),
      },
    };
  }

  /**
   * GET /api/v1/notifications/unread-count
   *
   * Returns the unread notification count for the current user.
   */
  async getUnreadCount(firebaseUid: string) {
    const user = await this.getDatabaseUser(firebaseUid);

    const count = await this.notificationRepository.count({
      where: {
        userId: user.id,
        isRead: false,
      },
    });

    return { unreadCount: count };
  }

  /**
   * POST /api/v1/notifications/:notificationId/read
   *
   * Marks one notification as read.
   */
  async markAsRead(
    firebaseUid: string,
    notificationId: string,
  ) {
    const user = await this.getDatabaseUser(firebaseUid);

    const notification =
      await this.notificationRepository.findOne({
        where: {
          id: notificationId,
          userId: user.id,
        },
      });

    if (!notification) {
      throw new NotFoundException('Notification not found.');
    }

    if (!notification.isRead) {
      notification.isRead = true;
      notification.readAt = new Date();

      await this.notificationRepository.save(notification);
    }

    return notification;
  }

  /**
   * POST /api/v1/notifications/read-all
   *
   * Marks all unread notifications belonging to the current user
   * as read.
   */
  async markAllAsRead(firebaseUid: string) {
    const user = await this.getDatabaseUser(firebaseUid);

    const result = await this.notificationRepository.update(
      {
        userId: user.id,
        isRead: false,
        readAt: IsNull(),
      },
      {
        isRead: true,
        readAt: new Date(),
      },
    );

    return {
      message: 'All notifications marked as read.',
      updatedCount: result.affected ?? 0,
    };
  }
}