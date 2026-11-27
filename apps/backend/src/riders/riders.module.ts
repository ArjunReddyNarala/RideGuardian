import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';
import { Ride } from '../rides/entities/ride.entity.js';
import { UsersModule } from '../users/users.module.js';

import { RidersController } from './riders.controller.js';
import { RidersService } from './riders.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      GuardianRiderRelationship,
      Ride,
    ]),
    UsersModule,
  ],
  controllers: [RidersController],
  providers: [RidersService],
  exports: [RidersService],
})
export class RidersModule {}