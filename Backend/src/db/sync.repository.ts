import { query, getPool } from './client.js';

interface FavoriteRow {
  id: string;
  user_id: string;
  song_id: string;
  title: string | null;
  artist: string | null;
  file_path: string | null;
  duration: number | null;
  thumbnail: string | null;
  created_at: number;
}

interface PlaylistRow {
  id: string;
  user_id: string;
  name: string;
  description: string | null;
  songs: unknown[];
  created_at: number;
  updated_at: number;
}

export async function replaceFavorites(userId: string, favorites: Array<{
  songId: string; title?: string; artist?: string; filePath?: string; duration?: number; thumbnail?: string;
}>, now: number): Promise<void> {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM user_favorites WHERE user_id = $1', [userId]);

    for (const fav of favorites) {
      await client.query(
        `INSERT INTO user_favorites (user_id, song_id, title, artist, file_path, duration, thumbnail, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [userId, fav.songId, fav.title ?? null, fav.artist ?? null, fav.filePath ?? null, fav.duration ?? null, fav.thumbnail ?? null, now]
      );
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function getFavorites(userId: string): Promise<FavoriteRow[]> {
  const result = await query(
    'SELECT * FROM user_favorites WHERE user_id = $1 ORDER BY created_at DESC',
    [userId]
  );
  return result.rows as FavoriteRow[];
}

export async function replacePlaylists(userId: string, playlists: Array<{
  id?: string; name: string; description?: string; songs?: unknown[];
}>, now: number): Promise<void> {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    await client.query('DELETE FROM user_playlists WHERE user_id = $1', [userId]);

    for (const pl of playlists) {
      await client.query(
        `INSERT INTO user_playlists (user_id, name, description, songs, created_at, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [userId, pl.name, pl.description ?? null, JSON.stringify(pl.songs ?? []), now, now]
      );
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export async function getPlaylists(userId: string): Promise<PlaylistRow[]> {
  const result = await query(
    'SELECT * FROM user_playlists WHERE user_id = $1 ORDER BY updated_at DESC',
    [userId]
  );
  return result.rows as PlaylistRow[];
}
