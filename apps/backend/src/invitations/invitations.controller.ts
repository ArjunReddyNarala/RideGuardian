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

import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { UsersService } from '../users/users.service.js';

import { CreateInvitationDto } from './dto/create-invitation.dto.js';
import { InvitationsService } from './invitations.service.js';

@ApiTags('Invitations')
@ApiBearerAuth()
@Controller('api/v1/invitations')
@UseGuards(FirebaseAuthGuard)
export class InvitationsController {
  constructor(
    private readonly invitationsService: InvitationsService,
    private readonly usersService: UsersService,
  ) {}

  @Post()
  async createInvitation(
    @CurrentUser() firebaseUser: { uid: string },
    @Body() dto: CreateInvitationDto,
  ) {
    const user = await this.getCurrentDatabaseUser(firebaseUser.uid);

    return this.invitationsService.createInvitation(user.id, dto);
  }

  @Get()
  async getInvitations(
    @CurrentUser() firebaseUser: { uid: string },
  ) {
    const user = await this.getCurrentDatabaseUser(firebaseUser.uid);

    return this.invitationsService.getInvitations(user.id);
  }

  @Patch(':token/accept')
  async acceptInvitation(
    @CurrentUser() firebaseUser: { uid: string },
    @Param('token') token: string,
  ) {
    const user = await this.getCurrentDatabaseUser(firebaseUser.uid);

    return this.invitationsService.acceptInvitation(token, user.id);
  }

  @Patch(':token/decline')
  async declineInvitation(
    @CurrentUser() firebaseUser: { uid: string },
    @Param('token') token: string,
  ) {
    const user = await this.getCurrentDatabaseUser(firebaseUser.uid);

    return this.invitationsService.declineInvitation(token, user.id);
  }

  @Patch(':id/cancel')
  async cancelInvitation(
    @CurrentUser() firebaseUser: { uid: string },
    @Param('id') invitationId: string,
  ) {
    const user = await this.getCurrentDatabaseUser(firebaseUser.uid);

    return this.invitationsService.cancelInvitation(
      invitationId,
      user.id,
    );
  }

  private async getCurrentDatabaseUser(firebaseUid: string) {
    const user = await this.usersService.getUserByFirebaseUid(firebaseUid);

    if (!user) {
      throw new NotFoundException('RideGuardian user profile not found');
    }

    return user;
  }
}