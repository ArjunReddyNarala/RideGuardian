import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { RideLocation } from './entities/ride-location.entity.js';
import { Ride } from './entities/ride.entity.js';
import { UsersService } from '../users/users.service.js';

@Injectable()
export class RidesService {
  constructor(
    @InjectRepository(Ride)
    private readonly rideRepository: Repository<Ride>,

    @InjectRepository(RideLocation)
    private readonly rideLocationRepository: Repository<RideLocation>,

    private readonly usersService: UsersService,
  ) {}

  async createRide(riderId: string): Promise<Ride> {
    const rider = await this.usersService.getUserById(riderId);

    if (!rider || !rider.isActive) {
      throw new NotFoundException('Rider not found');
    }

    const activeRide = await this.rideRepository.findOne({
      where: {
        riderId,
        status: 'ACTIVE',
      },
    });

    if (activeRide) {
      throw new ConflictException(
        'Rider already has an active ride',
      );
    }

    const ride = this.rideRepository.create({
      riderId,
      rideCode: this.generateRideCode(),
      status: 'ACTIVE',
      startedAt: new Date(),
    });

    return this.rideRepository.save(ride);
  }

  async getRides(riderId: string): Promise<Ride[]> {
    return this.rideRepository.find({
      where: {
        riderId,
      },
      order: {
        startedAt: 'DESC',
      },
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
      order: {
        startedAt: 'DESC',
      },
    });
  }

  async getRide(
    riderId: string,
    rideId: string,
  ): Promise<Ride> {
    const ride = await this.rideRepository.findOne({
      where: {
        id: rideId,
      },
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

    return this.rideRepository.save(ride);
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
        where: {
          rideId,
        },
        order: {
          recordedAt: 'ASC',
        },
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
      distanceKm: Number(
        distanceKm.toFixed(2),
      ),
      averageSpeedKmh:
        speedCount > 0
          ? Number(
              (
                totalSpeed / speedCount
              ).toFixed(2),
            )
          : 0,
      maxSpeedKmh: Number(
        maxSpeedKmh.toFixed(2),
      ),
      locationCount: locations.length,
    };
  }

  async getRideLocations(
    riderId: string,
    rideId: string,
  ): Promise<RideLocation[]> {
    await this.getRide(riderId, rideId);

    return this.rideLocationRepository.find({
      where: {
        rideId,
      },
      order: {
        recordedAt: 'ASC',
      },
    });
  }

  async getCurrentLocation(
    riderId: string,
    rideId: string,
  ): Promise<RideLocation> {
    await this.getRide(riderId, rideId);

    const location =
      await this.rideLocationRepository.findOne({
        where: {
          rideId,
        },
        order: {
          recordedAt: 'DESC',
        },
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
    const endTime =
      endedAt?.getTime() ?? Date.now();

    return Math.max(
      0,
      Math.floor(
        (endTime - startedAt.getTime()) /
          1000,
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