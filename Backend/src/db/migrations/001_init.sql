CREATE TABLE IF NOT EXISTS audio_jobs (
  id            TEXT PRIMARY KEY,
  video_id      TEXT NOT NULL,
  user_id       TEXT,
  status        TEXT NOT NULL CHECK(status IN ('queued','processing','ready','error')),
  file_path     TEXT,
  file_size     BIGINT,
  format        TEXT,
  error_message TEXT,
  title         TEXT,
  artist        TEXT,
  duration_sec  INTEGER,
  progress      REAL,
  created_at    BIGINT NOT NULL,
  updated_at    BIGINT NOT NULL,
  expires_at    BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_audio_jobs_video_id ON audio_jobs(video_id);
CREATE INDEX IF NOT EXISTS idx_audio_jobs_user_id ON audio_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_audio_jobs_expires_at ON audio_jobs(expires_at);
CREATE INDEX IF NOT EXISTS idx_audio_jobs_status ON audio_jobs(status);
