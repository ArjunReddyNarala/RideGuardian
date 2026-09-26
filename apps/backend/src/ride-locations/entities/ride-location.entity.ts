import {
  Column,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity('ride_locations')
export class RideLocation {
  @PrimaryGeneratedColumn({ type: 'bigint' })
  id: string;

  @Column({ name: 'ride_id', type: 'uuid' })
  rideId: string;

  @Column({ type: 'double precision' })
  latitude: number;

  @Column({ type: 'double precision' })
  longitude: number;

  @Column({ name: 'speed_kmh', type: 'double precision', nullable: true })
  speedKmh: number | null;

  @Column({ type: 'double precision', nullable: true })
  heading: number | null;

  @Column({ type: 'double precision', nullable: true })
  accuracy: number | null;

  @Column({ type: 'double precision', nullable: true })
  altitude: number | null;

  @Column({ name: 'recorded_at', type: 'timestamptz' })
  recordedAt: Date;
}