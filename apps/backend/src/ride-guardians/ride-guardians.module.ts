import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';
import { Ride } from '../rides/entities/ride.entity.js';
import { User } from '../users/entities/user.entity.js';
import { UsersModule } from '../users/users.module.js';

import { RideGuardian } from './entities/ride-guardian.entity.js';
import { RideGuardiansController } from './ride-guardians.controller.js';
import { RideGuardiansService } from './ride-guardians.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      RideGuardian,
      Ride,
      User,
      GuardianRiderRelationship,
    ]),
    UsersModule,
  ],
  controllers: [RideGuardiansController],
  providers: [RideGuardiansService],
  exports: [RideGuardiansService],
})
export class RideGuardiansModule {}