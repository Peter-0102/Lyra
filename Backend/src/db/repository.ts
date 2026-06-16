import { getDb } from './client.js';
import type { AudioJob, JobStatus } from '../types/audio.types.js';

export function createJob(job: AudioJob): void {
  const db = getDb();
  const stmt = db.prepare(`
    INSERT INTO audio_jobs (id, video_id, status, file_path, file_size, format,
                            error_message, title, artist, duration_sec, progress,
                            created_at, updated_at, expires_at)
    VALUES (@id, @video_id, @status, @file_path, @file_size, @format,
            @error_message, @title, @artist, @duration_sec, @progress,
            @created_at, @updated_at, @expires_at)
  `);
  stmt.run(job);
}

export function updateStatus(
  id: string,
  status: JobStatus,
  extra: Partial<Pick<AudioJob, 'file_path' | 'file_size' | 'format' | 'error_message' | 'title' | 'artist' | 'duration_sec' | 'expires_at' | 'progress'>> = {}
): void {
  const db = getDb();
  const fields = ['status = @status', 'updated_at = @updated_at'];
  const params: Record<string, unknown> = { id, status, updated_at: Date.now() };

  for (const [key, value] of Object.entries(extra)) {
    if (value !== undefined) {
      fields.push(`${key} = @${key}`);
      params[key] = value;
    }
  }

  const stmt = db.prepare(`UPDATE audio_jobs SET ${fields.join(', ')} WHERE id = @id`);
  stmt.run(params);
}

export function findByJobId(id: string): AudioJob | undefined {
  const db = getDb();
  const stmt = db.prepare('SELECT * FROM audio_jobs WHERE id = ?');
  return stmt.get(id) as AudioJob | undefined;
}

export function findLatestReadyByVideoId(videoId: string): AudioJob | undefined {
  const db = getDb();
  const stmt = db.prepare(`
    SELECT * FROM audio_jobs
    WHERE video_id = ? AND status = 'ready'
    ORDER BY created_at DESC
    LIMIT 1
  `);
  return stmt.get(videoId) as AudioJob | undefined;
}

export function findLatestInFlightByVideoId(videoId: string): AudioJob | undefined {
  const db = getDb();
  const stmt = db.prepare(`
    SELECT * FROM audio_jobs
    WHERE video_id = ? AND status IN ('queued', 'processing')
    ORDER BY created_at DESC
    LIMIT 1
  `);
  return stmt.get(videoId) as AudioJob | undefined;
}

export function findExpired(now: number): AudioJob[] {
  const db = getDb();
  const stmt = db.prepare('SELECT * FROM audio_jobs WHERE expires_at <= ? AND status = ?');
  return stmt.all(now, 'ready') as AudioJob[];
}

export function markDeleted(id: string): void {
  const db = getDb();
  const stmt = db.prepare('UPDATE audio_jobs SET status = ?, updated_at = ? WHERE id = ?');
  stmt.run('error', Date.now(), id);
}
