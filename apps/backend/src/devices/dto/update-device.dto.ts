import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class UpdateDeviceDto {
  @IsOptional()
  @IsString()
  pushToken?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  appVersion?: string | null;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}