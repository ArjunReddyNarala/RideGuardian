import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';

import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';
import { Ride } from '../rides/entities/ride.entity.js';
import { User } from '../users/entities/user.entity.js';

import { AddRideGuardianDto } from './dto/add-ride-guardian.dto.js';
import { RideGuardian } from './entities/ride-guardian.entity.js';

@Injectable()
export class RideGuardiansService {
  constructor(
    @InjectRepository(RideGuardian)
    private readonly rideGuardianRepository: Repository<RideGuardian>,

    @InjectRepository(Ride)
    private readonly rideRepository: Repository<Ride>,

    @InjectRepository(GuardianRiderRelationship)
    private readonly relationshipRepository: Repository<GuardianRiderRelationship>,

    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  /**
   * Add a guardian to a ride.
   */
  async addGuardian(
    riderId: string,
    rideId: string,
    dto: AddRideGuardianDto,
  ): Promise<RideGuardian> {
    // Verify that the ride belongs to the authenticated rider.
    const ride = await this.getOwnedRide(riderId, rideId);

    // Only allow guardians to be added while the ride is active.
    if (ride.status !== 'ACTIVE') {
      throw new ConflictException(
        'Guardians can only be added to an active ride',
      );
    }

    // A rider cannot add themselves as their own guardian.
    if (riderId === dto.guardianId) {
      throw new ForbiddenException(
        'A rider cannot be their own guardian',
      );
    }

    // Verify that the guardian exists and has an active account.
    const guardian = await this.userRepository.findOne({
      where: {
        id: dto.guardianId,
        isActive: true,
      },
    });

    if (!guardian) {
      throw new NotFoundException(
        'Guardian not found or inactive',
      );
    }

    // Verify that the guardian has an accepted relationship
    // with the rider who owns this ride.
    const relationship =
      await this.relationshipRepository.findOne({
        where: {
          guardianId: dto.guardianId,
          riderId,
          status: 'ACCEPTED',
        },
      });

    if (!relationship) {
      throw new ForbiddenException(
        'The guardian does not have an accepted relationship with this rider',
      );
    }

    // Look for an existing assignment, including removed assignments.
    const existingAssignment =
      await this.rideGuardianRepository.findOne({
        where: {
          rideId,
          guardianId: dto.guardianId,
        },
      });

    if (existingAssignment) {
      // The guardian is already assigned to this ride.
      if (!existingAssignment.removedAt) {
        throw new ConflictException(
          'Guardian is already assigned to this ride',
        );
      }

      // Restore the previous assignment instead of inserting a duplicate.
      existingAssignment.removedAt = null;

      return this.rideGuardianRepository.save(
        existingAssignment,
      );
    }

    // Create a new ride-guardian assignment.
    const assignment = this.rideGuardianRepository.create({
      rideId,
      guardianId: dto.guardianId,
      removedAt: null,
    });

    return this.rideGuardianRepository.save(assignment);
  }

  /**
   * Get all currently assigned guardians for a ride.
   */
  async getGuardians(
    riderId: string,
    rideId: string,
  ) {
    // Only the rider who owns the ride can list its guardians.
    await this.getOwnedRide(riderId, rideId);

    const assignments =
      await this.rideGuardianRepository.find({
        where: {
          rideId,
          removedAt: IsNull(),
        },
        order: {
          addedAt: 'ASC',
        },
      });

    // Return assignment information together with guardian profiles.
    const guardians = await Promise.all(
      assignments.map(async (assignment) => {
        const guardian = await this.userRepository.findOne({
          where: {
            id: assignment.guardianId,
          },
        });

        if (!guardian) {
          return null;
        }

        return {
          id: assignment.id,
          rideId: assignment.rideId,
          guardianId: guardian.id,
          name: guardian.name,
          email: guardian.email,
          phone: guardian.phone,
          profileImageUrl: guardian.profileImageUrl,
          addedAt: assignment.addedAt,
        };
      }),
    );

    return guardians.filter(
      (guardian) => guardian !== null,
    );
  }

  /**
   * Remove a guardian from a ride.
   */
  async removeGuardian(
    riderId: string,
    rideId: string,
    guardianId: string,
  ) {
    // Verify that the authenticated rider owns the ride.
    await this.getOwnedRide(riderId, rideId);

    const assignment =
      await this.rideGuardianRepository.findOne({
        where: {
          rideId,
          guardianId,
          removedAt: IsNull(),
        },
      });

    if (!assignment) {
      throw new NotFoundException(
        'Guardian is not assigned to this ride',
      );
    }

    // Soft removal preserves the assignment history.
    assignment.removedAt = new Date();

    await this.rideGuardianRepository.save(assignment);

    return {
      message: 'Guardian removed from ride successfully',
      rideId,
      guardianId,
    };
  }

  /**
   * Verify ride ownership.
   *
   * The caller supplies riderId from the authenticated user's
   * database profile, never from the request body.
   */
  private async getOwnedRide(
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
        'You do not have permission to manage guardians for this ride',
      );
    }

    return ride;
  }
}