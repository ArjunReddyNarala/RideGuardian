import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SafetyAlert } from './entities/safety-alert.entity.js';

@Module({
  imports: [TypeOrmModule.forFeature([SafetyAlert])],
})
export class SafetyAlertsModule {}