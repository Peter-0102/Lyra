import { query } from './client.js';
import type { UserRow, RefreshTokenRow, UserSettingRow } from '../types/auth.types.js';

export async function createUser(email: string, passwordHash: string, username: string): Promise<UserRow> {
  const now = Date.now();
  const result = await query(
    `INSERT INTO users (email, password_hash, username, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [email, passwordHash, username, now, now]
  );
  return result.rows[0] as UserRow;
}

export async function findUserByEmail(email: string): Promise<UserRow | undefined> {
  const result = await query('SELECT * FROM users WHERE email = $1', [email]);
  return result.rows[0] as UserRow | undefined;
}

export async function findUserById(id: string): Promise<UserRow | undefined> {
  const result = await query('SELECT * FROM users WHERE id = $1', [id]);
  return result.rows[0] as UserRow | undefined;
}

export async function createRefreshToken(userId: string, tokenHash: string, expiresAt: number): Promise<RefreshTokenRow> {
  const now = Date.now();
  const result = await query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at, created_at)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [userId, tokenHash, expiresAt, now]
  );
  return result.rows[0] as RefreshTokenRow;
}

export async function findRefreshTokenByHash(tokenHash: string): Promise<RefreshTokenRow | undefined> {
  const result = await query(
    'SELECT * FROM refresh_tokens WHERE token_hash = $1 AND expires_at > $2',
    [tokenHash, Date.now()]
  );
  return result.rows[0] as RefreshTokenRow | undefined;
}

export async function deleteRefreshToken(id: string): Promise<void> {
  await query('DELETE FROM refresh_tokens WHERE id = $1', [id]);
}

export async function deleteExpiredRefreshTokens(): Promise<void> {
  await query('DELETE FROM refresh_tokens WHERE expires_at <= $1', [Date.now()]);
}

export async function upsertUserSetting(userId: string, key: string, value: Record<string, unknown>): Promise<UserSettingRow> {
  const now = Date.now();
  const result = await query(
    `INSERT INTO user_settings (user_id, key, value, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id, key)
     DO UPDATE SET value = $3, updated_at = $5
     RETURNING *`,
    [userId, key, JSON.stringify(value), now, now]
  );
  return result.rows[0] as UserSettingRow;
}

export async function findUserSettings(userId: string): Promise<UserSettingRow[]> {
  const result = await query(
    'SELECT * FROM user_settings WHERE user_id = $1 ORDER BY key',
    [userId]
  );
  return result.rows as UserSettingRow[];
}

export async function deleteUserSetting(userId: string, key: string): Promise<void> {
  await query(
    'DELETE FROM user_settings WHERE user_id = $1 AND key = $2',
    [userId, key]
  );
}

export async function createPasswordResetToken(userId: string, tokenHash: string, expiresAt: number): Promise<void> {
  const now = Date.now();
  await query(
    `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at, created_at)
     VALUES ($1, $2, $3, $4)`,
    [userId, tokenHash, expiresAt, now]
  );
}

export async function findValidResetToken(tokenHash: string): Promise<{ id: string; user_id: string } | undefined> {
  const result = await query(
    'SELECT id, user_id FROM password_reset_tokens WHERE token_hash = $1 AND expires_at > $2 AND used = FALSE',
    [tokenHash, Date.now()]
  );
  return result.rows[0] as { id: string; user_id: string } | undefined;
}

export async function markResetTokenUsed(id: string): Promise<void> {
  await query('UPDATE password_reset_tokens SET used = TRUE WHERE id = $1', [id]);
}

export async function updateUserPassword(userId: string, newHash: string): Promise<void> {
  await query(
    'UPDATE users SET password_hash = $1, updated_at = $2 WHERE id = $3',
    [newHash, Date.now(), userId]
  );
}

export async function deleteRefreshTokensByUserId(userId: string): Promise<void> {
  await query('DELETE FROM refresh_tokens WHERE user_id = $1', [userId]);
}

export async function deleteExpiredResetTokens(): Promise<void> {
  await query('DELETE FROM password_reset_tokens WHERE expires_at <= $1', [Date.now()]);
}
