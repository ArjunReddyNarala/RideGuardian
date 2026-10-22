import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('user_settings')
@Index(['userId'], { unique: true })
export class UserSetting {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({
    name: 'user_id',
    type: 'uuid',
  })
  userId: string;

  @Column({
    name: 'notifications_enabled',
    type: 'boolean',
    default: true,
  })
  notificationsEnabled: boolean;

  @Column({
    name: 'push_notifications_enabled',
    type: 'boolean',
    default: true,
  })
  pushNotificationsEnabled: boolean;

  @Column({
    name: 'ride_updates_enabled',
    type: 'boolean',
    default: true,
  })
  rideUpdatesEnabled: boolean;

  @Column({
    name: 'speed_alerts_enabled',
    type: 'boolean',
    default: true,
  })
  speedAlertsEnabled: boolean;

  @Column({
    name: 'sound_enabled',
    type: 'boolean',
    default: true,
  })
  soundEnabled: boolean;

  @Column({
    type: 'varchar',
    length: 10,
    default: 'en',
  })
  language: string;

  @Column({
    name: 'distance_unit',
    type: 'varchar',
    length: 5,
    default: 'KM',
  })
  distanceUnit: string;

  @CreateDateColumn({
    name: 'created_at',
    type: 'timestamptz',
  })
  createdAt: Date;

  @UpdateDateColumn({
    name: 'updated_at',
    type: 'timestamptz',
  })
  updatedAt: Date;
}