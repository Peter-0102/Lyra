import { z } from 'zod';
import { resolve } from 'node:path';
import ms, { type StringValue } from 'ms';

const envSchema = z.object({
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('0.0.0.0'),
  REDIS_URL: z.string().default('redis://localhost:6379'),
  DATABASE_URL: z.string().default('postgresql://mispoti:mispoti@localhost:5432/mispoti'),
  AUDIO_DIR: z.string().default('./data/audio'),
  FILE_TTL_HOURS: z.coerce.number().default(168),
  RATE_LIMIT_MAX: z.coerce.number().default(10),
  CORS_ORIGIN: z.string().default('*'),
  JWT_SECRET: z.string().default('dev-secret-change-in-production'),
  JWT_EXPIRES_IN: z.string().default('15m'),
  REFRESH_TOKEN_EXPIRES_IN: z.string().default('7d'),
  YTDLP_TIMEOUT_MS: z.coerce.number().default(5 * 60 * 1000),
  SMTP_HOST: z.string().default('smtp.gmail.com'),
  SMTP_PORT: z.coerce.number().default(587),
  SMTP_USER: z.string().default(''),
  SMTP_PASS: z.string().default(''),
  SMTP_FROM: z.string().default('Mispoti <noreply@mispoti.app>'),
  RESET_TOKEN_EXPIRES_IN: z.string().default('15m'),
});

function parseMs(input: string): number {
  const result = ms(input as StringValue);
  if (typeof result !== 'number') {
    throw new Error(`Invalid duration string: "${input}"`);
  }
  return result;
}

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
    databaseUrl: env.DATABASE_URL,
    audioDir: resolve(env.AUDIO_DIR),
    fileTtlHours: env.FILE_TTL_HOURS,
    fileTtlMs: env.FILE_TTL_HOURS * 60 * 60 * 1000,
    rateLimitMax: env.RATE_LIMIT_MAX,
    corsOrigin: env.CORS_ORIGIN,
    jwtSecret: env.JWT_SECRET,
    jwtExpiresInMs: parseMs(env.JWT_EXPIRES_IN),
    jwtExpiresInSec: Math.floor(parseMs(env.JWT_EXPIRES_IN) / 1000),
    refreshTokenExpiresInMs: parseMs(env.REFRESH_TOKEN_EXPIRES_IN),
    ytdlpTimeoutMs: env.YTDLP_TIMEOUT_MS,
    smtpHost: env.SMTP_HOST,
    smtpPort: env.SMTP_PORT,
    smtpUser: env.SMTP_USER,
    smtpPass: env.SMTP_PASS,
    smtpFrom: env.SMTP_FROM,
    resetTokenExpiresInMs: parseMs(env.RESET_TOKEN_EXPIRES_IN),
  };
}

export const config = loadConfig();

export type Config = ReturnType<typeof loadConfig>;
