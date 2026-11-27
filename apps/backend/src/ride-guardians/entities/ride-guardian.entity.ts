import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
} from 'typeorm';

@Entity('ride_guardians')
@Index(['rideId', 'guardianId'], { unique: true })
export class RideGuardian {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'ride_id', type: 'uuid' })
  rideId: string;

  @Column({ name: 'guardian_id', type: 'uuid' })
  guardianId: string;

  @CreateDateColumn({ name: 'added_at', type: 'timestamptz' })
  addedAt: Date;

  @Column({ name: 'removed_at', type: 'timestamptz', nullable: true })
  removedAt: Date | null;
}