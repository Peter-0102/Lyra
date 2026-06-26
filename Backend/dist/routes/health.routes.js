import { execSync } from 'node:child_process';
import { query } from '../db/client.js';
import { checkRedisConnection } from '../queue/connection.js';
export async function healthRoutes(app) {
    app.get('/health', async () => {
        const results = await Promise.allSettled([
            checkRedisConnection(),
            checkDatabase(),
            checkYtDlp(),
        ]);
        const redis = results[0].status === 'fulfilled' ? results[0].value : false;
        const database = results[1].status === 'fulfilled' ? results[1].value : false;
        const ytDlpResult = results[2].status === 'fulfilled' ? results[2].value : { ok: false, version: undefined };
        const allOk = redis && database && ytDlpResult.ok;
        const response = {
            status: allOk ? 'ok' : 'degraded',
            redis,
            database,
            ytDlp: ytDlpResult.ok,
            ytDlpVersion: ytDlpResult.version,
        };
        return response;
    });
}
async function checkDatabase() {
    try {
        await query('SELECT 1');
        return true;
    }
    catch {
        return false;
    }
}
async function checkYtDlp() {
    try {
        const output = execSync('yt-dlp --version', { timeout: 5000, encoding: 'utf-8' });
        return { ok: true, version: output.trim() };
    }
    catch {
        return { ok: false };
    }
}
//# sourceMappingURL=health.routes.js.map