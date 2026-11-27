import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';

import {
  ApiBearerAuth,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';

import { DevicesService } from './devices.service.js';
import { RegisterDeviceDto } from './dto/register-device.dto.js';
import { UpdateDeviceDto } from './dto/update-device.dto.js';

import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { CurrentUser } from '../auth/decorators/current-user.decorator.js';

import type { DecodedIdToken } from 'firebase-admin/auth';

@ApiTags('Devices')
@ApiBearerAuth()
@UseGuards(FirebaseAuthGuard)
@Controller('api/devices')
export class DevicesController {
  constructor(
    private readonly devicesService: DevicesService,
  ) {}

  @Post()
  @ApiOperation({
    summary: 'Register or update a device',
  })
  async registerDevice(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Body() dto: RegisterDeviceDto,
  ) {
    return this.devicesService.registerDevice(
      firebaseUser.uid,
      dto,
    );
  }

  @Get()
  @ApiOperation({
    summary: 'Get the authenticated user devices',
  })
  async listDevices(
    @CurrentUser() firebaseUser: DecodedIdToken,
  ) {
    return this.devicesService.listDevices(
      firebaseUser.uid,
    );
  }

  @Patch(':id')
  @ApiOperation({
    summary: 'Update a device registration',
  })
  async updateDevice(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('id') deviceId: string,
    @Body() dto: UpdateDeviceDto,
  ) {
    return this.devicesService.updateDevice(
      firebaseUser.uid,
      deviceId,
      dto,
    );
  }

  @Delete(':id')
  @ApiOperation({
    summary: 'Deactivate a device registration',
  })
  async deactivateDevice(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('id') deviceId: string,
  ) {
    return this.devicesService.deactivateDevice(
      firebaseUser.uid,
      deviceId,
    );
  }
}