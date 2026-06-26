import { z } from 'zod';
import { resolve } from 'node:path';
import ms from 'ms';
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
});
function parseMs(input) {
    const result = ms(input);
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
    };
}
export const config = loadConfig();
//# sourceMappingURL=config.js.map