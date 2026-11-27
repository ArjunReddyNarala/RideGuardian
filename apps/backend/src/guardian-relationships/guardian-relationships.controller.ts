import {
  Controller,
  Get,
  NotFoundException,
  Param,
  Patch,
  UseGuards,
} from '@nestjs/common';
import type { DecodedIdToken } from 'firebase-admin/auth';
import { ApiBearerAuth } from '@nestjs/swagger';

import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { UsersService } from '../users/users.service.js';

import { GuardianRelationshipsService } from './guardian-relationships.service.js';

@ApiBearerAuth()
@Controller('api/v1/guardian-relationships')
@UseGuards(FirebaseAuthGuard)
export class GuardianRelationshipsController {
  constructor(
    private readonly guardianRelationshipsService: GuardianRelationshipsService,
    private readonly usersService: UsersService,
  ) {}

  @Get()
  async getRelationships(
    @CurrentUser() firebaseUser: DecodedIdToken,
  ) {
    const user = await this.getCurrentDatabaseUser(
      firebaseUser.uid,
    );

    return this.guardianRelationshipsService.getRelationships(
      user.id,
    );
  }

  @Patch(':id/revoke')
  async revokeRelationship(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('id') relationshipId: string,
  ) {
    const user = await this.getCurrentDatabaseUser(
      firebaseUser.uid,
    );

    return this.guardianRelationshipsService.revokeRelationship(
      relationshipId,
      user.id,
    );
  }

  private async getCurrentDatabaseUser(firebaseUid: string) {
    const user =
      await this.usersService.getUserByFirebaseUid(firebaseUid);

    if (!user) {
      throw new NotFoundException(
        'RideGuardian user profile not found',
      );
    }

    return user;
  }
}