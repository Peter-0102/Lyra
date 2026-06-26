import { query } from './client.js';

export interface HistoryEntry {
  id: string;
  user_id: string;
  song_id: string;
  title: string;
  artist: string;
  file_path: string | null;
  duration_sec: number | null;
  played_at: number;
  created_at: string;
}

export async function recordPlay(entry: Omit<HistoryEntry, 'id' | 'created_at'>): Promise<HistoryEntry> {
  const result = await query(
    `INSERT INTO listening_history (user_id, song_id, title, artist, file_path, duration_sec, played_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [entry.user_id, entry.song_id, entry.title, entry.artist, entry.file_path, entry.duration_sec, entry.played_at]
  );
  return result.rows[0] as HistoryEntry;
}

export async function getPlayHistory(userId: string, limit = 50, offset = 0): Promise<HistoryEntry[]> {
  const result = await query(
    `SELECT * FROM listening_history
     WHERE user_id = $1
     ORDER BY played_at DESC
     LIMIT $2 OFFSET $3`,
    [userId, limit, offset]
  );
  return result.rows as HistoryEntry[];
}

export async function getRecentPlaysBySongId(userId: string, songId: string, withinMs: number): Promise<HistoryEntry[]> {
  const cutoff = Date.now() - withinMs;
  const result = await query(
    `SELECT * FROM listening_history
     WHERE user_id = $1 AND song_id = $2 AND played_at >= $3
     ORDER BY played_at DESC`,
    [userId, songId, cutoff]
  );
  return result.rows as HistoryEntry[];
}
