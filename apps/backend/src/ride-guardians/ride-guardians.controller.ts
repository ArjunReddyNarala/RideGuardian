import {
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';

import {
  ApiBearerAuth,
  ApiOperation,
  ApiParam,
  ApiTags,
} from '@nestjs/swagger';

import type { DecodedIdToken } from 'firebase-admin/auth';

import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { UsersService } from '../users/users.service.js';

import { AddRideGuardianDto } from './dto/add-ride-guardian.dto.js';
import { RideGuardiansService } from './ride-guardians.service.js';

@ApiTags('Ride Guardians')
@ApiBearerAuth()
@Controller('api/v1/rides/:rideId/guardians')
@UseGuards(FirebaseAuthGuard)
export class RideGuardiansController {
  constructor(
    private readonly rideGuardiansService: RideGuardiansService,
    private readonly usersService: UsersService,
  ) {}

  @Post()
  @ApiOperation({
    summary: 'Add a guardian to a ride',
  })
  @ApiParam({
    name: 'rideId',
    description: 'ID of the ride',
  })
  async addGuardian(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('rideId') rideId: string,
    @Body() dto: AddRideGuardianDto,
  ) {
    const rider = await this.getCurrentDatabaseUser(
      firebaseUser.uid,
    );

    return this.rideGuardiansService.addGuardian(
      rider.id,
      rideId,
      dto,
    );
  }

  @Get()
  @ApiOperation({
    summary: 'Get guardians assigned to a ride',
  })
  @ApiParam({
    name: 'rideId',
    description: 'ID of the ride',
  })
  async getGuardians(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('rideId') rideId: string,
  ) {
    const rider = await this.getCurrentDatabaseUser(
      firebaseUser.uid,
    );

    return this.rideGuardiansService.getGuardians(
      rider.id,
      rideId,
    );
  }

  @Delete(':guardianId')
  @ApiOperation({
    summary: 'Remove a guardian from a ride',
  })
  @ApiParam({
    name: 'rideId',
    description: 'ID of the ride',
  })
  @ApiParam({
    name: 'guardianId',
    description: 'ID of the guardian to remove',
  })
  async removeGuardian(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('rideId') rideId: string,
    @Param('guardianId') guardianId: string,
  ) {
    const rider = await this.getCurrentDatabaseUser(
      firebaseUser.uid,
    );

    return this.rideGuardiansService.removeGuardian(
      rider.id,
      rideId,
      guardianId,
    );
  }

  private async getCurrentDatabaseUser(
    firebaseUid: string,
  ) {
    const user =
      await this.usersService.getUserByFirebaseUid(
        firebaseUid,
      );

    if (!user || !user.isActive) {
      throw new NotFoundException(
        'Authenticated user not found',
      );
    }

    return user;
  }
}