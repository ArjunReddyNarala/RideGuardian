import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import type { DecodedIdToken } from 'firebase-admin/auth';

import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { UsersService } from '../users/users.service.js';

import { CreateInvitationDto } from './dto/create-invitation.dto.js';
import { InvitationsService } from './invitations.service.js';

@Controller('api/v1/invitations')
@UseGuards(FirebaseAuthGuard)
export class InvitationsController {
  constructor(
    private readonly invitationsService: InvitationsService,
    private readonly usersService: UsersService,
  ) {}

  @Post()
  async createInvitation(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Body() dto: CreateInvitationDto,
  ) {
    const user = await this.getCurrentDatabaseUser(
      firebaseUser.uid,
    );

    return this.invitationsService.createInvitation(
      user.id,
      dto.inviteeEmail,
      dto.inviteePhone,
    );
  }

  @Get()
  async getInvitations(
    @CurrentUser() firebaseUser: DecodedIdToken,
  ) {
    const user = await this.getCurrentDatabaseUser(
      firebaseUser.uid,
    );

    return this.invitationsService.getInvitations(user.id);
  }

  @Patch(':token/accept')
  async acceptInvitation(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('token') token: string,
  ) {
    const rider = await this.getCurrentDatabaseUser(
      firebaseUser.uid,
    );

    return this.invitationsService.acceptInvitation(
      token,
      rider.id,
    );
  }

  @Patch(':token/decline')
  async declineInvitation(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('token') token: string,
  ) {
    const rider = await this.getCurrentDatabaseUser(
      firebaseUser.uid,
    );

    return this.invitationsService.declineInvitation(
      token,
      rider.id,
    );
  }

  @Patch(':id/cancel')
  async cancelInvitation(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('id') invitationId: string,
  ) {
    const inviter = await this.getCurrentDatabaseUser(
      firebaseUser.uid,
    );

    return this.invitationsService.cancelInvitation(
      invitationId,
      inviter.id,
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