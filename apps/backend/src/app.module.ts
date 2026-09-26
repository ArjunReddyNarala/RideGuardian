import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { UsersModule } from './users/users.module.js';
import { GuardianRelationshipsModule } from './guardian-relationships/guardian-relationships.module.js';
import { RiderSafetySettingsModule } from './safety-settings/safety-settings.module.js';
import { InvitationsModule } from './invitations/invitations.module.js';
import { RidesModule } from './rides/rides.module.js';
import { RideGuardiansModule } from './ride-guardians/ride-guardians.module.js';
import { RideLocationsModule } from './ride-locations/ride-locations.module.js';
import { RideEventsModule } from './ride-events/ride-events.module.js';
import { SafetyAlertsModule } from './safety-alerts/safety-alerts.module.js';
import { NotificationsModule } from './notifications/notifications.module.js';
import { DevicesModule } from './devices/devices.module.js';
import { AuthModule } from './auth/auth.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: process.env.DATABASE_HOST,
      port: Number(process.env.DATABASE_PORT),
      username: process.env.DATABASE_USER,
      password: process.env.DATABASE_PASSWORD,
      database: process.env.DATABASE_NAME,
      autoLoadEntities: true,
      synchronize: false,
    }),
    UsersModule,
    GuardianRelationshipsModule,
    RiderSafetySettingsModule,
    InvitationsModule,
    RidesModule,
    RideGuardiansModule,
    RideLocationsModule,
    RideEventsModule,
    SafetyAlertsModule,
    NotificationsModule,
    DevicesModule,
    AuthModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}