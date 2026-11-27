import { IsEmail } from 'class-validator';

export class CreateGuardianRelationshipDto {
  @IsEmail()
  riderEmail: string;
}