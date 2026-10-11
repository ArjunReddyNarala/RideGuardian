import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';
import { UsersModule } from '../users/users.module.js';

import { GuardiansController } from './guardians.controller.js';
import { GuardiansService } from './guardians.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      GuardianRiderRelationship,
    ]),
    UsersModule,
  ],
  controllers: [GuardiansController],
  providers: [GuardiansService],
  exports: [GuardiansService],
})
export class GuardiansModule {}