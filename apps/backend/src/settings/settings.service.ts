import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { UserSetting } from './entities/user-setting.entity.js';
import { UpdateSettingsDto } from './dto/update-settings.dto.js';
import { UsersService } from '../users/users.service.js';

@Injectable()
export class SettingsService {
  constructor(
    @InjectRepository(UserSetting)
    private readonly settingsRepository: Repository<UserSetting>,

    private readonly usersService: UsersService,
  ) {}

  private async getBackendUser(firebaseUid: string) {
    const user =
      await this.usersService.getUserByFirebaseUid(firebaseUid);

    if (!user) {
      throw new NotFoundException(
        'User not found. Please register first.',
      );
    }

    return user;
  }

  /**
   * GET /api/settings
   *
   * Return the authenticated user's settings.
   * Create a default settings record if one does not exist.
   */
  async getSettings(firebaseUid: string): Promise<UserSetting> {
    const user = await this.getBackendUser(firebaseUid);

    let settings = await this.settingsRepository.findOne({
      where: {
        userId: user.id,
      },
    });

    if (!settings) {
      settings = this.settingsRepository.create({
        userId: user.id,
      });

      settings = await this.settingsRepository.save(settings);
    }

    return settings;
  }

  /**
   * PATCH /api/settings
   *
   * Update only the settings supplied by the user.
   */
  async updateSettings(
    firebaseUid: string,
    dto: UpdateSettingsDto,
  ): Promise<UserSetting> {
    const user = await this.getBackendUser(firebaseUid);

    let settings = await this.settingsRepository.findOne({
      where: {
        userId: user.id,
      },
    });

    if (!settings) {
      settings = this.settingsRepository.create({
        userId: user.id,
      });
    }

    Object.assign(settings, dto);

    return this.settingsRepository.save(settings);
  }
}