import { Worker, Job } from 'bullmq';
import { stat } from 'node:fs/promises';
import { join } from 'node:path';
import { getRedisConnection } from './connection.js';
import { AUDIO_QUEUE_NAME } from './audioQueue.js';
import { initializeDatabase } from '../db/client.js';
import * as repository from '../db/repository.js';
import { runYtDlp, parseYtDlpError, buildAudioExtractionArgs } from '../services/ytdlp.service.js';
import { config } from '../config.js';

interface ExtractionData {
  videoId: string;
  jobId: string;
}

const MAX_RETRIES = 3;

async function processJob(job: Job<ExtractionData>) {
  const { videoId, jobId } = job.data;
  const attempts = job.attemptsMade || 0;

  await repository.updateStatus(jobId, 'processing');

  const outputTemplate = join(config.audioDir, `${videoId}_${jobId}.%(ext)s`);

  const args = buildAudioExtractionArgs(videoId, outputTemplate);

  let exitCode: number;
  let stdout: string;
  let stderr: string;

  const timeoutMs = config.ytdlpTimeoutMs + (attempts * 60 * 1000);

  try {
    const result = await runYtDlp(args, {
      onProgress: (pct: number) => {
        job.updateProgress?.(pct / 100);
        repository.updateStatus(jobId, 'processing', { progress: pct / 100 }).catch((err) => {
          console.warn(`Failed to update progress for job ${jobId}:`, err);
        });
      },
      timeoutMs,
    });

    exitCode = result.exitCode;
    stdout = result.stdout;
    stderr = result.stderr;
    console.log(`[WORKER] yt-dlp finished. exitCode=${exitCode} (attempt ${attempts + 1}/${MAX_RETRIES + 1})`);
    console.log(`[WORKER] Full stdout: ${stdout}`);
    console.log(`[WORKER] Full stderr: ${stderr}`);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    console.error(`[WORKER] yt-dlp failed on attempt ${attempts + 1}: ${message}`);

    if (attempts < MAX_RETRIES) {
      const backoffDelay = Math.pow(2, attempts) * 10000;
      console.log(`[WORKER] Retrying job ${jobId} in ${backoffDelay}ms (attempt ${attempts + 1}/${MAX_RETRIES})`);
      throw err;
    }

    await repository.updateStatus(jobId, 'error', {
      error_message: `Failed after ${MAX_RETRIES + 1} attempts: ${message}`,
    });
    throw err;
  }

  if (exitCode !== 0) {
    console.error(`[WORKER] yt-dlp exited with error code ${exitCode}`);
    console.error(`[WORKER] stderr: ${stderr}`);

    if (attempts < MAX_RETRIES) {
      const backoffDelay = Math.pow(2, attempts) * 10000;
      console.log(`[WORKER] Retrying job ${jobId} in ${backoffDelay}ms (attempt ${attempts + 1}/${MAX_RETRIES})`);
      throw new Error(stderr);
    }

    const errorMessage = parseYtDlpError(stderr);
    await repository.updateStatus(jobId, 'error', {
      error_message: `Failed after ${MAX_RETRIES + 1} attempts: ${errorMessage}`,
    });
    throw new Error(stderr);
  }

  const jsonStart = stdout.indexOf('{');
  const jsonEnd = stdout.lastIndexOf('}');
  if (jsonStart === -1 || jsonEnd === -1 || jsonEnd < jsonStart) {
    if (attempts < MAX_RETRIES) {
      const backoffDelay = Math.pow(2, attempts) * 10000;
      console.log(`[WORKER] No JSON output, retrying in ${backoffDelay}ms`);
      throw new Error('No valid JSON output from yt-dlp');
    }
    await repository.updateStatus(jobId, 'error', {
      error_message: 'No valid JSON output from yt-dlp after all retries',
    });
    throw new Error('No valid JSON output from yt-dlp');
  }
  const metadata = JSON.parse(stdout.substring(jsonStart, jsonEnd + 1));
  console.log(`[WORKER] Parsed metadata from YouTube:`);
  console.log(`  title: ${metadata.title}`);
  console.log(`  uploader: ${metadata.uploader}`);
  console.log(`  duration: ${metadata.duration}`);
  console.log(`  ext: ${metadata.ext}`);

  const ext = (metadata.ext as string) || 'm4a';
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

  const worker = new Worker(
    AUDIO_QUEUE_NAME,
    async (job) => {
      await processJob(job);
    },
    {
      connection: getRedisConnection() as any,
      concurrency: 2,
      lockDuration: config.ytdlpTimeoutMs + 60000,
    }
  );

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
