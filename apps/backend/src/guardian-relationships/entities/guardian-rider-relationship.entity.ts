import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('guardian_rider_relationships')
@Index(['guardianId', 'riderId'], { unique: true })
@Check(`"guardian_id" <> "rider_id"`)
@Check(`"status" IN ('PENDING', 'ACCEPTED', 'DECLINED', 'REVOKED')`)
export class GuardianRiderRelationship {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'guardian_id', type: 'uuid' })
  guardianId: string;

  @Column({ name: 'rider_id', type: 'uuid' })
  riderId: string;

  @Column({ length: 20, default: 'PENDING' })
  status: string;

  @CreateDateColumn({ name: 'invited_at', type: 'timestamptz' })
  invitedAt: Date;

  @Column({ name: 'accepted_at', type: 'timestamptz', nullable: true })
  acceptedAt: Date | null;

  @Column({ name: 'revoked_at', type: 'timestamptz', nullable: true })
  revokedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}