import {
  Controller,
  Get,
  NotFoundException,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiTags,
} from '@nestjs/swagger';
import type { DecodedIdToken } from 'firebase-admin/auth';

import { CurrentUser } from '../auth/decorators/current-user.decorator.js';
import { FirebaseAuthGuard } from '../auth/guards/firebase-auth.guard.js';
import { UsersService } from '../users/users.service.js';

import { RidesService } from './rides.service.js';

@ApiTags('Rides')
@ApiBearerAuth()
@Controller('api/v1/rides')
@UseGuards(FirebaseAuthGuard)
export class RidesController {
  constructor(
    private readonly ridesService: RidesService,
    private readonly usersService: UsersService,
  ) {}

  @Post()
  async createRide(
    @CurrentUser() firebaseUser: DecodedIdToken,
  ) {
    const rider = await this.getBackendUser(
      firebaseUser.uid,
    );

    return this.ridesService.createRide(
      rider.id,
    );
  }

  @Get()
  async getRides(
    @CurrentUser() firebaseUser: DecodedIdToken,
  ) {
    const rider = await this.getBackendUser(
      firebaseUser.uid,
    );

    return this.ridesService.getRides(
      rider.id,
    );
  }

  @Get('active')
  async getActiveRide(
    @CurrentUser() firebaseUser: DecodedIdToken,
  ) {
    const rider = await this.getBackendUser(
      firebaseUser.uid,
    );

    return this.ridesService.getActiveRide(
      rider.id,
    );
  }

  @Get(':rideId/summary')
  async getRideSummary(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('rideId') rideId: string,
  ) {
    const rider = await this.getBackendUser(
      firebaseUser.uid,
    );

    return this.ridesService.getRideSummary(
      rider.id,
      rideId,
    );
  }

  @Get(':rideId/locations')
  async getRideLocations(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('rideId') rideId: string,
  ) {
    const rider = await this.getBackendUser(
      firebaseUser.uid,
    );

    return this.ridesService.getRideLocations(
      rider.id,
      rideId,
    );
  }

  @Get(':rideId/current-location')
  async getCurrentLocation(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('rideId') rideId: string,
  ) {
    const rider = await this.getBackendUser(
      firebaseUser.uid,
    );

    return this.ridesService.getCurrentLocation(
      rider.id,
      rideId,
    );
  }

  @Get(':rideId')
  async getRide(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('rideId') rideId: string,
  ) {
    const rider = await this.getBackendUser(
      firebaseUser.uid,
    );

    return this.ridesService.getRide(
      rider.id,
      rideId,
    );
  }

  @Post(':rideId/end')
  async endRide(
    @CurrentUser() firebaseUser: DecodedIdToken,
    @Param('rideId') rideId: string,
  ) {
    const rider = await this.getBackendUser(
      firebaseUser.uid,
    );

    return this.ridesService.endRide(
      rider.id,
      rideId,
    );
  }

  private async getBackendUser(
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