import {
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsUUID,
} from 'class-validator';

export class CreateRideDto {
  @IsArray()
  @ArrayMinSize(1, {
    message: 'At least one guardian must be selected',
  })
  @ArrayUnique({
    message: 'Duplicate guardian IDs are not allowed',
  })
  @IsUUID('all', { each: true })
  guardianIds: string[];
}