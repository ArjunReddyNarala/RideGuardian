import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { UsersModule } from '../users/users.module.js';

import { GuardianRiderRelationship } from './entities/guardian-rider-relationship.entity.js';
import { GuardianRelationshipsController } from './guardian-relationships.controller.js';
import { GuardianRelationshipsService } from './guardian-relationships.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([GuardianRiderRelationship]),
    UsersModule,
  ],
  controllers: [GuardianRelationshipsController],
  providers: [GuardianRelationshipsService],
  exports: [GuardianRelationshipsService],
})
export class GuardianRelationshipsModule {}