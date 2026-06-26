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
    const outputTemplate = join(config.audioDir, `${videoId}_${jobId}.%(ext)s`);
    const args = buildAudioExtractionArgs(videoId, outputTemplate);
    let exitCode;
    let stdout;
    let stderr;
    try {
        const result = await runYtDlp(args, {
            onProgress: (pct) => {
                job.updateProgress?.(pct / 100);
                repository.updateStatus(jobId, 'processing', { progress: pct / 100 }).catch((err) => {
                    console.warn(`Failed to update progress for job ${jobId}:`, err);
                });
            },
            timeoutMs: 5 * 60 * 1000,
        });
        exitCode = result.exitCode;
        stdout = result.stdout;
        stderr = result.stderr;
        console.log(`[WORKER] yt-dlp finished. exitCode=${exitCode}`);
        console.log(`[WORKER] Full stdout: ${stdout}`);
        console.log(`[WORKER] Full stderr: ${stderr}`);
    }
    catch (err) {
        const message = err instanceof Error ? err.message : 'Unknown error';
        await repository.updateStatus(jobId, 'error', {
            error_message: message,
        });
        throw err;
    }
    if (exitCode !== 0) {
        console.error(`[WORKER] yt-dlp exited with error code ${exitCode}`);
        console.error(`[WORKER] stderr: ${stderr}`);
        const errorMessage = parseYtDlpError(stderr);
        await repository.updateStatus(jobId, 'error', {
            error_message: errorMessage,
        });
        throw new Error(stderr);
    }
    const jsonStart = stdout.indexOf('{');
    const jsonEnd = stdout.lastIndexOf('}');
    if (jsonStart === -1 || jsonEnd === -1 || jsonEnd < jsonStart) {
        await repository.updateStatus(jobId, 'error', {
            error_message: 'No valid JSON output from yt-dlp',
        });
        throw new Error('No valid JSON output from yt-dlp');
    }
    const metadata = JSON.parse(stdout.substring(jsonStart, jsonEnd + 1));
    console.log(`[WORKER] Parsed metadata from YouTube:`);
    console.log(`  title: ${metadata.title}`);
    console.log(`  artist: ${metadata.artist}`);
    console.log(`  uploader: ${metadata.uploader}`);
    console.log(`  channel: ${metadata.channel}`);
    console.log(`  duration: ${metadata.duration}`);
    console.log(`  ext: ${metadata.ext}`);
    console.log(`  format: ${metadata.format}`);
    console.log(`  webpage_url: ${metadata.webpage_url}`);
    const ext = metadata.ext || 'm4a';
    const filePath = join(config.audioDir, `${videoId}_${jobId}.${ext}`);
    const fileStat = await stat(filePath).catch(() => null);
    const fileSize = fileStat?.size ?? 0;
    console.log(`[WORKER] File saved at: ${filePath}, size: ${fileSize} bytes`);
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