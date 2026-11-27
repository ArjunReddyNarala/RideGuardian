import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { DecodedIdToken } from 'firebase-admin/auth';

import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { UsersService } from '../users/users.service.js';

import { UpdateRiderSafetySettingsDto } from './dto/update-rider-safety-settings.dto.js';
import { RiderSafetySettingsService } from './rider-safety-settings.service.js';

@ApiTags('Rider Safety Settings')
@ApiBearerAuth()
@Controller('api/v1/rider-safety-settings')
@UseGuards(FirebaseAuthGuard)
export class RiderSafetySettingsController {
  constructor(
    private readonly safetySettingsService: RiderSafetySettingsService,
    private readonly usersService: UsersService,
  ) {}

  @Get()
  async getSettings(
    @CurrentUser() firebaseUser: DecodedIdToken,
  ) {
    const guardianId = await this.getBackendUserId(
      firebaseUser.uid,
    );

    return this.safetySettingsService.getSettings(guardianId);
  }

  @Put(':riderId')
  async updateSettings(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('riderId') riderId: string,
    @Body() dto: UpdateRiderSafetySettingsDto,
  ) {
    const guardianId = await this.getBackendUserId(
      firebaseUser.uid,
    );

    return this.safetySettingsService.updateSettings(
      guardianId,
      riderId,
      dto,
    );
  }

  private async getBackendUserId(
    firebaseUid: string,
  ): Promise<string> {
    const user =
      await this.usersService.getUserByFirebaseUid(
        firebaseUid,
      );

    if (!user) {
      throw new NotFoundException(
        'Authenticated user not found',
      );
    }

    return user.id;
  }
}