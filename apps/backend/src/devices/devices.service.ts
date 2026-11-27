import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { Device } from './entities/device.entity.js';
import { UsersService } from '../users/users.service.js';
import { RegisterDeviceDto } from './dto/register-device.dto.js';
import { UpdateDeviceDto } from './dto/update-device.dto.js';

type DeviceResponse = Omit<Device, 'pushToken'>;

@Injectable()
export class DevicesService {
  constructor(
    @InjectRepository(Device)
    private readonly deviceRepository: Repository<Device>,
    private readonly usersService: UsersService,
  ) {}

  private async getBackendUser(firebaseUid: string) {
    const user =
      await this.usersService.getUserByFirebaseUid(firebaseUid);

    if (!user) {
      throw new NotFoundException(
        'User not found. Please register your account first.',
      );
    }

    return user;
  }

  private toResponse(device: Device): DeviceResponse {
    const { pushToken: _pushToken, ...response } = device;
    return response;
  }

  /**
   * POST /api/devices
   *
   * Register a new device or update an existing registration.
   */
  async registerDevice(
    firebaseUid: string,
    dto: RegisterDeviceDto,
  ): Promise<DeviceResponse> {
    const user = await this.getBackendUser(firebaseUid);

    const deviceIdentifier =
      dto.deviceIdentifier?.trim() || null;

    let device: Device | null = null;

    if (deviceIdentifier) {
      device = await this.deviceRepository.findOne({
        where: {
          userId: user.id,
          deviceIdentifier,
        },
      });
    }

    if (device) {
      device.platform = dto.platform;
      device.pushToken = dto.pushToken ?? null;
      device.appVersion = dto.appVersion ?? null;
      device.isActive = true;
      device.lastSeenAt = new Date();
    } else {
      device = this.deviceRepository.create({
        userId: user.id,
        deviceIdentifier,
        platform: dto.platform,
        pushToken: dto.pushToken ?? null,
        appVersion: dto.appVersion ?? null,
        isActive: true,
        lastSeenAt: new Date(),
      });
    }

    const savedDevice =
      await this.deviceRepository.save(device);

    return this.toResponse(savedDevice);
  }

  /**
   * GET /api/devices
   *
   * Return devices belonging to the authenticated user.
   */
  async listDevices(
    firebaseUid: string,
  ): Promise<DeviceResponse[]> {
    const user = await this.getBackendUser(firebaseUid);

    const devices = await this.deviceRepository.find({
      where: {
        userId: user.id,
      },
      order: {
        createdAt: 'DESC',
      },
    });

    return devices.map((device) =>
      this.toResponse(device),
    );
  }

  /**
   * PATCH /api/devices/:id
   *
   * Update a device owned by the authenticated user.
   */
  async updateDevice(
    firebaseUid: string,
    deviceId: string,
    dto: UpdateDeviceDto,
  ): Promise<DeviceResponse> {
    const user = await this.getBackendUser(firebaseUid);

    const device = await this.deviceRepository.findOne({
      where: {
        id: deviceId,
        userId: user.id,
      },
    });

    if (!device) {
      throw new NotFoundException(
        'Device not found.',
      );
    }

    if (dto.pushToken !== undefined) {
      device.pushToken = dto.pushToken;
    }

    if (dto.appVersion !== undefined) {
      device.appVersion = dto.appVersion;
    }

    if (dto.isActive !== undefined) {
      device.isActive = dto.isActive;
    }

    device.lastSeenAt = new Date();

    const savedDevice =
      await this.deviceRepository.save(device);

    return this.toResponse(savedDevice);
  }

  /**
   * DELETE /api/devices/:id
   *
   * Deactivate a device without deleting its database record.
   */
  async deactivateDevice(
    firebaseUid: string,
    deviceId: string,
  ): Promise<DeviceResponse> {
    const user = await this.getBackendUser(firebaseUid);

    const device = await this.deviceRepository.findOne({
      where: {
        id: deviceId,
        userId: user.id,
      },
    });

    if (!device) {
      throw new NotFoundException(
        'Device not found.',
      );
    }

    device.isActive = false;
    device.pushToken = null;

    const savedDevice =
      await this.deviceRepository.save(device);

    return this.toResponse(savedDevice);
  }
}