import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RideEvent } from './entities/ride-event.entity.js';

@Module({
  imports: [TypeOrmModule.forFeature([RideEvent])],
})
export class RideEventsModule {}