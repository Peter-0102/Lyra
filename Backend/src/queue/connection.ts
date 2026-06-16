import IORedis from 'ioredis';
import { config } from '../config.js';

let redis: any = null;

export function getRedisConnection(): any {
  if (!redis) {
    redis = new (IORedis as any)(config.redisUrl, {
      maxRetriesPerRequest: null,
      enableReadyCheck: false,
    });
  }
  return redis;
}

export async function closeRedisConnection(): Promise<void> {
  if (redis) {
    await redis.quit();
    redis = null;
  }
}

export async function checkRedisConnection(): Promise<boolean> {
  try {
    const conn = getRedisConnection();
    const result = await conn.ping();
    return result === 'PONG';
  } catch {
    return false;
  }
}
