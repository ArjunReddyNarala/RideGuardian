import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { RiderSafetySetting } from './entities/rider-safety-setting.entity.js';

@Module({
  imports: [TypeOrmModule.forFeature([RiderSafetySetting])],
})
export class RiderSafetySettingsModule {}