import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

import { User } from '../../users/entities/user.entity.js';

@Entity('guardian_rider_relationships')
@Index(['guardianId', 'riderId'], { unique: true })
@Check(`"guardian_id" <> "rider_id"`)
@Check(`"status" IN ('PENDING', 'ACCEPTED', 'DECLINED', 'REVOKED')`)
export class GuardianRiderRelationship {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'guardian_id', type: 'uuid' })
  guardianId: string;

  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: 'guardian_id' })
  guardian: User;

  @Column({ name: 'rider_id', type: 'uuid' })
  riderId: string;

  @ManyToOne(() => User, { nullable: false })
  @JoinColumn({ name: 'rider_id' })
  rider: User;

  @Column({ length: 20, default: 'PENDING' })
  status: string;

  @CreateDateColumn({
    name: 'invited_at',
    type: 'timestamptz',
  })
  invitedAt: Date;

  @Column({
    name: 'accepted_at',
    type: 'timestamptz',
    nullable: true,
  })
  acceptedAt: Date | null;

  @Column({
    name: 'revoked_at',
    type: 'timestamptz',
    nullable: true,
  })
  revokedAt: Date | null;

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