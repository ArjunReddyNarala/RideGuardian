import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';
import { UsersModule } from '../users/users.module.js';

import { RiderSafetySettingsController } from './rider-safety-settings.controller.js';
import { RiderSafetySettings } from './entities/rider-safety-settings.entity.js';
import { RiderSafetySettingsService } from './rider-safety-settings.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      RiderSafetySettings,
      GuardianRiderRelationship,
    ]),
    UsersModule,
  ],
  controllers: [RiderSafetySettingsController],
  providers: [RiderSafetySettingsService],
  exports: [RiderSafetySettingsService],
})
export class RiderSafetySettingsModule {}