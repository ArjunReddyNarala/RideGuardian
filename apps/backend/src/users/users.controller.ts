import {
  Body,
  Controller,
  Get,
  Patch,
  UseGuards,
} from '@nestjs/common';
import { UsersService } from './users.service.js';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import type { DecodedIdToken } from 'firebase-admin/auth';

@Controller('api/v1/users')
@UseGuards(FirebaseAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  async getCurrentUser(
    @CurrentUser() firebaseUser: DecodedIdToken,
  ) {
    return this.usersService.getUserByFirebaseUid(firebaseUser.uid);
  }

  @Patch('me')
  async updateCurrentUser(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Body()
    body: {
      name?: string;
      phone?: string;
      profileImageUrl?: string;
    },
  ) {
    const user = await this.usersService.getUserByFirebaseUid(
      firebaseUser.uid,
    );

    if (!user) {
      return null;
    }

    return this.usersService.updateUser(user.id, body);
  }
}