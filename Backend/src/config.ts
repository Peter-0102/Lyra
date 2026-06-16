import { z } from 'zod';
import { resolve } from 'node:path';

const envSchema = z.object({
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('0.0.0.0'),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  DATABASE_PATH: z.string().default('./data/db.sqlite'),
  AUDIO_DIR: z.string().default('./data/audio'),
  FILE_TTL_HOURS: z.coerce.number().default(168),
  RATE_LIMIT_MAX: z.coerce.number().default(10),
  CORS_ORIGIN: z.string().default('*'),
});

function loadConfig() {
  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    console.error('Invalid environment variables:', parsed.error.flatten().fieldErrors);
    process.exit(1);
  }

  const env = parsed.data;

  return {
    port: env.PORT,
    host: env.HOST,
    redisUrl: env.REDIS_URL,
    databasePath: resolve(env.DATABASE_PATH),
    audioDir: resolve(env.AUDIO_DIR),
    fileTtlHours: env.FILE_TTL_HOURS,
    fileTtlMs: env.FILE_TTL_HOURS * 60 * 60 * 1000,
    rateLimitMax: env.RATE_LIMIT_MAX,
    corsOrigin: env.CORS_ORIGIN,
  };
}

export const config = loadConfig();

export type Config = ReturnType<typeof loadConfig>;
