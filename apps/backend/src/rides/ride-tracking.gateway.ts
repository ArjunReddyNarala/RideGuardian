import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';

import { HttpAdapterHost } from '@nestjs/core';

import { WebSocketServer, WebSocket } from 'ws';

import { URL } from 'node:url';

import { AuthService } from '../auth/auth.service.js';
import { UsersService } from '../users/users.service.js';

import { InjectRepository } from '@nestjs/typeorm';

import { IsNull, Repository } from 'typeorm';

import { Ride } from './entities/ride.entity.js';
import { RideGuardian } from '../ride-guardians/entities/ride-guardian.entity.js';

import { RideLocationDto } from './dto/ride-location.dto.js';

import { RideTrackingService } from './ride-tracking.service.js';

interface ConnectedClient {
  socket: WebSocket;
  userId: string;
  rideId: string;
  role: 'RIDER' | 'GUARDIAN';
  locationProcessing: Promise<void>;
}

@Injectable()
export class RideTrackingGateway implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RideTrackingGateway.name);

  private server: WebSocketServer;

  private readonly clients = new Set<ConnectedClient>();

  constructor(
    private readonly httpAdapterHost: HttpAdapterHost,

    private readonly authService: AuthService,

    private readonly usersService: UsersService,

    private readonly rideTrackingService: RideTrackingService,

    @InjectRepository(Ride)
    private readonly rideRepository: Repository<Ride>,

    @InjectRepository(RideGuardian)
    private readonly rideGuardianRepository: Repository<RideGuardian>,
  ) {}

  onModuleInit() {
    const httpServer = this.httpAdapterHost.httpAdapter.getHttpServer();

    this.server = new WebSocketServer({
      server: httpServer,
      path: '/ws/rides',
    });

    this.server.on('connection', (socket, request) => {
      void this.handleConnection(socket, request);
    });

    this.logger.log('Ride WebSocket server initialized');
  }

  async onModuleDestroy() {
    for (const client of this.clients) {
      client.socket.close();
    }

    this.server?.close();
  }

  private async handleConnection(
    socket: WebSocket,
    request: import('node:http').IncomingMessage,
  ) {
    try {
      const requestUrl = new URL(request.url ?? '/', 'http://localhost');

      const token = requestUrl.searchParams.get('token');

      const rideId = requestUrl.searchParams.get('rideId');

      if (!token || !rideId) {
        socket.close(1008, 'Missing authentication or ride ID');
        return;
      }

      const decodedToken = await this.authService.verifyIdToken(token);

      const user = await this.usersService.getUserByFirebaseUid(
        decodedToken.uid,
      );

      if (!user || !user.isActive) {
        socket.close(1008, 'User is not active');
        return;
      }

      const ride = await this.rideRepository.findOne({
        where: {
          id: rideId,
          status: 'ACTIVE',
        },
      });

      if (!ride) {
        socket.close(1008, 'Active ride not found');
        return;
      }

      let role: 'RIDER' | 'GUARDIAN';

      if (ride.riderId === user.id) {
        role = 'RIDER';
      } else {
        const assignment = await this.rideGuardianRepository.findOne({
          where: {
            rideId,
            guardianId: user.id,
            removedAt: IsNull(),
          },
        });

        if (!assignment) {
          socket.close(1008, 'Not authorized for this ride');
          return;
        }

        role = 'GUARDIAN';
      }

      const client: ConnectedClient = {
        socket,
        userId: user.id,
        rideId,
        role,
        locationProcessing: Promise.resolve(),
      };

      this.clients.add(client);

      this.send(socket, {
        type: 'CONNECTED',
        data: {
          rideId,
          role,
        },
      });

      this.logger.log(`User connected to ride ${rideId} as ${role}`);

      socket.on('message', (rawMessage) => {
        void this.handleMessage(client, rawMessage.toString());
      });

      socket.on('close', () => {
        this.clients.delete(client);
      });

      socket.on('error', (error) => {
        this.logger.error(`WebSocket error: ${error.message}`);

        this.clients.delete(client);
      });
    } catch (error) {
      this.logger.error(
        `WebSocket authentication failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );

      socket.close(1008, 'Authentication failed');
    }
  }

  private handleMessage(client: ConnectedClient, rawMessage: string) {
    try {
      const message = JSON.parse(rawMessage);

      if (message.type === 'PING') {
        this.send(client.socket, {
          type: 'PONG',
        });

        return;
      }

      if (message.type !== 'LOCATION_UPDATE') {
        this.sendError(client.socket, 'Unsupported event type');

        return;
      }

      if (client.role !== 'RIDER') {
        this.sendError(
          client.socket,
          'Only the rider can publish location updates',
        );

        return;
      }

      const dto = this.validateLocation(message.data);

      // Deliver the GPS fix to rider and guardians immediately. Database writes
      // and speed-alert work can take much longer than the websocket hop.
      this.broadcast(client.rideId, {
        type: 'LOCATION_UPDATE',
        data: {
          rideId: client.rideId,
          latitude: dto.latitude,
          longitude: dto.longitude,
          speedKmh: dto.speedKmh ?? null,
          speedAccuracyKmh: dto.speedAccuracyKmh ?? null,
          accuracyMeters: dto.accuracyMeters ?? null,
          headingDegrees: dto.headingDegrees ?? null,
          recordedAt: dto.recordedAt ?? new Date().toISOString(),
        },
      });

      this.send(client.socket, {
        type: 'LOCATION_RECEIVED',
        data: {
          rideId: client.rideId,
        },
      });

      // Preserve fix order in storage while keeping the websocket delivery
      // path independent from database and notification latency.
      client.locationProcessing = client.locationProcessing
        .then(async () => {
          const result = await this.rideTrackingService.processLocation(
            client.userId,
            client.rideId,
            dto,
          );

          for (const alert of result.alerts) {
            this.broadcast(client.rideId, {
              type: 'SPEED_LIMIT_EXCEEDED',
              data: alert,
            });
          }
        })
        .catch((error: unknown) => {
          this.logger.error(
            `Location persistence failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
          );
        });
    } catch (error) {
      this.logger.error(
        `Location processing failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
      );

      this.sendError(
        client.socket,
        error instanceof Error ? error.message : 'Unable to process location',
      );
    }
  }

  private validateLocation(data: unknown): RideLocationDto {
    if (!data || typeof data !== 'object') {
      throw new Error('Invalid location data');
    }

    const value = data as Record<string, unknown>;

    const latitude = Number(value.latitude);
    const longitude = Number(value.longitude);
    const speedKmh = value.speedKmh == null ? null : Number(value.speedKmh);

    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
      throw new Error('Invalid latitude');
    }

    if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
      throw new Error('Invalid longitude');
    }

    if (
      speedKmh !== null &&
      (!Number.isFinite(speedKmh) || speedKmh < 0 || speedKmh > 350)
    ) {
      throw new Error('Invalid speed');
    }

    const accuracyMeters =
      value.accuracyMeters == null ? undefined : Number(value.accuracyMeters);

    const headingDegrees =
      value.headingDegrees == null ? undefined : Number(value.headingDegrees);

    const speedAccuracyKmh =
      value.speedAccuracyKmh == null
        ? undefined
        : Number(value.speedAccuracyKmh);

    const recordedAt =
      value.recordedAt == null ? undefined : String(value.recordedAt);

    if (
      speedAccuracyKmh !== undefined &&
      (!Number.isFinite(speedAccuracyKmh) ||
        speedAccuracyKmh < 0 ||
        speedAccuracyKmh > 350)
    ) {
      throw new Error('Invalid speed accuracy');
    }

    if (recordedAt !== undefined && !Number.isFinite(Date.parse(recordedAt))) {
      throw new Error('Invalid location timestamp');
    }

    if (
      accuracyMeters !== undefined &&
      (!Number.isFinite(accuracyMeters) || accuracyMeters < 0)
    ) {
      throw new Error('Invalid location accuracy');
    }

    if (
      headingDegrees !== undefined &&
      (!Number.isFinite(headingDegrees) ||
        headingDegrees < 0 ||
        headingDegrees > 360)
    ) {
      throw new Error('Invalid heading');
    }

    return {
      latitude,
      longitude,
      speedKmh,
      speedAccuracyKmh,
      accuracyMeters,
      headingDegrees,
      recordedAt,
    };
  }

  broadcast(rideId: string, message: object) {
    for (const client of this.clients) {
      if (
        client.rideId === rideId &&
        client.socket.readyState === WebSocket.OPEN
      ) {
        this.send(client.socket, message);
      }
    }
  }

  broadcastRideEnded(rideId: string) {
    this.broadcast(rideId, {
      type: 'RIDE_ENDED',
      data: {
        rideId,
      },
    });
  }

  private send(socket: WebSocket, message: object) {
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify(message));
    }
  }

  private sendError(socket: WebSocket, message: string) {
    this.send(socket, {
      type: 'ERROR',
      message,
    });
  }
}
