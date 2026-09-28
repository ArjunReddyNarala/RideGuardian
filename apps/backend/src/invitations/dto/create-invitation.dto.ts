import {
  IsEmail,
  IsOptional,
  IsString,
  ValidateIf,
} from 'class-validator';

export class CreateInvitationDto {
  @ValidateIf((o) => !o.inviteePhone)
  @IsEmail()
  @IsOptional()
  inviteeEmail?: string;

  @ValidateIf((o) => !o.inviteeEmail)
  @IsString()
  @IsOptional()
  inviteePhone?: string;
}