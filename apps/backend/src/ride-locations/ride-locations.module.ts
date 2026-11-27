import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RideLocation } from './entities/ride-location.entity.js';

@Module({
  imports: [TypeOrmModule.forFeature([RideLocation])],
})
export class RideLocationsModule {}