import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';

export class UpdateRiderSafetySettingsDto {
  @IsOptional()
  @IsNumber()
  @Min(1)
  @Max(999.99)
  maxSpeedKmh?: number | null;

  @IsOptional()
  @IsBoolean()
  speedAlertEnabled?: boolean;

  @IsOptional()
  @IsInt()
  @Min(0)
  speedAlertCooldownSeconds?: number;
}