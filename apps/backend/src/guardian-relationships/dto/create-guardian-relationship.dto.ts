import { IsUUID } from 'class-validator';

export class CreateGuardianRelationshipDto {
  @IsUUID()
  riderId: string;
}