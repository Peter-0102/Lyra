import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import * as repository from '../db/history.repository.js';

const recordPlaySchema = z.object({
  songId: z.string().min(1),
  title: z.string().min(1),
  artist: z.string().min(1),
  filePath: z.string().nullable().optional(),
  durationSec: z.number().int().nullable().optional(),
  playedAt: z.number(),
});

export async function historyRoutes(app: FastifyInstance) {
  app.post(
    '/api/history',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.userId;
      const body = recordPlaySchema.parse(request.body);

      const entry = await repository.recordPlay({
        user_id: userId,
        song_id: body.songId,
        title: body.title,
        artist: body.artist,
        file_path: body.filePath ?? null,
        duration_sec: body.durationSec ?? null,
        played_at: body.playedAt,
      });

      return reply.status(201).send(entry);
    }
  );

  app.get(
    '/api/history',
    { preHandler: [app.authenticate] },
    async (request: FastifyRequest, reply: FastifyReply) => {
      const userId = request.user!.userId;
      const query = request.query as { limit?: string; offset?: string };
      const limit = Math.min(Math.max(parseInt(query.limit ?? '50', 10) || 50, 1), 200);
      const offset = Math.max(parseInt(query.offset ?? '0', 10) || 0, 0);

      const entries = await repository.getPlayHistory(userId, limit, offset);
      return reply.send(entries);
    }
  );
}
