import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';
import { UsersService } from '../users/users.service.js';

@Injectable()
export class GuardiansService {
  constructor(
    @InjectRepository(GuardianRiderRelationship)
    private readonly relationshipRepository: Repository<GuardianRiderRelationship>,

    private readonly usersService: UsersService,
  ) {}

  async getGuardians(userId: string) {
    const relationships =
      await this.relationshipRepository.find({
        where: {
          riderId: userId,
          status: 'ACCEPTED',
        },
        order: {
          createdAt: 'DESC',
        },
      });

    const guardians = await Promise.all(
      relationships.map(async (relationship) => {
        const guardian = await this.usersService.getUserById(
          relationship.guardianId,
        );

        return guardian
          ? {
              id: guardian.id,
              name: guardian.name,
              email: guardian.email,
              phone: guardian.phone,
              profileImageUrl: guardian.profileImageUrl,
              relationshipId: relationship.id,
              acceptedAt: relationship.acceptedAt,
            }
          : null;
      }),
    );

    return guardians.filter(
      (guardian) => guardian !== null,
    );
  }

  async removeGuardian(
    userId: string,
    relationshipId: string,
  ) {
    const relationship =
      await this.relationshipRepository.findOne({
        where: {
          id: relationshipId,
          riderId: userId,
        },
      });

    if (!relationship) {
      throw new NotFoundException(
        'Guardian relationship not found',
      );
    }

    if (relationship.status !== 'ACCEPTED') {
      throw new ForbiddenException(
        'Only an accepted guardian relationship can be removed',
      );
    }

    relationship.status = 'REVOKED';
    relationship.revokedAt = new Date();

    return this.relationshipRepository.save(
      relationship,
    );
  }
}