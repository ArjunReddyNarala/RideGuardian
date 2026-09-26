import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('rider_safety_settings')
@Index(['guardianId', 'riderId'], { unique: true })
@Check(`"max_speed_kmh" IS NULL OR "max_speed_kmh" > 0`)
@Check(`"speed_alert_cooldown_seconds" >= 0`)
export class RiderSafetySetting {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'guardian_id', type: 'uuid' })
  guardianId: string;

  @Column({ name: 'rider_id', type: 'uuid' })
  riderId: string;

  @Column({
    name: 'max_speed_kmh',
    type: 'numeric',
    precision: 5,
    scale: 2,
    nullable: true,
  })
  maxSpeedKmh: number | null;

  @Column({ name: 'speed_alert_enabled', default: true })
  speedAlertEnabled: boolean;

  @Column({
    name: 'speed_alert_cooldown_seconds',
    type: 'integer',
    default: 60,
  })
  speedAlertCooldownSeconds: number;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}