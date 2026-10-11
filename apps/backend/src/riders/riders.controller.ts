import {
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { DecodedIdToken } from 'firebase-admin/auth';

import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { UsersService } from '../users/users.service.js';

import { RidersService } from './riders.service.js';

@ApiTags('Riders')
@ApiBearerAuth()
@Controller('api/v1/riders')
@UseGuards(FirebaseAuthGuard)
export class RidersController {
  constructor(
    private readonly ridersService: RidersService,
    private readonly usersService: UsersService,
  ) {}

  @Get()
  async getRiders(@CurrentUser() firebaseUser: DecodedIdToken) {
    const user = await this.getBackendUser(firebaseUser.uid);

    return this.ridersService.getRiders(user.id);
  }

  @Delete(':relationshipId')
  async removeRider(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('relationshipId') relationshipId: string,
  ) {
    const user = await this.getBackendUser(firebaseUser.uid);

    return this.ridersService.removeRider(user.id, relationshipId);
  }

  @Get(':id/active-ride')
  async getActiveRide(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('id') riderId: string,
  ) {
    const user = await this.getBackendUser(firebaseUser.uid);

    return this.ridersService.getActiveRide(user.id, riderId);
  }

  private async getBackendUser(firebaseUid: string) {
    const user = await this.usersService.getUserByFirebaseUid(firebaseUid);

    if (!user) {
      throw new NotFoundException('Authenticated user not found');
    }

    return user;
  }
}
