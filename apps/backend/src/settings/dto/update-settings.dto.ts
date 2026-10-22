import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class UpdateSettingsDto {
  @IsOptional()
  @IsBoolean()
  notificationsEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  pushNotificationsEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  rideUpdatesEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  speedAlertsEnabled?: boolean;

  @IsOptional()
  @IsBoolean()
  soundEnabled?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  language?: string;

  @IsOptional()
  @IsIn(['KM', 'MI'])
  distanceUnit?: 'KM' | 'MI';
}