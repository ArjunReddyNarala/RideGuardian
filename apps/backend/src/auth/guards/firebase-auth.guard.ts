import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';
import { AuthService } from '../auth.service.js';

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(private readonly authService: AuthService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();

    const authorization = request.headers.authorization;

    if (!authorization?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing Firebase ID token');
    }

    const idToken = authorization.substring('Bearer '.length);

    try {
      const decodedToken = await this.authService.verifyIdToken(idToken);

      request.user = decodedToken;

      return true;
    } catch {
      throw new UnauthorizedException('Invalid Firebase ID token');
    }
  }
}