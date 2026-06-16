import { createReadStream, existsSync } from 'node:fs';
import { stat } from 'node:fs/promises';
import { z } from 'zod';
import { v4 as uuidv4 } from 'uuid';
import * as repository from '../db/repository.js';
import { getAudioQueue } from '../queue/audioQueue.js';
import { config } from '../config.js';
const videoIdRegex = /^[a-zA-Z0-9_-]{11}$/;
const requestBodySchema = z.object({
    videoId: z.string().regex(videoIdRegex, 'Invalid videoId format'),
});
export async function audioRoutes(app) {
    app.post('/request', async (request, reply) => {
        const { videoId } = requestBodySchema.parse(request.body);
        const cachedJob = repository.findLatestReadyByVideoId(videoId);
        if (cachedJob && cachedJob.file_path && existsSync(cachedJob.file_path)) {
            const response = {
                jobId: cachedJob.id,
                status: 'ready',
                videoId,
                title: cachedJob.title ?? undefined,
                artist: cachedJob.artist ?? undefined,
                durationSec: cachedJob.duration_sec ?? undefined,
                fileSize: cachedJob.file_size ?? undefined,
                format: cachedJob.format ?? undefined,
            };
            return reply.status(200).send(response);
        }
        const now = Date.now();
        const jobId = uuidv4();
        const job = {
            id: jobId,
            video_id: videoId,
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
        repository.createJob(job);
        const queue = getAudioQueue();
        await queue.add('extract', { videoId, jobId });
        const response = {
            jobId,
            status: 'queued',
            videoId,
        };
        return reply.status(202).send(response);
    });
    app.get('/status/:jobId', async (request, reply) => {
        const { jobId } = request.params;
        const job = repository.findByJobId(jobId);
        if (!job) {
            return reply.status(404).send({
                statusCode: 404,
                error: 'Not Found',
                message: 'Job not found',
            });
        }
        const response = {
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
    app.get('/file/:videoId', async (request, reply) => {
        const { videoId } = request.params;
        if (!videoIdRegex.test(videoId)) {
            return reply.status(400).send({
                statusCode: 400,
                error: 'Bad Request',
                message: 'Invalid videoId format',
            });
        }
        const job = repository.findLatestReadyByVideoId(videoId);
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
        const fileStat = await stat(job.file_path);
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
            const stream = createReadStream(job.file_path, { start, end });
            return reply.send(stream);
        }
        reply.header('Content-Type', contentType);
        reply.header('Content-Length', fileSize);
        reply.header('Accept-Ranges', 'bytes');
        reply.header('Content-Disposition', `attachment; filename="${filename}"`);
        const stream = createReadStream(job.file_path);
        return reply.send(stream);
    });
}
//# sourceMappingURL=audio.routes.js.map