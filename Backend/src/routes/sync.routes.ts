import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import * as syncRepository from '../db/sync.repository.js';

const favoriteSchema = z.object({
  songId: z.string().min(1),
  title: z.string().optional(),
  artist: z.string().optional(),
  filePath: z.string().optional(),
  duration: z.number().optional(),
  thumbnail: z.string().optional(),
});

const playlistSchema = z.object({
  id: z.string().optional(),
  name: z.string().min(1),
  description: z.string().optional(),
  songs: z.array(z.unknown()).optional(),
});

const syncFavoritesSchema = z.object({
  favorites: z.array(favoriteSchema),
});

const syncPlaylistsSchema = z.object({
  playlists: z.array(playlistSchema),
});

export async function syncRoutes(app: FastifyInstance) {
  app.post('/sync/favorites', { preHandler: [app.authenticate] }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const { favorites } = syncFavoritesSchema.parse(request.body);
      const userId = request.user!.userId;
      const now = Date.now();

      await syncRepository.replaceFavorites(userId, favorites, now);

      const stored = await syncRepository.getFavorites(userId);
      const result = stored.map(f => ({
        songId: f.song_id,
        title: f.title,
        artist: f.artist,
        filePath: f.file_path,
        duration: f.duration,
        thumbnail: f.thumbnail,
        createdAt: f.created_at,
      }));

      return reply.send({ favorites: result });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to sync favorites.',
      });
    }
  });

  app.get('/sync/favorites', { preHandler: [app.authenticate] }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const userId = request.user!.userId;
      const stored = await syncRepository.getFavorites(userId);
      const result = stored.map(f => ({
        songId: f.song_id,
        title: f.title,
        artist: f.artist,
        filePath: f.file_path,
        duration: f.duration,
        thumbnail: f.thumbnail,
        createdAt: f.created_at,
      }));

      return reply.send({ favorites: result });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to load favorites.',
      });
    }
  });

  app.post('/sync/playlists', { preHandler: [app.authenticate] }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const { playlists } = syncPlaylistsSchema.parse(request.body);
      const userId = request.user!.userId;
      const now = Date.now();

      await syncRepository.replacePlaylists(userId, playlists, now);

      const stored = await syncRepository.getPlaylists(userId);
      const result = stored.map(p => ({
        id: p.id,
        name: p.name,
        description: p.description,
        songs: p.songs,
        createdAt: p.created_at,
        updatedAt: p.updated_at,
      }));

      return reply.send({ playlists: result });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to sync playlists.',
      });
    }
  });

  app.get('/sync/playlists', { preHandler: [app.authenticate] }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const userId = request.user!.userId;
      const stored = await syncRepository.getPlaylists(userId);
      const result = stored.map(p => ({
        id: p.id,
        name: p.name,
        description: p.description,
        songs: p.songs,
        createdAt: p.created_at,
        updatedAt: p.updated_at,
      }));

      return reply.send({ playlists: result });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to load playlists.',
      });
    }
  });
}
