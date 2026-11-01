import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { InjectRepository } from '@nestjs/typeorm';

import {
  DataSource,
  IsNull,
  Repository,
} from 'typeorm';

import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';

import { RideGuardian } from '../ride-guardians/entities/ride-guardian.entity.js';

import { RiderSafetySettings } from '../rider-safety-settings/entities/rider-safety-settings.entity.js';

import { UsersService } from '../users/users.service.js';

import { User } from '../users/entities/user.entity.js';

import { CreateRideDto } from './dto/create-ride.dto.js';

import { RideLocation } from './entities/ride-location.entity.js';

import { Ride } from './entities/ride.entity.js';

import { RideTrackingGateway } from './ride-tracking.gateway.js';

@Injectable()
export class RidesService {
  constructor(
    @InjectRepository(Ride)
    private readonly rideRepository: Repository<Ride>,

    @InjectRepository(RideLocation)
    private readonly rideLocationRepository: Repository<RideLocation>,

    @InjectRepository(RiderSafetySettings)
    private readonly safetySettingsRepository: Repository<RiderSafetySettings>,

    private readonly usersService: UsersService,

    private readonly dataSource: DataSource,

    private readonly rideTrackingGateway: RideTrackingGateway,
  ) {}

  /**
   * Creates a ride and all guardian assignments atomically.
   */
  async createRide(
    riderId: string,
    dto: CreateRideDto,
  ) {
    const guardianIds = dto.guardianIds;

    if (
      !Array.isArray(guardianIds) ||
      guardianIds.length === 0
    ) {
      throw new ConflictException(
        'At least one guardian must be selected',
      );
    }

    if (new Set(guardianIds).size !== guardianIds.length) {
      throw new ConflictException(
        'Duplicate guardian IDs are not allowed',
      );
    }

    const rider = await this.usersService.getUserById(
      riderId,
    );

    if (!rider || !rider.isActive) {
      throw new NotFoundException('Rider not found');
    }

    await this.validateGuardians(
      riderId,
      guardianIds,
    );

    return this.dataSource.transaction(
      'READ COMMITTED',
      async (manager) => {
        const rideRepository = manager.getRepository(Ride);

        const guardianRepository =
          manager.getRepository(RideGuardian);

        const relationshipRepository =
          manager.getRepository(GuardianRiderRelationship);

        const activeRide = await rideRepository.findOne({
          where: {
            riderId,
            status: 'ACTIVE',
          },
          lock: {
            mode: 'pessimistic_write',
          },
        });

        if (activeRide) {
          throw new ConflictException(
            'Rider already has an active ride',
          );
        }

        const guardians = await manager
          .getRepository(User)
          .find({
            where: guardianIds.map((id) => ({
              id,
              isActive: true,
            })),
          });

        if (guardians.length !== guardianIds.length) {
          throw new ForbiddenException(
            'One or more selected guardians do not exist or are inactive',
          );
        }

        const relationships =
          await relationshipRepository.find({
            where: guardianIds.map((guardianId) => ({
              guardianId,
              riderId,
              status: 'ACCEPTED',
            })),
          });

        const acceptedGuardianIds = new Set(
          relationships.map(
            (relationship) => relationship.guardianId,
          ),
        );

        const invalidGuardianIds = guardianIds.filter(
          (guardianId) =>
            !acceptedGuardianIds.has(guardianId),
        );

        if (invalidGuardianIds.length > 0) {
          throw new ForbiddenException(
            'Every selected guardian must have an accepted relationship with this rider',
          );
        }

        let ride = rideRepository.create({
          riderId,
          rideCode: this.generateRideCode(),
          status: 'CANCELLED',
          startedAt: new Date(),
        });

        ride = await rideRepository.save(ride);

        const assignments = guardianIds.map(
          (guardianId) =>
            guardianRepository.create({
              rideId: ride.id,
              guardianId,
              removedAt: null,
            }),
        );

        await guardianRepository.save(assignments);

        ride.status = 'ACTIVE';

        ride = await rideRepository.save(ride);

        return {
          ...ride,
          guardians: assignments.map((assignment) => ({
            id: assignment.id,
            guardianId: assignment.guardianId,
            addedAt: assignment.addedAt,
          })),
        };
      },
    );
  }

  private async validateGuardians(
    riderId: string,
    guardianIds: string[],
  ): Promise<void> {
    const userRepository =
      this.dataSource.getRepository(User);

    const relationshipRepository =
      this.dataSource.getRepository(
        GuardianRiderRelationship,
      );

    const guardians = await userRepository.find({
      where: guardianIds.map((id) => ({
        id,
        isActive: true,
      })),
    });

    if (guardians.length !== guardianIds.length) {
      throw new ForbiddenException(
        'One or more selected guardians do not exist or are inactive',
      );
    }

    if (guardianIds.includes(riderId)) {
      throw new ForbiddenException(
        'A rider cannot be their own guardian',
      );
    }

    const relationships =
      await relationshipRepository.find({
        where: guardianIds.map((guardianId) => ({
          guardianId,
          riderId,
          status: 'ACCEPTED',
        })),
      });

    const acceptedGuardianIds = new Set(
      relationships.map(
        (relationship) => relationship.guardianId,
      ),
    );

    if (
      guardianIds.some(
        (guardianId) =>
          !acceptedGuardianIds.has(guardianId),
      )
    ) {
      throw new ForbiddenException(
        'Every selected guardian must have an accepted relationship with this rider',
      );
    }
  }

  async getRides(riderId: string): Promise<Ride[]> {
    return this.rideRepository.find({
      where: { riderId },
      order: { startedAt: 'DESC' },
    });
  }

  async getActiveRide(
    riderId: string,
  ): Promise<Ride | null> {
    return this.rideRepository.findOne({
      where: {
        riderId,
        status: 'ACTIVE',
      },
      order: { startedAt: 'DESC' },
    });
  }

  /**
   * Returns active rides currently assigned to this guardian.
   */
  async getGuardianActiveRides(guardianId: string) {
    const assignments =
      await this.dataSource
        .getRepository(RideGuardian)
        .find({
          where: {
            guardianId,
            removedAt: IsNull(),
          },
          order: {
            addedAt: 'DESC',
          },
        });

    if (assignments.length === 0) {
      return [];
    }

    const rides = await this.rideRepository.find({
      where: assignments.map((assignment) => ({
        id: assignment.rideId,
        status: 'ACTIVE',
      })),
      order: {
        startedAt: 'DESC',
      },
    });

    const assignmentMap = new Map(
      assignments.map((assignment) => [
        assignment.rideId,
        assignment,
      ]),
    );

    return rides.map((ride) => {
      const assignment = assignmentMap.get(ride.id);

      return {
        ...ride,
        guardianAssignmentId: assignment?.id,
        guardianAddedAt: assignment?.addedAt,
      };
    });
  }

  async getRide(
    riderId: string,
    rideId: string,
  ): Promise<Ride> {
    const ride = await this.rideRepository.findOne({
      where: { id: rideId },
    });

    if (!ride) {
      throw new NotFoundException('Ride not found');
    }

    if (ride.riderId !== riderId) {
      throw new ForbiddenException(
        'You do not have access to this ride',
      );
    }

    return ride;
  }

  /**
   * Provides the latest location and the authenticated
   * user's applicable speed-monitoring settings.
   *
   * The rider and assigned guardians are authorized.
   */
  async getTrackingSnapshot(
    userId: string,
    rideId: string,
  ) {
    const ride = await this.rideRepository.findOne({
      where: { id: rideId },
    });

    if (!ride) {
      throw new NotFoundException('Ride not found');
    }

    const isRider = ride.riderId === userId;

    let isGuardian = false;

    if (!isRider) {
      const assignment =
        await this.dataSource
          .getRepository(RideGuardian)
          .findOne({
            where: {
              rideId,
              guardianId: userId,
              removedAt: IsNull(),
            },
          });

      isGuardian = assignment !== null;
    }

    if (!isRider && !isGuardian) {
      throw new ForbiddenException(
        'You do not have permission to monitor this ride',
      );
    }

    const currentLocation =
      await this.rideLocationRepository.findOne({
        where: { rideId },
        order: {
          recordedAt: 'DESC',
        },
      });

    /*
     * Retrieve settings belonging to this guardian only.
     * Different guardians can configure different limits
     * for the same rider.
     */
    let settings: RiderSafetySettings | null = null;

    if (isGuardian) {
      settings =
        await this.safetySettingsRepository.findOne({
          where: {
            guardianId: userId,
            riderId: ride.riderId,
          },
        });
    }

    return {
      ride,
      currentLocation,
      speedLimitKmh:
        settings?.maxSpeedKmh != null
          ? Number(settings.maxSpeedKmh)
          : null,
      speedAlertEnabled:
        settings?.speedAlertEnabled ?? false,
    };
  }

  async endRide(
    riderId: string,
    rideId: string,
  ): Promise<Ride> {
    const ride = await this.getRide(
      riderId,
      rideId,
    );

    if (ride.status !== 'ACTIVE') {
      throw new ConflictException(
        `Ride is already ${ride.status.toLowerCase()}`,
      );
    }

    ride.status = 'COMPLETED';
    ride.endedAt = new Date();

    const savedRide = await this.rideRepository.save(
      ride,
    );

    /*
     * Inform all connected guardians and the rider that
     * the ride has ended.
     */
    this.rideTrackingGateway.broadcastRideEnded(
      rideId,
    );

    return savedRide;
  }

  async getRideSummary(
    riderId: string,
    rideId: string,
  ) {
    const ride = await this.getRide(
      riderId,
      rideId,
    );

    const locations =
      await this.rideLocationRepository.find({
        where: { rideId },
        order: { recordedAt: 'ASC' },
      });

    if (locations.length === 0) {
      return {
        rideId: ride.id,
        rideCode: ride.rideCode,
        status: ride.status,
        startedAt: ride.startedAt,
        endedAt: ride.endedAt,
        durationSeconds: this.calculateDuration(
          ride.startedAt,
          ride.endedAt,
        ),
        distanceKm: 0,
        averageSpeedKmh: 0,
        maxSpeedKmh: 0,
        locationCount: 0,
      };
    }

    let distanceKm = 0;
    let totalSpeed = 0;
    let speedCount = 0;
    let maxSpeedKmh = 0;

    for (let i = 0; i < locations.length; i++) {
      const location = locations[i];

      if (
        location.speedKmh !== null &&
        location.speedKmh !== undefined
      ) {
        totalSpeed += location.speedKmh;
        speedCount++;

        maxSpeedKmh = Math.max(
          maxSpeedKmh,
          location.speedKmh,
        );
      }

      if (i > 0) {
        const previousLocation = locations[i - 1];

        distanceKm += this.calculateDistanceKm(
          previousLocation.latitude,
          previousLocation.longitude,
          location.latitude,
          location.longitude,
        );
      }
    }

    return {
      rideId: ride.id,
      rideCode: ride.rideCode,
      status: ride.status,
      startedAt: ride.startedAt,
      endedAt: ride.endedAt,
      durationSeconds: this.calculateDuration(
        ride.startedAt,
        ride.endedAt,
      ),
      distanceKm: Number(distanceKm.toFixed(2)),
      averageSpeedKmh:
        speedCount > 0
          ? Number(
              (totalSpeed / speedCount).toFixed(2),
            )
          : 0,
      maxSpeedKmh: Number(maxSpeedKmh.toFixed(2)),
      locationCount: locations.length,
    };
  }

  async getRideLocations(
    riderId: string,
    rideId: string,
  ): Promise<RideLocation[]> {
    await this.getRide(riderId, rideId);

    return this.rideLocationRepository.find({
      where: { rideId },
      order: { recordedAt: 'ASC' },
    });
  }

  async getCurrentLocation(
    riderId: string,
    rideId: string,
  ): Promise<RideLocation> {
    await this.getRide(riderId, rideId);

    const location =
      await this.rideLocationRepository.findOne({
        where: { rideId },
        order: { recordedAt: 'DESC' },
      });

    if (!location) {
      throw new NotFoundException(
        'No location data found for this ride',
      );
    }

    return location;
  }

  private generateRideCode(): string {
    const timestamp =
      Date.now().toString(36).toUpperCase();

    const random = Math.random()
      .toString(36)
      .substring(2, 6)
      .toUpperCase();

    return `RG-${timestamp.slice(-6)}-${random}`;
  }

  private calculateDuration(
    startedAt: Date,
    endedAt: Date | null,
  ): number {
    const endTime = endedAt?.getTime() ?? Date.now();

    return Math.max(
      0,
      Math.floor(
        (endTime - startedAt.getTime()) / 1000,
      ),
    );
  }

  private calculateDistanceKm(
    latitude1: number,
    longitude1: number,
    latitude2: number,
    longitude2: number,
  ): number {
    const earthRadiusKm = 6371;

    const lat1 = this.toRadians(latitude1);
    const lat2 = this.toRadians(latitude2);

    const deltaLat = this.toRadians(
      latitude2 - latitude1,
    );

    const deltaLongitude = this.toRadians(
      longitude2 - longitude1,
    );

    const a =
      Math.sin(deltaLat / 2) ** 2 +
      Math.cos(lat1) *
        Math.cos(lat2) *
        Math.sin(deltaLongitude / 2) ** 2;

    const c =
      2 *
      Math.atan2(
        Math.sqrt(a),
        Math.sqrt(1 - a),
      );

    return earthRadiusKm * c;
  }

  private toRadians(degrees: number): number {
    return degrees * (Math.PI / 180);
  }
}