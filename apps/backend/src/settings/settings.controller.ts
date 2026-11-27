import {
  Body,
  Controller,
  Get,
  Patch,
  UseGuards,
} from '@nestjs/common';

import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';

import type { DecodedIdToken } from 'firebase-admin/auth';

import { SettingsService } from './settings.service.js';
import { UpdateSettingsDto } from './dto/update-settings.dto.js';

import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';

@ApiTags('Settings')
@ApiBearerAuth()
@UseGuards(FirebaseAuthGuard)
@Controller('api/settings')
export class SettingsController {
  constructor(
    private readonly settingsService: SettingsService,
  ) {}

  @Get()
  @ApiOperation({
    summary: 'Get the authenticated user settings',
  })
  getSettings(
    @CurrentUser() firebaseUser: DecodedIdToken,
  ) {
    return this.settingsService.getSettings(
      firebaseUser.uid,
    );
  }

  @Patch()
  @ApiOperation({
    summary: 'Update the authenticated user settings',
  })
  updateSettings(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Body() dto: UpdateSettingsDto,
  ) {
    return this.settingsService.updateSettings(
      firebaseUser.uid,
      dto,
    );
  }
}