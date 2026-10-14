import { IsUUID } from 'class-validator';

export class AddRideGuardianDto {
  @IsUUID()
  guardianId: string;
}