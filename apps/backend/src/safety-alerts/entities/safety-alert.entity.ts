import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity('safety_alerts')
@Check(
  `"type" IN ('SPEED_LIMIT_EXCEEDED', 'SOS', 'CRASH_DETECTED', 'ROUTE_DEVIATION', 'PROLONGED_STOP')`,
)
@Check(`"severity" IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')`)
@Check(`"status" IN ('ACTIVE', 'ACKNOWLEDGED', 'RESOLVED')`)
export class SafetyAlert {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'ride_id', type: 'uuid' })
  rideId: string;

  @Column({ name: 'rider_id', type: 'uuid' })
  riderId: string;

  @Column({ name: 'guardian_id', type: 'uuid', nullable: true })
  guardianId: string | null;

  @Column({ length: 30 })
  type: string;

  @Column({ length: 20, default: 'HIGH' })
  severity: string;

  @Column({
    name: 'current_speed_kmh',
    type: 'double precision',
    nullable: true,
  })
  currentSpeedKmh: number | null;

  @Column({
    name: 'configured_speed_limit_kmh',
    type: 'double precision',
    nullable: true,
  })
  configuredSpeedLimitKmh: number | null;

  @Column({ type: 'double precision', nullable: true })
  latitude: number | null;

  @Column({ type: 'double precision', nullable: true })
  longitude: number | null;

  @CreateDateColumn({
    name: 'triggered_at',
    type: 'timestamptz',
  })
  triggeredAt: Date;

  @Column({ length: 20, default: 'ACTIVE' })
  status: string;

  @Column({
    name: 'acknowledged_at',
    type: 'timestamptz',
    nullable: true,
  })
  acknowledgedAt: Date | null;

  @Column({
    name: 'resolved_at',
    type: 'timestamptz',
    nullable: true,
  })
  resolvedAt: Date | null;
}