import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';
import { Ride } from '../rides/entities/ride.entity.js';
import { UsersService } from '../users/users.service.js';

@Injectable()
export class RidersService {
  constructor(
    @InjectRepository(GuardianRiderRelationship)
    private readonly relationshipRepository: Repository<GuardianRiderRelationship>,

    @InjectRepository(Ride)
    private readonly rideRepository: Repository<Ride>,

    private readonly usersService: UsersService,
  ) {}

  async getRiders(userId: string) {
    const relationships =
      await this.relationshipRepository.find({
        where: {
          guardianId: userId,
          status: 'ACCEPTED',
        },
        order: {
          createdAt: 'DESC',
        },
      });

    const riders = await Promise.all(
      relationships.map(async (relationship) => {
        const rider = await this.usersService.getUserById(
          relationship.riderId,
        );

        return rider
          ? {
              id: rider.id,
              name: rider.name,
              email: rider.email,
              phone: rider.phone,
              profileImageUrl: rider.profileImageUrl,
              relationshipId: relationship.id,
              acceptedAt: relationship.acceptedAt,
            }
          : null;
      }),
    );

    return riders.filter(
      (rider) => rider !== null,
    );
  }

  async removeRider(
    userId: string,
    relationshipId: string,
  ) {
    const relationship =
      await this.relationshipRepository.findOne({
        where: {
          id: relationshipId,
          guardianId: userId,
        },
      });

    if (!relationship) {
      throw new NotFoundException(
        'Rider relationship not found',
      );
    }

    if (relationship.status !== 'ACCEPTED') {
      throw new ForbiddenException(
        'Only an accepted rider relationship can be removed',
      );
    }

    relationship.status = 'REVOKED';
    relationship.revokedAt = new Date();

    return this.relationshipRepository.save(
      relationship,
    );
  }

  async getActiveRide(
    guardianId: string,
    riderId: string,
  ) {
    await this.validateGuardianRiderRelationship(
      guardianId,
      riderId,
    );

    const rider = await this.usersService.getUserById(
      riderId,
    );

    if (!rider) {
      throw new NotFoundException('Rider not found');
    }

    const ride = await this.rideRepository.findOne({
      where: {
        riderId,
        status: 'ACTIVE',
      },
      order: {
        startedAt: 'DESC',
      },
    });

    return ride;
  }

  private async validateGuardianRiderRelationship(
    guardianId: string,
    riderId: string,
  ): Promise<void> {
    const relationship =
      await this.relationshipRepository.findOne({
        where: {
          guardianId,
          riderId,
          status: 'ACCEPTED',
        },
      });

    if (!relationship) {
      throw new ForbiddenException(
        'You do not have an accepted guardian relationship with this rider',
      );
    }
  }
}