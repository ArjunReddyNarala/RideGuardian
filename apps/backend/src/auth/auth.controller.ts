import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import type { DecodedIdToken } from 'firebase-admin/auth';

import { CurrentUser } from './decorators/current-user.decorator.js';
import { FirebaseAuthGuard } from './guards/firebase-auth.guard.js';

import { UsersService } from '../users/users.service.js';

@ApiTags('Authentication')
@ApiBearerAuth()
@Controller('api/v1/auth')
export class AuthController {
  constructor(private readonly usersService: UsersService) {}

  @Post('register')
  @UseGuards(FirebaseAuthGuard)
  async register(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Body()
    body: {
      phone?: string;
      profileImageUrl?: string;
    },
  ) {
    const existingUser = await this.usersService.getUserByFirebaseUid(
      firebaseUser.uid,
    );

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

  @Get('me')
  @UseGuards(FirebaseAuthGuard)
  async getCurrentUser(@CurrentUser() firebaseUser: DecodedIdToken) {
    const user = await this.usersService.getUserByFirebaseUid(firebaseUser.uid);

    if (!user) {
      throw new NotFoundException(
        'User profile not found. Please register first.',
      );
    }

    return user;
  }

  @Patch('me')
  @UseGuards(FirebaseAuthGuard)
  async updateCurrentUser(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Body()
    body: {
      name?: string;
      phone?: string;
      profileImageUrl?: string;
    },
  ) {
    const user = await this.usersService.getUserByFirebaseUid(firebaseUser.uid);

    if (!user) {
      throw new NotFoundException(
        'User profile not found. Please register first.',
      );
    }

    const updatedUser = await this.usersService.updateUser(user.id, body);

    if (!updatedUser) {
      throw new NotFoundException('User profile not found.');
    }

    return updatedUser;
  }

  @Delete('me')
  @UseGuards(FirebaseAuthGuard)
  async deleteCurrentUser(@CurrentUser() firebaseUser: DecodedIdToken) {
    const user = await this.usersService.getUserByFirebaseUid(firebaseUser.uid);

    if (!user) {
      throw new NotFoundException('User profile not found.');
    }

    const deactivatedUser = await this.usersService.deactivateUser(user.id);

    if (!deactivatedUser) {
      throw new NotFoundException('User profile not found.');
    }

    return {
      message: 'Account deactivated successfully.',
    };
  }
}
