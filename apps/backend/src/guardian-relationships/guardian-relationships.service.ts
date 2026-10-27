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
import { User } from '../users/entities/user.entity.js';

interface PublicUser {
  id: string;
  name: string;
  email: string | null;
  phone: string | null;
  profileImageUrl: string | null;
}

export interface RelationshipResponse {
  id: string;
  guardianId: string;
  riderId: string;
  status: string;
  invitedAt: Date;
  acceptedAt: Date | null;
  revokedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  guardian: PublicUser | null;
  rider: PublicUser | null;
}

@Injectable()
export class GuardianRelationshipsService {
  constructor(
    @InjectRepository(GuardianRiderRelationship)
    private readonly relationshipRepository: Repository<GuardianRiderRelationship>,
    private readonly usersService: UsersService,
  ) {}

  /**

* Creates a relationship or reactivates a previously revoked one.
* The original guardian/rider direction is preserved during reactivation.
    */
  async createRelationship(
    guardianId: string,
    riderId: string,
  ): Promise<GuardianRiderRelationship> {
    if (guardianId === riderId) {
      throw new BadRequestException(
        'A user cannot be their own guardian or rider',
      );
    }

    const [guardian, rider] = await Promise.all([
      this.usersService.getUserById(guardianId),
      this.usersService.getUserById(riderId),
    ]);
    if (!guardian || !guardian.isActive) {
      throw new NotFoundException('Active guardian not found');
    }
    if (!rider || !rider.isActive) {
      throw new NotFoundException('Active rider not found');
    }
    const existing = await this.relationshipRepository
      .createQueryBuilder('relationship')
      .where(
        `(
      relationship.guardian_id = :guardianId
      AND relationship.rider_id = :riderId
    ) OR (
      relationship.guardian_id = :riderId
      AND relationship.rider_id = :guardianId
    )`,
        { guardianId, riderId },
      )
      .getOne();
    if (existing) {
      if (existing.status !== 'REVOKED') {
        throw new ConflictException(
          'A guardian-rider relationship already exists between these users',
        );
      }
      existing.status = 'ACCEPTED';
      existing.acceptedAt = new Date();
      existing.revokedAt = null;
      try {
        return await this.relationshipRepository.save(existing);
      } catch (error: unknown) {
        this.handleDuplicateRelationshipError(error);
      }
    }
    const relationship = this.relationshipRepository.create({
      guardianId,
      riderId,
      status: 'ACCEPTED',
      acceptedAt: new Date(),
      revokedAt: null,
    });
    try {
      return await this.relationshipRepository.save(relationship);
    } catch (error: unknown) {
      this.handleDuplicateRelationshipError(error);
    }
  }

  /**
   * Returns all relationships involving the user.
   * The status is included so clients can distinguish ACCEPTED,
   * PENDING, DECLINED, and REVOKED relationships.
   */
  async getRelationships(userId: string): Promise<RelationshipResponse[]> {
    const relationships = await this.relationshipRepository
      .createQueryBuilder('relationship')
      .leftJoinAndSelect('relationship.guardian', 'guardian')
      .leftJoinAndSelect('relationship.rider', 'rider')
      .where('relationship.guardian_id = :userId', { userId })
      .orWhere('relationship.rider_id = :userId', { userId })
      .orderBy('relationship.created_at', 'DESC')
      .getMany();

    return relationships.map((relationship: GuardianRiderRelationship) => ({
      id: relationship.id,
      guardianId: relationship.guardianId,
      riderId: relationship.riderId,
      status: relationship.status,
      invitedAt: relationship.invitedAt,
      acceptedAt: relationship.acceptedAt,
      revokedAt: relationship.revokedAt,
      createdAt: relationship.createdAt,
      updatedAt: relationship.updatedAt,
      guardian: this.toPublicUser(relationship.guardian),
      rider: this.toPublicUser(relationship.rider),
    }));
  }

  /**

* Revokes an accepted relationship.
* Either participant may revoke it.
    */
  async revokeRelationship(
    relationshipId: string,
    userId: string,
  ): Promise<GuardianRiderRelationship> {
    const relationship = await this.getRelationshipOrThrow(relationshipId);

    if (relationship.guardianId !== userId && relationship.riderId !== userId) {
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
    return this.relationshipRepository.save(relationship);
  }

  private async getRelationshipOrThrow(
    relationshipId: string,
  ): Promise<GuardianRiderRelationship> {
    const relationship = await this.relationshipRepository.findOne({
      where: { id: relationshipId },
    });

    if (!relationship) {
      throw new NotFoundException('Guardian-rider relationship not found');
    }
    return relationship;
  }

  private toPublicUser(user: User | null | undefined): PublicUser | null {
    if (!user) {
      return null;
    }

    return {
      id: user.id,
      name: user.name,
      email: user.email ?? null,
      phone: user.phone ?? null,
      profileImageUrl: user.profileImageUrl ?? null,
    };
  }

  private handleDuplicateRelationshipError(error: unknown): never {
    if (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      (error as { code?: string }).code === '23505'
    ) {
      throw new ConflictException(
        'A guardian-rider relationship already exists between these users',
      );
    }

    throw error;
  }
}
