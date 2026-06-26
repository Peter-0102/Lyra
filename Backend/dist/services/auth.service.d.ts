import type { JwtPayload, AuthTokens } from '../types/auth.types.js';
export declare function hashPassword(password: string): Promise<string>;
export declare function verifyPassword(password: string, hash: string): Promise<boolean>;
export declare function generateAccessToken(payload: JwtPayload): string;
export declare function verifyAccessToken(token: string): JwtPayload;
export declare function generateRefreshToken(): string;
export declare function hashRefreshToken(token: string): string;
export declare function generateTokens(userId: string, email: string): AuthTokens;
export declare function getRefreshTokenExpiry(): number;
//# sourceMappingURL=auth.service.d.ts.map