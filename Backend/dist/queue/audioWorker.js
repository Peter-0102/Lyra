import { Worker } from 'bullmq';
import { stat } from 'node:fs/promises';
import { join } from 'node:path';
import { getRedisConnection } from './connection.js';
import { AUDIO_QUEUE_NAME } from './audioQueue.js';
import { initializeDatabase } from '../db/client.js';
import * as repository from '../db/repository.js';
import { runYtDlp, parseYtDlpError, buildAudioExtractionArgs } from '../services/ytdlp.service.js';
import { config } from '../config.js';
async function processJob(job) {
    const { videoId, jobId } = job.data;
    await repository.updateStatus(jobId, 'processing');
    const outputTemplate = join(config.audioDir, `${videoId}.%(ext)s`);
    const args = buildAudioExtractionArgs(videoId, outputTemplate);
    let exitCode;
    let stdout;
    let stderr;
    try {
        const result = await runYtDlp(args, {
            onProgress: (pct) => {
                job.updateProgress?.(pct / 100);
                repository.updateStatus(jobId, 'processing', { progress: pct / 100 });
            },
            timeoutMs: 5 * 60 * 1000,
        });
        exitCode = result.exitCode;
        stdout = result.stdout;
        stderr = result.stderr;
    }
    catch (err) {
        const message = err instanceof Error ? err.message : 'Unknown error';
        await repository.updateStatus(jobId, 'error', {
            error_message: message,
        });
        throw err;
    }
    if (exitCode !== 0) {
        const errorMessage = parseYtDlpError(stderr);
        await repository.updateStatus(jobId, 'error', {
            error_message: errorMessage,
        });
        throw new Error(stderr);
    }
    const metadata = JSON.parse(stdout);
    const ext = metadata.ext || 'm4a';
    const filePath = join(config.audioDir, `${videoId}.${ext}`);
    const fileStat = await stat(filePath).catch(() => null);
    const fileSize = fileStat?.size ?? 0;
    await repository.updateStatus(jobId, 'ready', {
        file_path: filePath,
        file_size: fileSize,
        format: ext,
        title: metadata.title,
        artist: metadata.artist ?? metadata.uploader ?? metadata.channel,
        duration_sec: metadata.duration,
        expires_at: Date.now() + config.fileTtlMs,
    });
}
async function main() {
    await initializeDatabase();
    const worker = new Worker(AUDIO_QUEUE_NAME, async (job) => {
        await processJob(job);
    }, {
        connection: getRedisConnection(),
        concurrency: 2,
        lockDuration: 5 * 60 * 1000,
    });
    worker.on('completed', (job) => {
        console.log(`Job ${job?.id} completed for video ${job?.data.videoId}`);
    });
    worker.on('failed', (job, err) => {
        console.error(`Job ${job?.id} failed for video ${job?.data.videoId}:`, err.message);
    });
    console.log('Audio worker started');
}
main().catch((err) => {
    console.error('Worker failed to start:', err);
    process.exit(1);
});
//# sourceMappingURL=audioWorker.js.map