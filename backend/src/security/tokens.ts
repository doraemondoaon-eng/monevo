import { createHmac, randomBytes } from 'node:crypto';
import { errors as joseErrors, jwtVerify, SignJWT } from 'jose';
import { AppError } from '../common/errors.js';

export interface TokenConfig {
  accessSecret: string;
  refreshSecret: string;
  accessTtlSeconds: number;
  refreshTtlDays: number;
}

const ISSUER = 'monevo-api';
const AUDIENCE = 'monevo-app';

export class TokenService {
  private readonly accessKey: Uint8Array;

  constructor(private readonly config: TokenConfig) {
    this.accessKey = new TextEncoder().encode(config.accessSecret);
  }

  get accessTtlSeconds() {
    return this.config.accessTtlSeconds;
  }

  async signAccessToken(userId: string): Promise<string> {
    return new SignJWT({ typ: 'access' })
      .setProtectedHeader({ alg: 'HS256' })
      .setSubject(userId)
      .setIssuer(ISSUER)
      .setAudience(AUDIENCE)
      .setIssuedAt()
      .setExpirationTime(`${this.config.accessTtlSeconds}s`)
      .sign(this.accessKey);
  }

  /** Returns the user id, or throws TOKEN_EXPIRED / INVALID_TOKEN. */
  async verifyAccessToken(token: string): Promise<string> {
    try {
      const { payload } = await jwtVerify(token, this.accessKey, {
        issuer: ISSUER,
        audience: AUDIENCE,
        algorithms: ['HS256'],
      });
      if (payload.typ !== 'access' || typeof payload.sub !== 'string') {
        throw AppError.unauthorized('INVALID_TOKEN', 'Invalid access token');
      }
      return payload.sub;
    } catch (err) {
      if (err instanceof AppError) throw err;
      if (err instanceof joseErrors.JWTExpired) {
        throw AppError.unauthorized('TOKEN_EXPIRED', 'Access token expired');
      }
      throw AppError.unauthorized('INVALID_TOKEN', 'Invalid access token');
    }
  }

  /** Opaque, high-entropy refresh token. Only its keyed hash is persisted. */
  generateRefreshToken(): { token: string; hash: string; expiresAt: Date } {
    const token = randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + this.config.refreshTtlDays * 24 * 60 * 60 * 1000);
    return { token, hash: this.hashRefreshToken(token), expiresAt };
  }

  hashRefreshToken(token: string): string {
    return createHmac('sha256', this.config.refreshSecret).update(token).digest('hex');
  }
}

