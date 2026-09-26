import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RideGuardian } from './entities/ride-guardian.entity.js';

@Module({
  imports: [TypeOrmModule.forFeature([RideGuardian])],
})
export class RideGuardiansModule {}