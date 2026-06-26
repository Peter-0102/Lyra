import type { UserRow, RefreshTokenRow, UserSettingRow } from '../types/auth.types.js';
export declare function createUser(email: string, passwordHash: string, username: string): Promise<UserRow>;
export declare function findUserByEmail(email: string): Promise<UserRow | undefined>;
export declare function findUserById(id: string): Promise<UserRow | undefined>;
export declare function createRefreshToken(userId: string, tokenHash: string, expiresAt: number): Promise<RefreshTokenRow>;
export declare function findRefreshTokenByHash(tokenHash: string): Promise<RefreshTokenRow | undefined>;
export declare function deleteRefreshToken(id: string): Promise<void>;
export declare function deleteExpiredRefreshTokens(): Promise<void>;
export declare function upsertUserSetting(userId: string, key: string, value: Record<string, unknown>): Promise<UserSettingRow>;
export declare function findUserSettings(userId: string): Promise<UserSettingRow[]>;
export declare function deleteUserSetting(userId: string, key: string): Promise<void>;
//# sourceMappingURL=auth.repository.d.ts.map