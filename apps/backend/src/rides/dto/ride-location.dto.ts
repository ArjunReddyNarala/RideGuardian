import { IsNumber, IsOptional, IsDateString, Max, Min } from 'class-validator';

export class RideLocationDto {
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(350)
  speedKmh?: number | null;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(350)
  speedAccuracyKmh?: number | null;

  @IsOptional()
  @IsNumber()
  @Min(0)
  accuracyMeters?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(360)
  headingDegrees?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  batteryLevel?: number;

  @IsOptional()
  @IsDateString()
  recordedAt?: string;
}
