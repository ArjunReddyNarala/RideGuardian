import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { UsersModule } from '../users/users.module.js';
import { GuardianRelationshipsModule } from '../guardian-relationships/guardian-relationships.module.js';

import { Invitation } from './entities/invitation.entity.js';
import { InvitationsController } from './invitations.controller.js';
import { InvitationsService } from './invitations.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([Invitation]),
    UsersModule,
    GuardianRelationshipsModule,
  ],
  controllers: [InvitationsController],
  providers: [InvitationsService],
  exports: [InvitationsService],
})
export class InvitationsModule {}