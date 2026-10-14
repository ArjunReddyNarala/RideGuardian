import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { SafetyAlert } from './entities/safety-alert.entity.js';
import { SafetyAlertsController } from './safety-alerts.controller.js';
import { SafetyAlertsService } from './safety-alerts.service.js';
import { UsersModule } from '../users/users.module.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([SafetyAlert]),
    UsersModule,
  ],
  controllers: [SafetyAlertsController],
  providers: [SafetyAlertsService],
  exports: [SafetyAlertsService],
})
export class SafetyAlertsModule {}