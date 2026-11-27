import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('devices')
@Check(`"platform" IN ('IOS', 'ANDROID')`)
export class Device {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid' })
  userId: string;

  @Column({
    name: 'device_identifier',
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  deviceIdentifier: string | null;

  @Column({ length: 20 })
  platform: string;

  @Column({
    name: 'push_token',
    type: 'text',
    nullable: true,
  })
  pushToken: string | null;

  @Column({
    name: 'app_version',
    type: 'varchar',
    length: 30,
    nullable: true,
  })
  appVersion: string | null;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({
    name: 'last_seen_at',
    type: 'timestamptz',
    nullable: true,
  })
  lastSeenAt: Date | null;

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