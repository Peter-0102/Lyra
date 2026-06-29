import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { createReadStream, existsSync } from 'node:fs';
import { stat } from 'node:fs/promises';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import * as repository from '../db/repository.js';
import { getAudioQueue } from '../queue/audioQueue.js';
import { config } from '../config.js';
import type { AudioJob, RequestAudioBody, RequestAudioResponse, StatusResponse } from '../types/audio.types.js';

const videoIdRegex = /^[a-zA-Z0-9_-]{11}$/;

const requestBodySchema = z.object({
  videoId: z.string().regex(videoIdRegex, 'Invalid videoId format'),
});

function formatStatusResponse(job: AudioJob): StatusResponse {
  const response: StatusResponse = {
    jobId: job.id,
    status: job.status,
    progress: job.progress ?? undefined,
  };
  if (job.status === 'ready') {
    response.title = job.title ?? undefined;
    response.artist = job.artist ?? undefined;
    response.durationSec = job.duration_sec ?? undefined;
    response.fileSize = job.file_size ?? undefined;
    response.format = job.format ?? undefined;
  }
  if (job.status === 'error') {
    response.errorMessage = job.error_message ?? undefined;
  }
  return response;
}

export async function audioRoutes(app: FastifyInstance) {
  app.post<{ Body: RequestAudioBody }>('/request', { preHandler: [app.authenticate] }, async (request: FastifyRequest<{ Body: RequestAudioBody }>, reply: FastifyReply) => {
    const { videoId } = requestBodySchema.parse(request.body);
    const userId = request.user!.userId;

    const readyJob = await repository.findLatestReadyByVideoId(videoId);

    if (readyJob) {
      if (readyJob.file_path && existsSync(readyJob.file_path)) {
        const response: RequestAudioResponse = {
          jobId: readyJob.id,
          status: 'ready',
          videoId,
          title: readyJob.title ?? undefined,
          artist: readyJob.artist ?? undefined,
          durationSec: readyJob.duration_sec ?? undefined,
          fileSize: readyJob.file_size ?? undefined,
          format: readyJob.format ?? undefined,
        };
        return reply.status(200).send(response);
      }

      const now = Date.now();
      await repository.updateStatus(readyJob.id, 'queued', {
        progress: null,
        file_path: null,
        file_size: null,
        format: null,
        error_message: null,
        expires_at: now + config.fileTtlMs,
      });

      const enqueued = await enqueueJob(videoId, readyJob.id);
      if (!enqueued) {
        return reply.status(503).send({
          statusCode: 503,
          error: 'Service Unavailable',
          message: 'Extraction service is not available. Please try again later.',
        });
      }

      const response: RequestAudioResponse = {
        jobId: readyJob.id,
        status: 'queued',
        videoId,
      };
      return reply.status(202).send(response);
    }

    const inFlightJob = await repository.findLatestInFlightByVideoId(videoId);
    if (inFlightJob) {
      const response: RequestAudioResponse = {
        jobId: inFlightJob.id,
        status: inFlightJob.status,
        videoId,
      };
      return reply.status(202).send(response);
    }

    const now = Date.now();
    const jobId = uuidv4();

    const job: AudioJob = {
      id: jobId,
      video_id: videoId,
      user_id: userId,
      status: 'queued',
      file_path: null,
      file_size: null,
      format: null,
      error_message: null,
      title: null,
      artist: null,
      duration_sec: null,
      progress: null,
      created_at: now,
      updated_at: now,
      expires_at: now + config.fileTtlMs,
    };

    await repository.createJob(job);

    const enqueued = await enqueueJob(videoId, jobId);
    if (!enqueued) {
      await repository.updateStatus(jobId, 'error', {
        error_message: 'Extraction service unavailable',
      });
      return reply.status(503).send({
        statusCode: 503,
        error: 'Service Unavailable',
        message: 'Extraction service is not available. Please try again later.',
      });
    }

    const response: RequestAudioResponse = {
      jobId,
      status: 'queued',
      videoId,
    };

    return reply.status(202).send(response);
  });

async function enqueueJob(videoId: string, jobId: string): Promise<boolean> {
  try {
    const queue = getAudioQueue();
    await queue.add('extract', { videoId, jobId });
    return true;
  } catch (err) {
    console.error(`[Audio] Failed to enqueue job ${jobId} for video ${videoId}:`, err);
    return false;
  }
}

  app.get<{ Params: { jobId: string } }>('/status/:jobId', { preHandler: [app.authenticate] }, async (request: FastifyRequest<{ Params: { jobId: string } }>, reply: FastifyReply) => {
    const { jobId } = request.params;

    const job = await repository.findByJobId(jobId);

    if (!job) {
      return reply.status(404).send({
        statusCode: 404,
        error: 'Not Found',
        message: 'Job not found',
      });
    }

    const response: StatusResponse = {
      jobId: job.id,
      status: job.status,
      progress: job.progress ?? undefined,
    };

    if (job.status === 'ready') {
      response.title = job.title ?? undefined;
      response.artist = job.artist ?? undefined;
      response.durationSec = job.duration_sec ?? undefined;
      response.fileSize = job.file_size ?? undefined;
      response.format = job.format ?? undefined;
    }

    if (job.status === 'error') {
      response.errorMessage = job.error_message ?? undefined;
    }

    return reply.send(response);
  });

  app.get<{ Params: { jobId: string } }>('/status/:jobId/stream', { preHandler: [app.authenticate] }, async (request: FastifyRequest<{ Params: { jobId: string } }>, reply: FastifyReply) => {
    const { jobId } = request.params;

    const initialJob = await repository.findByJobId(jobId);
    if (!initialJob) {
      return reply.status(404).send({
        statusCode: 404,
        error: 'Not Found',
        message: 'Job not found',
      });
    }

    reply.raw.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'X-Accel-Buffering': 'no',
    });

    let lastStatus = '';
    let lastProgress: number | undefined;

    const sendEvent = (event: string, data: unknown) => {
      reply.raw.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
    };

    const poll = async () => {
      try {
        const job = await repository.findByJobId(jobId);
        if (!job) {
          sendEvent('error', { message: 'Job not found' });
          cleanup();
          return;
        }

        const changed = job.status !== lastStatus || job.progress !== lastProgress;
        lastStatus = job.status;
        lastProgress = job.progress ?? undefined;

        if (changed) {
          sendEvent('status', formatStatusResponse(job));
        }

        if (job.status === 'ready' || job.status === 'error') {
          cleanup();
        }
      } catch (err) {
        console.error(`[SSE] Poll error for job ${jobId}:`, err);
      }
    };

    const interval = setInterval(poll, 2000);

    const cleanup = () => {
      clearInterval(interval);
      reply.raw.end();
    };

    request.raw.on('close', cleanup);

    poll();
  });

  app.get<{ Params: { videoId: string } }>('/file/:videoId', { preHandler: [app.authenticate] }, async (request: FastifyRequest<{ Params: { videoId: string } }>, reply: FastifyReply) => {
    const { videoId } = request.params;

    if (!videoIdRegex.test(videoId)) {
      return reply.status(400).send({
        statusCode: 400,
        error: 'Bad Request',
        message: 'Invalid videoId format',
      });
    }

    const job = await repository.findLatestReadyByVideoId(videoId);

    if (!job) {
      return reply.status(404).send({
        statusCode: 404,
        error: 'Not Found',
        message: 'No audio file available. Request extraction first via POST /api/audio/request',
      });
    }

    if (!job.file_path || !existsSync(job.file_path)) {
      return reply.status(410).send({
        statusCode: 410,
        error: 'Gone',
        message: 'Audio file has expired. Request a new extraction via POST /api/audio/request',
      });
    }

    const fileStat = await stat(job.file_path!);
    const fileSize = fileStat.size;
    const contentType = job.format === 'webm' ? 'audio/webm' : 'audio/mp4';
    const filename = `${job.title ?? videoId}.${job.format ?? 'm4a'}`;

    const range = request.headers.range;

    if (range) {
      const parts = range.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

      if (start >= fileSize) {
        return reply.status(416).send({
          statusCode: 416,
          error: 'Range Not Satisfiable',
          message: `Requested range ${start} exceeds file size ${fileSize}`,
        });
      }

      const chunkSize = end - start + 1;

      reply.status(206);
      reply.header('Content-Range', `bytes ${start}-${end}/${fileSize}`);
      reply.header('Content-Length', chunkSize);
      reply.header('Content-Type', contentType);
      reply.header('Accept-Ranges', 'bytes');
      reply.header('Content-Disposition', `attachment; filename="${filename}"`);

      const stream = createReadStream(job.file_path!, { start, end });
      return reply.send(stream);
    }

    reply.header('Content-Type', contentType);
    reply.header('Content-Length', fileSize);
    reply.header('Accept-Ranges', 'bytes');
    reply.header('Content-Disposition', `attachment; filename="${filename}"`);

    const stream = createReadStream(job.file_path!);
    return reply.send(stream);
  });
}
