import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';

import { Notification } from './entities/notification.entity.js';
import { UsersService } from '../users/users.service.js';
import { UserSetting } from '../settings/entities/user-setting.entity.js';

export type NotificationCategory = 'RIDE' | 'SAFETY' | 'GENERAL';

export interface CreateNotificationInput {
  userId: string;
  type: string;
  title: string;
  body: string;
  category?: NotificationCategory;
  safetyAlertId?: string | null;
}

@Injectable()
export class NotificationsService {
  constructor(
    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,

    @InjectRepository(UserSetting)
    private readonly settingsRepository: Repository<UserSetting>,

    private readonly usersService: UsersService,
  ) {}

  /** Store an in-app notification unless the user disabled its category. */
  async createForUser(
    input: CreateNotificationInput,
  ): Promise<Notification | null> {
    const settings = await this.settingsRepository.findOne({
      where: { userId: input.userId },
      select: {
        notificationsEnabled: true,
        rideUpdatesEnabled: true,
        speedAlertsEnabled: true,
      },
    });

    if (settings?.notificationsEnabled === false) return null;
    if (input.category === 'RIDE' && settings?.rideUpdatesEnabled === false) {
      return null;
    }
    if (input.category === 'SAFETY' && settings?.speedAlertsEnabled === false) {
      return null;
    }

    return this.notificationRepository.save(
      this.notificationRepository.create({
        userId: input.userId,
        safetyAlertId: input.safetyAlertId ?? null,
        type: input.type,
        title: input.title,
        body: input.body,
      }),
    );
  }

  async createForUsers(
    userIds: string[],
    input: Omit<CreateNotificationInput, 'userId'>,
  ): Promise<void> {
    const uniqueUserIds = [...new Set(userIds)];
    await Promise.all(
      uniqueUserIds.map((userId) => this.createForUser({ ...input, userId })),
    );
  }

  /**
   * Resolve the authenticated Firebase user to the database user.
   */
  private async getDatabaseUser(firebaseUid: string) {
    const user = await this.usersService.getUserByFirebaseUid(firebaseUid);

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
  async getNotifications(firebaseUid: string, page = 1, limit = 20) {
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
  async markAsRead(firebaseUid: string, notificationId: string) {
    const user = await this.getDatabaseUser(firebaseUid);

    const notification = await this.notificationRepository.findOne({
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
