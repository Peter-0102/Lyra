CREATE TABLE IF NOT EXISTS user_favorites (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  song_id    TEXT NOT NULL,
  title      TEXT,
  artist     TEXT,
  file_path  TEXT,
  duration   INTEGER,
  thumbnail  TEXT,
  created_at BIGINT NOT NULL,
  UNIQUE(user_id, song_id)
);

CREATE INDEX IF NOT EXISTS idx_user_favorites_user_id ON user_favorites(user_id);

CREATE TABLE IF NOT EXISTS user_playlists (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  description TEXT,
  songs       JSONB NOT NULL DEFAULT '[]',
  created_at  BIGINT NOT NULL,
  updated_at  BIGINT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_playlists_user_id ON user_playlists(user_id);
