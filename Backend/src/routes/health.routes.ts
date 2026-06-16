import { FastifyInstance } from 'fastify';
import { execSync } from 'node:child_process';
import { getDb } from '../db/client.js';
import { checkRedisConnection } from '../queue/connection.js';
import type { HealthResponse } from '../types/audio.types.js';

export async function healthRoutes(app: FastifyInstance) {
  app.get('/health', async () => {
    const results = await Promise.allSettled([
      checkRedisConnection(),
      checkSqlite(),
      checkYtDlp(),
    ]);

    const redis = results[0].status === 'fulfilled' ? results[0].value : false;
    const sqlite = results[1].status === 'fulfilled' ? results[1].value : false;
    const ytDlpResult = results[2].status === 'fulfilled' ? results[2].value : { ok: false, version: undefined };

    const allOk = redis && sqlite && ytDlpResult.ok;

    const response: HealthResponse = {
      status: allOk ? 'ok' : 'degraded',
      redis,
      sqlite,
      ytDlp: ytDlpResult.ok,
      ytDlpVersion: ytDlpResult.version,
    };

    return response;
  });
}

async function checkSqlite(): Promise<boolean> {
  try {
    const db = getDb();
    db.prepare('SELECT 1').get();
    return true;
  } catch {
    return false;
  }
}

async function checkYtDlp(): Promise<{ ok: boolean; version?: string }> {
  try {
    const output = execSync('yt-dlp --version', { timeout: 5000, encoding: 'utf-8' });
    return { ok: true, version: output.trim() };
  } catch {
    return { ok: false };
  }
}
