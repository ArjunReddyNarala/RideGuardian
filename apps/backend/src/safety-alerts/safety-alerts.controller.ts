import {
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import type { DecodedIdToken } from 'firebase-admin/auth';

import { SafetyAlertsService } from './safety-alerts.service.js';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';

@ApiTags('Alerts')
@ApiBearerAuth()
@UseGuards(FirebaseAuthGuard)
@Controller('api/v1/alerts')
export class SafetyAlertsController {
  constructor(
    private readonly safetyAlertsService: SafetyAlertsService,
  ) {}

  @Get()
  @ApiOperation({
    summary: 'Get all alerts accessible to the current user',
  })
  async getAlerts(
    @CurrentUser() user: DecodedIdToken,
  ) {
    return this.safetyAlertsService.getAlerts(user.uid);
  }

  @Get('active')
  @ApiOperation({
    summary: 'Get active alerts accessible to the current user',
  })
  async getActiveAlerts(
    @CurrentUser() user: DecodedIdToken,
  ) {
    return this.safetyAlertsService.getActiveAlerts(user.uid);
  }

  @Get(':alertId')
  @ApiOperation({
    summary: 'Get an alert by ID',
  })
  async getAlertById(
    @CurrentUser() user: DecodedIdToken,
    @Param('alertId', new ParseUUIDPipe())
    alertId: string,
  ) {
    return this.safetyAlertsService.getAlertById(
      user.uid,
      alertId,
    );
  }

  @Post(':alertId/acknowledge')
  @ApiOperation({
    summary: 'Acknowledge an alert',
  })
  async acknowledgeAlert(
    @CurrentUser() user: DecodedIdToken,
    @Param('alertId', new ParseUUIDPipe())
    alertId: string,
  ) {
    return this.safetyAlertsService.acknowledgeAlert(
      user.uid,
      alertId,
    );
  }

  @Post(':alertId/resolve')
  @ApiOperation({
    summary: 'Resolve an alert',
  })
  async resolveAlert(
    @CurrentUser() user: DecodedIdToken,
    @Param('alertId', new ParseUUIDPipe())
    alertId: string,
  ) {
    return this.safetyAlertsService.resolveAlert(
      user.uid,
      alertId,
    );
  }
}