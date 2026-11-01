import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';

import { RideGuardian } from '../ride-guardians/entities/ride-guardian.entity.js';

import { UsersModule } from '../users/users.module.js';

import { RiderSafetySettings } from '../rider-safety-settings/entities/rider-safety-settings.entity.js';

import { SafetyAlert } from '../safety-alerts/entities/safety-alert.entity.js';

import { Notification } from '../notifications/entities/notification.entity.js';

import { AuthModule } from '../auth/auth.module.js';

import { Ride } from './entities/ride.entity.js';

import { RideLocation } from './entities/ride-location.entity.js';

import { RidesController } from './rides.controller.js';

import { RidesService } from './rides.service.js';

import { RideTrackingGateway } from './ride-tracking.gateway.js';

import { RideTrackingService } from './ride-tracking.service.js';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Ride,
      RideLocation,
      RideGuardian,
      GuardianRiderRelationship,
      RiderSafetySettings,
      SafetyAlert,
      Notification,
    ]),

    UsersModule,
    AuthModule,
  ],

  controllers: [
    RidesController,
  ],

  providers: [
    RidesService,
    RideTrackingService,
    RideTrackingGateway,
  ],

  exports: [
    RidesService,
    RideTrackingService,
  ],
})
export class RidesModule {}