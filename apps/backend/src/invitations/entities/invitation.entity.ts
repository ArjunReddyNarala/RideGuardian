import {
  Check,
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
} from 'typeorm';
import { InvitationRelationshipType } from '../enums/invitation-relationship-type.enum.js';

@Entity('invitations')
@Check(`"invitee_email" IS NOT NULL OR "invitee_phone" IS NOT NULL`)
@Check(
  `"status" IN ('PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'CANCELLED')`,
)
export class Invitation {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'inviter_id', type: 'uuid' })
  inviterId: string;

  @Column({
    name: 'invitee_email',
    type: 'varchar',
    length: 255,
    nullable: true,
  })
  inviteeEmail: string | null;

  @Column({
    name: 'invitee_phone',
    type: 'varchar',
    length: 20,
    nullable: true,
  })
  inviteePhone: string | null;

  @Column({
    name: 'relationship_type',
    type: 'varchar',
    length: 30,
    default: InvitationRelationshipType.I_MONITOR_THEM,
  })
  relationshipType: InvitationRelationshipType;

  @Column({ length: 100, unique: true })
  token: string;

  @Column({ length: 20, default: 'PENDING' })
  status: string;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  @Column({ name: 'accepted_at', type: 'timestamptz', nullable: true })
  acceptedAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

}
