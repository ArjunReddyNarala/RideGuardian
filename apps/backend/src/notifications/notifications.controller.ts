import {
  Controller,
  DefaultValuePipe,
  Get,
  Param,
  ParseIntPipe,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
  ApiTags,
} from '@nestjs/swagger';
import type { DecodedIdToken } from 'firebase-admin/auth';

import { NotificationsService } from './notifications.service.js';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';

@ApiTags('Notifications')
@ApiBearerAuth()
@UseGuards(FirebaseAuthGuard)
@Controller('api/v1/notifications')
export class NotificationsController {
  constructor(
    private readonly notificationsService: NotificationsService,
  ) {}

  @Get()
  @ApiOperation({
    summary: 'Get notifications for the authenticated user',
  })
  @ApiQuery({
    name: 'page',
    required: false,
    type: Number,
    example: 1,
  })
  @ApiQuery({
    name: 'limit',
    required: false,
    type: Number,
    example: 20,
  })
  async getNotifications(
    @CurrentUser() user: DecodedIdToken,
    @Query('page', new DefaultValuePipe(1), ParseIntPipe)
    page: number,
    @Query('limit', new DefaultValuePipe(20), ParseIntPipe)
    limit: number,
  ) {
    return this.notificationsService.getNotifications(
      user.uid,
      page,
      limit,
    );
  }

  @Get('unread-count')
  @ApiOperation({
    summary: 'Get the unread notification count',
  })
  async getUnreadCount(
    @CurrentUser() user: DecodedIdToken,
  ) {
    return this.notificationsService.getUnreadCount(user.uid);
  }

  @Post('read-all')
  @ApiOperation({
    summary: 'Mark all notifications as read',
  })
  async markAllAsRead(
    @CurrentUser() user: DecodedIdToken,
  ) {
    return this.notificationsService.markAllAsRead(user.uid);
  }

  @Post(':notificationId/read')
  @ApiOperation({
    summary: 'Mark a notification as read',
  })
  async markAsRead(
    @CurrentUser() user: DecodedIdToken,
    @Param('notificationId', new ParseUUIDPipe())
    notificationId: string,
  ) {
    return this.notificationsService.markAsRead(
      user.uid,
      notificationId,
    );
  }
}