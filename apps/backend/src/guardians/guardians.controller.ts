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

import { GuardiansService } from './guardians.service.js';

@ApiTags('Guardians')
@ApiBearerAuth()
@Controller('api/v1/guardians')
@UseGuards(FirebaseAuthGuard)
export class GuardiansController {
  constructor(
    private readonly guardiansService: GuardiansService,
    private readonly usersService: UsersService,
  ) {}

  @Get()
  async getGuardians(@CurrentUser() firebaseUser: DecodedIdToken) {
    const user = await this.getBackendUser(firebaseUser.uid);

    return this.guardiansService.getGuardians(user.id);
  }

  @Delete(':relationshipId')
  async removeGuardian(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('relationshipId') relationshipId: string,
  ) {
    const user = await this.getBackendUser(firebaseUser.uid);

    return this.guardiansService.removeGuardian(user.id, relationshipId);
  }

  private async getBackendUser(firebaseUid: string) {
    const user = await this.usersService.getUserByFirebaseUid(firebaseUid);

    if (!user) {
      throw new NotFoundException('Authenticated user not found');
    }

    return user;
  }
}
