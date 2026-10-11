import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { UsersModule } from '../users/users.module.js';

import { Ride } from './entities/ride.entity.js';
import { RideLocation } from './entities/ride-location.entity.js';
import { RidesController } from './rides.controller.js';
import { RidesService } from './rides.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Ride,
      RideLocation,
    ]),
    UsersModule,
  ],
  controllers: [RidesController],
  providers: [RidesService],
  exports: [RidesService],
})
export class RidesModule {}