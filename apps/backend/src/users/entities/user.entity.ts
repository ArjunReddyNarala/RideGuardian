import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'firebase_uid', length: 128, unique: true })
  firebaseUid: string;

  @Column({ length: 100 })
  name: string;

  @Column({
    type: 'varchar',
    length: 255,
    unique: true,
    nullable: true,
  })
  email: string | null;

  @Column({
    type: 'varchar',
    length: 20,
    unique: true,
    nullable: true,
  })
  phone: string | null;

  @Column({ name: 'profile_image_url', type: 'text', nullable: true })
  profileImageUrl: string | null;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;
}