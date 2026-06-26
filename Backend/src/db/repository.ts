import { query } from './client.js';
import type { AudioJob, JobStatus } from '../types/audio.types.js';

export async function createJob(job: AudioJob): Promise<void> {
  await query(
    `INSERT INTO audio_jobs (id, video_id, user_id, status, file_path, file_size, format,
                             error_message, title, artist, duration_sec, progress,
                             created_at, updated_at, expires_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
    [
      job.id, job.video_id, job.user_id, job.status,
      job.file_path, job.file_size, job.format,
      job.error_message, job.title, job.artist,
      job.duration_sec, job.progress,
      job.created_at, job.updated_at, job.expires_at,
    ]
  );
}

export async function updateStatus(
  id: string,
  status: JobStatus,
  extra: Partial<Pick<AudioJob, 'file_path' | 'file_size' | 'format' | 'error_message' | 'title' | 'artist' | 'duration_sec' | 'expires_at' | 'progress'>> = {}
): Promise<void> {
  const setClauses: string[] = [];
  const params: unknown[] = [];
  let paramIndex = 1;

  setClauses.push(`status = $${paramIndex++}`);
  params.push(status);
  setClauses.push(`updated_at = $${paramIndex++}`);
  params.push(Date.now());

  for (const [key, value] of Object.entries(extra)) {
    if (value !== undefined) {
      setClauses.push(`${key} = $${paramIndex++}`);
      params.push(value);
    }
  }

  params.push(id);
  await query(
    `UPDATE audio_jobs SET ${setClauses.join(', ')} WHERE id = $${paramIndex}`,
    params
  );
}

export async function findByJobId(id: string): Promise<AudioJob | undefined> {
  const result = await query('SELECT * FROM audio_jobs WHERE id = $1', [id]);
  return result.rows[0] as AudioJob | undefined;
}

export async function findLatestReadyByVideoId(videoId: string): Promise<AudioJob | undefined> {
  const result = await query(
    `SELECT * FROM audio_jobs
     WHERE video_id = $1 AND status = 'ready'
     ORDER BY created_at DESC
     LIMIT 1`,
    [videoId]
  );
  return result.rows[0] as AudioJob | undefined;
}

export async function findAnyJobByVideoId(videoId: string): Promise<AudioJob | undefined> {
  const result = await query(
    `SELECT * FROM audio_jobs
     WHERE video_id = $1
     ORDER BY created_at DESC
     LIMIT 1`,
    [videoId]
  );
  return result.rows[0] as AudioJob | undefined;
}

export async function findLatestInFlightByVideoId(videoId: string): Promise<AudioJob | undefined> {
  const result = await query(
    `SELECT * FROM audio_jobs
     WHERE video_id = $1 AND status IN ('queued', 'processing')
     ORDER BY created_at DESC
     LIMIT 1`,
    [videoId]
  );
  return result.rows[0] as AudioJob | undefined;
}

export async function findExpired(now: number): Promise<AudioJob[]> {
  const result = await query(
    'SELECT * FROM audio_jobs WHERE expires_at <= $1 AND status = $2',
    [now, 'ready']
  );
  return result.rows as AudioJob[];
}

export async function markDeleted(id: string): Promise<void> {
  await query(
    'UPDATE audio_jobs SET status = $1, updated_at = $2 WHERE id = $3',
    ['error', Date.now(), id]
  );
}
