import IORedis from 'ioredis';
import { config } from '../config.js';
let redis = null;
export function getRedisConnection() {
    if (!redis) {
        redis = new IORedis(config.redisUrl, {
            maxRetriesPerRequest: null,
            enableReadyCheck: false,
        });
    }
    return redis;
}
export async function closeRedisConnection() {
    if (redis) {
        await redis.quit();
        redis = null;
    }
}
export async function checkRedisConnection() {
    try {
        const conn = getRedisConnection();
        const result = await conn.ping();
        return result === 'PONG';
    }
    catch {
        return false;
    }
}
//# sourceMappingURL=connection.js.map