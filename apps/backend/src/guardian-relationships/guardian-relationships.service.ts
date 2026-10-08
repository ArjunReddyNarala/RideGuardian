import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { GuardianRiderRelationship } from './entities/guardian-rider-relationship.entity.js';
import { UsersService } from '../users/users.service.js';

@Injectable()
export class GuardianRelationshipsService {
  constructor(
    @InjectRepository(GuardianRiderRelationship)
    private readonly relationshipRepository: Repository<GuardianRiderRelationship>,

    private readonly usersService: UsersService,
  ) {}

  /**
   * Creates a guardian-rider relationship after an invitation
   * has been accepted.
   *
   * This method is intended to be called internally by
   * InvitationsService.acceptInvitation().
   */
  async createRelationship(
    guardianId: string,
    riderId: string,
  ): Promise<GuardianRiderRelationship> {
    if (guardianId === riderId) {
      throw new BadRequestException(
        'A user cannot be their own rider',
      );
    }

    const rider = await this.usersService.getUserById(riderId);

    if (!rider) {
      throw new NotFoundException('Rider not found');
    }

    const existing =
      await this.relationshipRepository.findOne({
        where: {
          guardianId,
          riderId,
        },
      });

    if (existing) {
      throw new ConflictException(
        'Guardian-rider relationship already exists',
      );
    }

    const relationship =
      this.relationshipRepository.create({
        guardianId,
        riderId,
        status: 'ACCEPTED',
        acceptedAt: new Date(),
      });

    return this.relationshipRepository.save(relationship);
  }

  /**
   * Returns all guardian-rider relationships where
   * the current user is either the guardian or the rider.
   */
  async getRelationships(
    userId: string,
  ): Promise<GuardianRiderRelationship[]> {
    return this.relationshipRepository
      .createQueryBuilder('relationship')
      .where(
        'relationship.guardian_id = :userId',
        { userId },
      )
      .orWhere(
        'relationship.rider_id = :userId',
        { userId },
      )
      .orderBy(
        'relationship.created_at',
        'DESC',
      )
      .getMany();
  }

  /**
   * Revokes an existing accepted guardian-rider relationship.
   *
   * Either the guardian or the rider can revoke the relationship.
   */
  async revokeRelationship(
    relationshipId: string,
    userId: string,
  ): Promise<GuardianRiderRelationship> {
    const relationship =
      await this.getRelationshipOrThrow(relationshipId);

    if (
      relationship.guardianId !== userId &&
      relationship.riderId !== userId
    ) {
      throw new ForbiddenException(
        'You are not part of this guardian-rider relationship',
      );
    }

    if (relationship.status !== 'ACCEPTED') {
      throw new BadRequestException(
        `Only an accepted relationship can be revoked. Current status: ${relationship.status}`,
      );
    }

    relationship.status = 'REVOKED';
    relationship.revokedAt = new Date();

    return this.relationshipRepository.save(
      relationship,
    );
  }

  private async getRelationshipOrThrow(
    relationshipId: string,
  ): Promise<GuardianRiderRelationship> {
    const relationship =
      await this.relationshipRepository.findOne({
        where: {
          id: relationshipId,
        },
      });

    if (!relationship) {
      throw new NotFoundException(
        'Guardian-rider relationship not found',
      );
    }

    return relationship;
  }
}