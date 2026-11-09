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

import { NotificationsService } from '../notifications/notifications.service.js';

import { RideLocationDto } from './dto/ride-location.dto.js';

interface LocationSample {
  latitude: number;
  longitude: number;
  accuracyMeters: number | null;
  recordedAt: Date;
}

interface RideLocationSamplingState {
  hasStartPoint: boolean;
  previousFix: LocationSample | null;
  movementAnchor: LocationSample | null;
  distanceSinceCheckpointMeters: number;
}

@Injectable()
export class RideTrackingService {
  private static readonly checkpointDistanceMeters = 250;
  private static readonly maximumAccuracyMeters = 50;
  private static readonly minimumMovementMeters = 3;
  private static readonly maximumNoiseThresholdMeters = 15;
  private static readonly maximumPlausibleSpeedMetersPerSecond = 70;
  private static readonly maximumFixGapMs = 15_000;
  private static readonly maximumFixAgeMs = 30_000;

  private readonly lastPersistedLocations = new Map<
    string,
    Pick<RideLocation, 'latitude' | 'longitude' | 'accuracy' | 'recordedAt'>
  >();
  private readonly samplingStates = new Map<string, RideLocationSamplingState>();

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

    private readonly notificationsService: NotificationsService,
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

    // Every GPS fix remains live over WebSocket. Persist a route checkpoint
    // only after 250 meters of filtered movement have accumulated.
    if (await this.shouldPersistLocation(rideId, dto)) {
      const savedLocation = await this.locationRepository.save(
        this.createRideLocation(rideId, dto),
      );
      this.lastPersistedLocations.set(rideId, savedLocation);
      this.markCheckpointSaved(rideId, dto);
    }

    // Get all active guardians assigned to this ride.
    const assignments = await this.rideGuardianRepository.find({
      where: {
        rideId,
        removedAt: IsNull(),
      },
    });

    const guardianIds = assignments.map((assignment) => assignment.guardianId);

    if (guardianIds.length === 0 || dto.speedKmh == null) {
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
      await this.notificationsService.createForUser({
        userId: setting.guardianId,
        safetyAlertId: savedAlert.id,
        type: 'SPEED_LIMIT_EXCEEDED',
        title: 'Speed limit exceeded',
        body: `Your rider is travelling at ${dto.speedKmh.toFixed(2)} km/h. Configured limit: ${Number(setting.maxSpeedKmh).toFixed(1)} km/h.`,
        category: 'SAFETY',
      });

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

  private async shouldPersistLocation(
    rideId: string,
    dto: RideLocationDto,
  ): Promise<boolean> {
    const sample = this.toLocationSample(dto);
    if (!this.isFreshAccurateFix(sample)) return false;

    const state = await this.getSamplingState(rideId);
    if (!state.hasStartPoint) {
      this.setSamplingAnchor(state, sample);
      return true;
    }

    const previousFix = state.previousFix;
    const movementAnchor = state.movementAnchor;
    if (!previousFix || !movementAnchor) {
      this.setSamplingAnchor(state, sample);
      return false;
    }

    const gapMs = sample.recordedAt.getTime() - previousFix.recordedAt.getTime();
    if (gapMs <= 0) return false;

    if (gapMs > RideTrackingService.maximumFixGapMs) {
      this.setSamplingAnchor(state, sample);
      return false;
    }

    const fixDistanceMeters = this.distanceBetweenMeters(
      previousFix.latitude,
      previousFix.longitude,
      sample.latitude,
      sample.longitude,
    );
    const maximumPlausibleDistance =
      (gapMs / 1000) *
        RideTrackingService.maximumPlausibleSpeedMetersPerSecond +
      10;

    if (
      !Number.isFinite(fixDistanceMeters) ||
      fixDistanceMeters > maximumPlausibleDistance
    ) {
      this.setSamplingAnchor(state, sample);
      return false;
    }

    state.previousFix = sample;

    const distanceFromAnchor = this.distanceBetweenMeters(
      movementAnchor.latitude,
      movementAnchor.longitude,
      sample.latitude,
      sample.longitude,
    );
    const accuracyForAnchor =
      movementAnchor.accuracyMeters ?? sample.accuracyMeters ?? 0;
    const accuracyForFix = sample.accuracyMeters ?? accuracyForAnchor;
    const movementThreshold = Math.max(
      RideTrackingService.minimumMovementMeters,
      Math.min(
        RideTrackingService.maximumNoiseThresholdMeters,
        (accuracyForAnchor + accuracyForFix) / 2,
      ),
    );

    // Keep the movement anchor until GPS displacement clears its uncertainty
    // threshold. This lets small steps accumulate instead of being discarded.
    if (distanceFromAnchor < movementThreshold) return false;

    state.movementAnchor = sample;
    state.distanceSinceCheckpointMeters += distanceFromAnchor;
    return (
      state.distanceSinceCheckpointMeters >=
      RideTrackingService.checkpointDistanceMeters
    );
  }

  async persistFinalLocation(rideId: string, dto: RideLocationDto) {
    const sample = this.toLocationSample(dto);
    if (!this.isFreshAccurateFix(sample)) return;

    const previous =
      this.lastPersistedLocations.get(rideId) ??
      (await this.locationRepository.findOne({
        where: { rideId },
        order: { recordedAt: 'DESC' },
      }));

    if (!previous) {
      const saved = await this.locationRepository.save(
        this.createRideLocation(rideId, dto),
      );
      this.lastPersistedLocations.set(rideId, saved);
      this.markCheckpointSaved(rideId, dto);
      return;
    }

    const distanceFromLastSaved = this.distanceBetweenMeters(
      previous.latitude,
      previous.longitude,
      dto.latitude,
      dto.longitude,
    );
    if (distanceFromLastSaved >= 1) {
      const saved = await this.locationRepository.save(
        this.createRideLocation(rideId, dto),
      );
      this.lastPersistedLocations.set(rideId, saved);
    }
    this.clearRideSamplingState(rideId);
  }

  clearRideSamplingState(rideId: string) {
    this.lastPersistedLocations.delete(rideId);
    this.samplingStates.delete(rideId);
  }

  private async getSamplingState(
    rideId: string,
  ): Promise<RideLocationSamplingState> {
    const cached = this.samplingStates.get(rideId);
    if (cached) return cached;

    const latest =
      this.lastPersistedLocations.get(rideId) ??
      (await this.locationRepository.findOne({
        where: { rideId },
        order: { recordedAt: 'DESC' },
      }));

    if (latest) this.lastPersistedLocations.set(rideId, latest);
    const anchor = latest
      ? {
          latitude: latest.latitude,
          longitude: latest.longitude,
          accuracyMeters: latest.accuracy ?? null,
          recordedAt: latest.recordedAt,
        }
      : null;

    const state: RideLocationSamplingState = {
      hasStartPoint: latest != null,
      previousFix: anchor,
      movementAnchor: anchor,
      distanceSinceCheckpointMeters: 0,
    };
    this.samplingStates.set(rideId, state);
    return state;
  }

  private markCheckpointSaved(rideId: string, dto: RideLocationDto) {
    const state = this.samplingStates.get(rideId);
    if (!state) return;
    state.hasStartPoint = true;
    state.distanceSinceCheckpointMeters = 0;
    this.setSamplingAnchor(state, this.toLocationSample(dto));
  }

  private setSamplingAnchor(
    state: RideLocationSamplingState,
    sample: LocationSample,
  ) {
    state.previousFix = sample;
    state.movementAnchor = sample;
  }

  private toLocationSample(dto: RideLocationDto): LocationSample {
    return {
      latitude: dto.latitude,
      longitude: dto.longitude,
      accuracyMeters: dto.accuracyMeters ?? null,
      recordedAt: dto.recordedAt ? new Date(dto.recordedAt) : new Date(),
    };
  }

  private isFreshAccurateFix(sample: LocationSample) {
    const ageMs = Date.now() - sample.recordedAt.getTime();
    return (
      Number.isFinite(sample.latitude) &&
      Number.isFinite(sample.longitude) &&
      ageMs >= -5_000 &&
      ageMs <= RideTrackingService.maximumFixAgeMs &&
      sample.accuracyMeters != null &&
      Number.isFinite(sample.accuracyMeters) &&
      sample.accuracyMeters >= 0 &&
      sample.accuracyMeters <= RideTrackingService.maximumAccuracyMeters
    );
  }

  private createRideLocation(rideId: string, dto: RideLocationDto) {
    return this.locationRepository.create({
      rideId,
      latitude: dto.latitude,
      longitude: dto.longitude,
      speedKmh: dto.speedKmh ?? null,
      accuracy: dto.accuracyMeters ?? null,
      heading: dto.headingDegrees ?? null,
      recordedAt: dto.recordedAt ? new Date(dto.recordedAt) : new Date(),
    });
  }

  private distanceBetweenMeters(
    latitudeA: number,
    longitudeA: number,
    latitudeB: number,
    longitudeB: number,
  ): number {
    const radians = (degrees: number) => (degrees * Math.PI) / 180;
    const deltaLatitude = radians(latitudeB - latitudeA);
    const deltaLongitude = radians(longitudeB - longitudeA);
    const haversine =
      Math.sin(deltaLatitude / 2) ** 2 +
      Math.cos(radians(latitudeA)) *
        Math.cos(radians(latitudeB)) *
        Math.sin(deltaLongitude / 2) ** 2;

    return (
      6_371_000 * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine))
    );
  }
}
