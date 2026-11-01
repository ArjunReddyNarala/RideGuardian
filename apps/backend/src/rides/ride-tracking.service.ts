import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { InjectRepository } from '@nestjs/typeorm';

import { IsNull, Repository } from 'typeorm';

import { Ride } from './entities/ride.entity.js';

import { RideLocation } from './entities/ride-location.entity.js';

import { RideGuardian } from '../ride-guardians/entities/ride-guardian.entity.js';

import { RiderSafetySettings } from '../rider-safety-settings/entities/rider-safety-settings.entity.js';

import { SafetyAlert } from '../safety-alerts/entities/safety-alert.entity.js';

import { Notification } from '../notifications/entities/notification.entity.js';

import { RideLocationDto } from './dto/ride-location.dto.js';

@Injectable()
export class RideTrackingService {
  constructor(
    @InjectRepository(Ride)
    private readonly rideRepository: Repository<Ride>,

    @InjectRepository(RideLocation)
    private readonly locationRepository: Repository<RideLocation>,

    @InjectRepository(RideGuardian)
    private readonly rideGuardianRepository: Repository<RideGuardian>,

    @InjectRepository(RiderSafetySettings)
    private readonly safetySettingsRepository: Repository<RiderSafetySettings>,

    @InjectRepository(SafetyAlert)
    private readonly safetyAlertRepository: Repository<SafetyAlert>,

    @InjectRepository(Notification)
    private readonly notificationRepository: Repository<Notification>,
  ) {}

  async processLocation(riderId: string, rideId: string, dto: RideLocationDto) {
    const ride = await this.rideRepository.findOne({
      where: {
        id: rideId,
        riderId,
        status: 'ACTIVE',
      },
    });

    if (!ride) {
      throw new ForbiddenException(
        'The ride is not active or does not belong to this rider',
      );
    }

    // Persist the rider's latest location.
    const location = this.locationRepository.create({
      rideId,
      latitude: dto.latitude,
      longitude: dto.longitude,
      speedKmh: dto.speedKmh,
      accuracy: dto.accuracyMeters ?? null,
      heading: dto.headingDegrees ?? null,
      recordedAt: new Date(),
    });

    await this.locationRepository.save(location);

    // Get all active guardians assigned to this ride.
    const assignments = await this.rideGuardianRepository.find({
      where: {
        rideId,
        removedAt: IsNull(),
      },
    });

    const guardianIds = assignments.map((assignment) => assignment.guardianId);

    if (guardianIds.length === 0) {
      return { alerts: [] };
    }

    // Get speed-alert settings configured by each guardian.
    const settings = await this.safetySettingsRepository.find({
      where: guardianIds.map((guardianId) => ({
        guardianId,
        riderId,
        speedAlertEnabled: true,
      })),
    });

    const alerts: Array<Record<string, unknown>> = [];

    for (const setting of settings) {
      if (
        setting.maxSpeedKmh == null ||
        dto.speedKmh <= Number(setting.maxSpeedKmh)
      ) {
        continue;
      }

      const cooldown = setting.speedAlertCooldownSeconds ?? 60;

      // Check the latest alert to prevent repeated notifications.
      const latestAlert = await this.safetyAlertRepository.findOne({
        where: {
          rideId,
          guardianId: setting.guardianId,
          riderId,
          type: 'SPEED_LIMIT_EXCEEDED',
        },
        order: {
          triggeredAt: 'DESC',
        },
      });

      if (
        latestAlert &&
        Date.now() - latestAlert.triggeredAt.getTime() < cooldown * 1000
      ) {
        continue;
      }

      // Create a speed-limit alert.
      const alert = this.safetyAlertRepository.create({
        rideId,
        riderId,
        guardianId: setting.guardianId,
        type: 'SPEED_LIMIT_EXCEEDED',
        severity: 'HIGH',
        currentSpeedKmh: dto.speedKmh,
        configuredSpeedLimitKmh: Number(setting.maxSpeedKmh),
        latitude: dto.latitude,
        longitude: dto.longitude,
        status: 'ACTIVE',
        triggeredAt: new Date(),
      });

      const savedAlert = await this.safetyAlertRepository.save(alert);

      // Notify the guardian.
      await this.notificationRepository.save(
        this.notificationRepository.create({
          userId: setting.guardianId,
          safetyAlertId: savedAlert.id,
          type: 'SPEED_LIMIT_EXCEEDED',
          title: 'Speed limit exceeded',
          body: `Your rider is travelling at ${dto.speedKmh.toFixed(1)} km/h. Configured limit: ${Number(setting.maxSpeedKmh).toFixed(1)} km/h.`,
        }),
      );

      alerts.push({
        alertId: savedAlert.id,
        guardianId: setting.guardianId,
        currentSpeedKmh: dto.speedKmh,
        speedLimitKmh: Number(setting.maxSpeedKmh),
        latitude: dto.latitude,
        longitude: dto.longitude,
        triggeredAt: savedAlert.triggeredAt.toISOString(),
      });
    }

    return { alerts };
  }
}
