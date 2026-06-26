import { query } from './client.js';
export async function createUser(email, passwordHash, username) {
    const now = Date.now();
    const result = await query(`INSERT INTO users (email, password_hash, username, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`, [email, passwordHash, username, now, now]);
    return result.rows[0];
}
export async function findUserByEmail(email) {
    const result = await query('SELECT * FROM users WHERE email = $1', [email]);
    return result.rows[0];
}
export async function findUserById(id) {
    const result = await query('SELECT * FROM users WHERE id = $1', [id]);
    return result.rows[0];
}
export async function createRefreshToken(userId, tokenHash, expiresAt) {
    const now = Date.now();
    const result = await query(`INSERT INTO refresh_tokens (user_id, token_hash, expires_at, created_at)
     VALUES ($1, $2, $3, $4)
     RETURNING *`, [userId, tokenHash, expiresAt, now]);
    return result.rows[0];
}
export async function findRefreshTokenByHash(tokenHash) {
    const result = await query('SELECT * FROM refresh_tokens WHERE token_hash = $1 AND expires_at > $2', [tokenHash, Date.now()]);
    return result.rows[0];
}
export async function deleteRefreshToken(id) {
    await query('DELETE FROM refresh_tokens WHERE id = $1', [id]);
}
export async function deleteExpiredRefreshTokens() {
    await query('DELETE FROM refresh_tokens WHERE expires_at <= $1', [Date.now()]);
}
export async function upsertUserSetting(userId, key, value) {
    const now = Date.now();
    const result = await query(`INSERT INTO user_settings (user_id, key, value, created_at, updated_at)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id, key)
     DO UPDATE SET value = $3, updated_at = $5
     RETURNING *`, [userId, key, JSON.stringify(value), now, now]);
    return result.rows[0];
}
export async function findUserSettings(userId) {
    const result = await query('SELECT * FROM user_settings WHERE user_id = $1 ORDER BY key', [userId]);
    return result.rows;
}
export async function deleteUserSetting(userId, key) {
    await query('DELETE FROM user_settings WHERE user_id = $1 AND key = $2', [userId, key]);
}
//# sourceMappingURL=auth.repository.js.map