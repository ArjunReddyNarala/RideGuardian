import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GuardianRiderRelationship } from './entities/guardian-rider-relationship.entity.js';

@Module({
  imports: [TypeOrmModule.forFeature([GuardianRiderRelationship])],
})
export class GuardianRelationshipsModule {}