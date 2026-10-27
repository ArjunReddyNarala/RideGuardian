import {
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  ValidateIf,
} from 'class-validator';
import { InvitationRelationshipType } from '../enums/invitation-relationship-type.enum.js';

export class CreateInvitationDto {
  @ValidateIf((o) => !o.inviteePhone)
  @IsEmail()
  @IsOptional()
  inviteeEmail?: string;

  @ValidateIf((o) => !o.inviteeEmail)
  @IsString()
  @IsOptional()
  inviteePhone?: string;

  @IsEnum(InvitationRelationshipType)
  relationshipType: InvitationRelationshipType;
}