import {
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';
import fs from 'node:fs';

@Injectable()
export class AuthService {
  private readonly firebaseAuth: Auth;

  constructor(
    private readonly configService: ConfigService,
  ) {
    const serviceAccountPath =
      this.configService.getOrThrow<string>(
        'GOOGLE_APPLICATION_CREDENTIALS',
      );

    const serviceAccount = JSON.parse(
      fs.readFileSync(serviceAccountPath, 'utf-8'),
    );

    console.log(
      'Firebase Admin project:',
      serviceAccount.project_id,
    );

    console.log(
      'Firebase Admin client:',
      serviceAccount.client_email,
    );

    const firebaseApp = initializeApp(
      {
        credential: cert(serviceAccount),
        projectId: serviceAccount.project_id,
      },
      'rideguardian',
    );

    this.firebaseAuth = getAuth(firebaseApp);
  }

  async verifyIdToken(idToken: string) {
    try {
      return await this.firebaseAuth.verifyIdToken(
        idToken,
      );
    } catch {
      throw new UnauthorizedException(
        'Invalid Firebase ID token',
      );
    }
  }
}