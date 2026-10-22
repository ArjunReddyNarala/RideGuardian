import {
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class RegisterDeviceDto {
  @IsIn(['IOS', 'ANDROID'])
  platform: 'IOS' | 'ANDROID';

  @IsOptional()
  @IsString()
  @MaxLength(255)
  deviceIdentifier?: string | null;

  @IsOptional()
  @IsString()
  pushToken?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  appVersion?: string | null;
}