import { query, getPool } from './client.js';
export async function replaceFavorites(userId, favorites, now) {
    const client = await getPool().connect();
    try {
        await client.query('BEGIN');
        await client.query('DELETE FROM user_favorites WHERE user_id = $1', [userId]);
        for (const fav of favorites) {
            await client.query(`INSERT INTO user_favorites (user_id, song_id, title, artist, file_path, duration, thumbnail, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`, [userId, fav.songId, fav.title ?? null, fav.artist ?? null, fav.filePath ?? null, fav.duration ?? null, fav.thumbnail ?? null, now]);
        }
        await client.query('COMMIT');
    }
    catch (err) {
        await client.query('ROLLBACK');
        throw err;
    }
    finally {
        client.release();
    }
}
export async function getFavorites(userId) {
    const result = await query('SELECT * FROM user_favorites WHERE user_id = $1 ORDER BY created_at DESC', [userId]);
    return result.rows;
}
export async function replacePlaylists(userId, playlists, now) {
    const client = await getPool().connect();
    try {
        await client.query('BEGIN');
        await client.query('DELETE FROM user_playlists WHERE user_id = $1', [userId]);
        for (const pl of playlists) {
            await client.query(`INSERT INTO user_playlists (user_id, name, description, songs, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6)`, [userId, pl.name, pl.description ?? null, JSON.stringify(pl.songs ?? []), now, now]);
        }
        await client.query('COMMIT');
    }
    catch (err) {
        await client.query('ROLLBACK');
        throw err;
    }
    finally {
        client.release();
    }
}
export async function getPlaylists(userId) {
    const result = await query('SELECT * FROM user_playlists WHERE user_id = $1 ORDER BY updated_at DESC', [userId]);
    return result.rows;
}
//# sourceMappingURL=sync.repository.js.map