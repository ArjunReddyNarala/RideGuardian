import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { Notification } from './entities/notification.entity.js';
import { NotificationsController } from './notifications.controller.js';
import { NotificationsService } from './notifications.service.js';
import { UsersModule } from '../users/users.module.js';
import { UserSetting } from '../settings/entities/user-setting.entity.js';

@Module({
  imports: [TypeOrmModule.forFeature([Notification, UserSetting]), UsersModule],
  controllers: [NotificationsController],
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
