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

  async createRelationship(
    guardianId: string,
    riderEmail: string,
  ): Promise<GuardianRiderRelationship> {
    const rider = await this.usersService.getUserByEmail(riderEmail);

    if (!rider) {
      throw new NotFoundException('Rider not found');
    }

    if (guardianId === rider.id) {
      throw new BadRequestException('A user cannot be their own rider');
    }

    const existing = await this.relationshipRepository.findOne({
      where: {
        guardianId,
        riderId: rider.id,
      },
    });

    if (existing) {
      throw new ConflictException('Guardian-rider relationship already exists');
    }

    const relationship = this.relationshipRepository.create({
      guardianId,
      riderId: rider.id,
      status: 'PENDING',
    });

    return this.relationshipRepository.save(relationship);
  }

  async getRelationships(userId: string): Promise<GuardianRiderRelationship[]> {
    return this.relationshipRepository
      .createQueryBuilder('relationship')
      .where('relationship.guardian_id = :userId', { userId })
      .orWhere('relationship.rider_id = :userId', { userId })
      .orderBy('relationship.created_at', 'DESC')
      .getMany();
  }

  async acceptRelationship(
    relationshipId: string,
    riderId: string,
  ): Promise<GuardianRiderRelationship> {
    const relationship = await this.getRelationshipOrThrow(relationshipId);

    if (relationship.riderId !== riderId) {
      throw new ForbiddenException(
        'Only the rider can accept this relationship',
      );
    }

    if (relationship.status !== 'PENDING') {
      throw new BadRequestException(
        `Cannot accept a relationship with status ${relationship.status}`,
      );
    }

    relationship.status = 'ACCEPTED';
    relationship.acceptedAt = new Date();

    return this.relationshipRepository.save(relationship);
  }

  async declineRelationship(
    relationshipId: string,
    riderId: string,
  ): Promise<GuardianRiderRelationship> {
    const relationship = await this.getRelationshipOrThrow(relationshipId);

    if (relationship.riderId !== riderId) {
      throw new ForbiddenException(
        'Only the rider can decline this relationship',
      );
    }

    if (relationship.status !== 'PENDING') {
      throw new BadRequestException(
        `Cannot decline a relationship with status ${relationship.status}`,
      );
    }

    relationship.status = 'DECLINED';

    return this.relationshipRepository.save(relationship);
  }

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
      where: {
        id: relationshipId,
      },
    });

    if (!relationship) {
      throw new NotFoundException('Guardian-rider relationship not found');
    }

    return relationship;
  }
}
