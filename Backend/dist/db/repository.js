import { getDb } from './client.js';
export function createJob(job) {
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
export function updateStatus(id, status, extra = {}) {
    const db = getDb();
    const fields = ['status = @status', 'updated_at = @updated_at'];
    const params = { id, status, updated_at: Date.now() };
    for (const [key, value] of Object.entries(extra)) {
        if (value !== undefined) {
            fields.push(`${key} = @${key}`);
            params[key] = value;
        }
    }
    const stmt = db.prepare(`UPDATE audio_jobs SET ${fields.join(', ')} WHERE id = @id`);
    stmt.run(params);
}
export function findByJobId(id) {
    const db = getDb();
    const stmt = db.prepare('SELECT * FROM audio_jobs WHERE id = ?');
    return stmt.get(id);
}
export function findLatestReadyByVideoId(videoId) {
    const db = getDb();
    const stmt = db.prepare(`
    SELECT * FROM audio_jobs
    WHERE video_id = ? AND status = 'ready'
    ORDER BY created_at DESC
    LIMIT 1
  `);
    return stmt.get(videoId);
}
export function findLatestInFlightByVideoId(videoId) {
    const db = getDb();
    const stmt = db.prepare(`
    SELECT * FROM audio_jobs
    WHERE video_id = ? AND status IN ('queued', 'processing')
    ORDER BY created_at DESC
    LIMIT 1
  `);
    return stmt.get(videoId);
}
export function findExpired(now) {
    const db = getDb();
    const stmt = db.prepare('SELECT * FROM audio_jobs WHERE expires_at <= ? AND status = ?');
    return stmt.all(now, 'ready');
}
export function markDeleted(id) {
    const db = getDb();
    const stmt = db.prepare('UPDATE audio_jobs SET status = ?, updated_at = ? WHERE id = ?');
    stmt.run('error', Date.now(), id);
}
//# sourceMappingURL=repository.js.map