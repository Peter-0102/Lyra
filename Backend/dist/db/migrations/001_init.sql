CREATE TABLE IF NOT EXISTS audio_jobs (
  id            TEXT PRIMARY KEY,
  video_id      TEXT NOT NULL,
  status        TEXT NOT NULL CHECK(status IN ('queued','processing','ready','error')),
  file_path     TEXT,
  file_size     INTEGER,
  format        TEXT,
  error_message TEXT,
  title         TEXT,
  artist        TEXT,
  duration_sec  INTEGER,
  progress      REAL,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  expires_at    INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audio_jobs_video_id ON audio_jobs(video_id);
CREATE INDEX IF NOT EXISTS idx_audio_jobs_expires_at ON audio_jobs(expires_at);
CREATE INDEX IF NOT EXISTS idx_audio_jobs_status ON audio_jobs(status);
