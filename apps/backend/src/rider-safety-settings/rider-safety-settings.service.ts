import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';
import { UsersService } from '../users/users.service.js';

import { UpdateRiderSafetySettingsDto } from './dto/update-rider-safety-settings.dto.js';
import { RiderSafetySettings } from './entities/rider-safety-settings.entity.js';

@Injectable()
export class RiderSafetySettingsService {
  constructor(
    @InjectRepository(RiderSafetySettings)
    private readonly safetySettingsRepository: Repository<RiderSafetySettings>,

    @InjectRepository(GuardianRiderRelationship)
    private readonly relationshipRepository: Repository<GuardianRiderRelationship>,

    private readonly usersService: UsersService,
  ) {}

  async getSettings(userId: string): Promise<RiderSafetySettings[]> {
    // A user can view settings they configured for riders and settings
    // configured by their guardians for them. Restrict both directions to
    // accepted relationships so revoked connections cannot expose old values.
    const relationships = await this.relationshipRepository.find({
      where: [
        { guardianId: userId, status: 'ACCEPTED' },
        { riderId: userId, status: 'ACCEPTED' },
      ],
      select: {
        guardianId: true,
        riderId: true,
      },
    });

    if (relationships.length === 0) return [];

    return this.safetySettingsRepository.find({
      where: relationships.map(({ guardianId, riderId }) => ({
        guardianId,
        riderId,
      })),
      order: {
        createdAt: 'ASC',
      },
    });
  }

  async updateSettings(
    guardianId: string,
    riderId: string,
    dto: UpdateRiderSafetySettingsDto,
  ): Promise<RiderSafetySettings> {
    await this.validateGuardianRiderRelationship(guardianId, riderId);

    const rider = await this.usersService.getUserById(riderId);

    if (!rider) {
      throw new NotFoundException('Rider not found');
    }

    let settings = await this.safetySettingsRepository.findOne({
      where: {
        guardianId,
        riderId,
      },
    });

    if (!settings) {
      settings = this.safetySettingsRepository.create({
        guardianId,
        riderId,
        maxSpeedKmh: dto.maxSpeedKmh ?? null,
        speedAlertEnabled: dto.speedAlertEnabled ?? true,
        speedAlertCooldownSeconds: dto.speedAlertCooldownSeconds ?? 60,
      });
    } else {
      if (dto.maxSpeedKmh !== undefined) {
        settings.maxSpeedKmh = dto.maxSpeedKmh;
      }

      if (dto.speedAlertEnabled !== undefined) {
        settings.speedAlertEnabled = dto.speedAlertEnabled;
      }

      if (dto.speedAlertCooldownSeconds !== undefined) {
        settings.speedAlertCooldownSeconds = dto.speedAlertCooldownSeconds;
      }
    }

    return this.safetySettingsRepository.save(settings);
  }

  private async validateGuardianRiderRelationship(
    guardianId: string,
    riderId: string,
  ): Promise<void> {
    const relationship = await this.relationshipRepository.findOne({
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
