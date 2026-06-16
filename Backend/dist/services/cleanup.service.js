import { unlink } from 'node:fs/promises';
import cron from 'node-cron';
import * as repository from '../db/repository.js';
export async function cleanupExpiredFiles() {
    const expired = repository.findExpired(Date.now());
    for (const job of expired) {
        if (job.file_path) {
            try {
                await unlink(job.file_path);
                console.log(`Deleted expired file: ${job.file_path}`);
            }
            catch (err) {
                console.warn(`Failed to delete file ${job.file_path}:`, err);
            }
        }
        repository.markDeleted(job.id);
    }
    if (expired.length > 0) {
        console.log(`Cleanup completed: removed ${expired.length} expired files`);
    }
}
export function startCleanupCron() {
    cron.schedule('0 * * * *', () => {
        cleanupExpiredFiles().catch((err) => {
            console.error('Cleanup cron job failed:', err);
        });
    });
    console.log('Cleanup cron job registered (runs every hour)');
}
//# sourceMappingURL=cleanup.service.js.map