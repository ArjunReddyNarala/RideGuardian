import {
  Body,
  Controller,
  Post,
  UseGuards,
} from '@nestjs/common';
import { UsersService } from '../users/users.service.js';
import { FirebaseAuthGuard } from './guards/firebase-auth.guard.js';
import { CurrentUser } from './decorators/current-user.decorator.js';
import type { DecodedIdToken } from 'firebase-admin/auth';

@Controller('api/v1/auth')
export class AuthController {
  constructor(
    private readonly usersService: UsersService,
  ) {}

  @Post('sync')
  @UseGuards(FirebaseAuthGuard)
  async syncUser(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Body()
    body: {
      phone?: string;
      profileImageUrl?: string;
    },
  ) {
    const existingUser =
      await this.usersService.getUserByFirebaseUid(firebaseUser.uid);

    if (existingUser) {
      return existingUser;
    }

    return this.usersService.createUser({
      firebaseUid: firebaseUser.uid,
      name: firebaseUser.name ?? 'RideGuardian User',
      email: firebaseUser.email,
      phone: body.phone ?? firebaseUser.phone_number,
      profileImageUrl: body.profileImageUrl ?? firebaseUser.picture,
    });
  }
}