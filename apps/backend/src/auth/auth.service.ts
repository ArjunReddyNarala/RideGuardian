import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth, Auth } from 'firebase-admin/auth';
import fs from 'node:fs';

@Injectable()
export class AuthService {
  private readonly firebaseAuth: Auth;

  constructor(private readonly configService: ConfigService) {
    const apps = getApps();

    const firebaseApp =
      apps.length > 0
        ? apps[0]
        : initializeApp({
            credential: cert(
              JSON.parse(
                fs.readFileSync(
                  this.configService.get<string>(
                    'GOOGLE_APPLICATION_CREDENTIALS',
                  )!,
                  'utf-8',
                ),
              ),
            ),
          });

    this.firebaseAuth = getAuth(firebaseApp);
  }

  async verifyIdToken(idToken: string) {
    return this.firebaseAuth.verifyIdToken(idToken);
  }
}