import {
  Body,
  Controller,
  Headers,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthService } from './auth.service.js';
import { UsersService } from '../users/users.service.js';

@Controller('api/v1/auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly usersService: UsersService,
  ) {}

  @Post('sync')
  async syncUser(
    @Headers('authorization') authorization: string,
    @Body()
    body: {
      name?: string;
      phone?: string;
      profileImageUrl?: string;
    },
  ) {
    if (!authorization?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing Firebase ID token');
    }

    const idToken = authorization.substring('Bearer '.length);

    let decodedToken;

    try {
      decodedToken = await this.authService.verifyIdToken(idToken);
    } catch {
      throw new UnauthorizedException('Invalid Firebase ID token');
    }

    const firebaseUid = decodedToken.uid;

    // We'll add getUserByFirebaseUid next.
    return {
      firebaseUid,
      message: 'Firebase token verified successfully',
    };
  }
}