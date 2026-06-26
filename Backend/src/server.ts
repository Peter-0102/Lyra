import Fastify from 'fastify';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import cron from 'node-cron';
import { config } from './config.js';
import { initializeDatabase, closeDatabase } from './db/client.js';
import { deleteExpiredRefreshTokens } from './db/auth.repository.js';
import { audioRoutes } from './routes/audio.routes.js';
import { authRoutes } from './routes/auth.routes.js';
import { healthRoutes } from './routes/health.routes.js';
import { syncRoutes } from './routes/sync.routes.js';
import { historyRoutes } from './routes/history.routes.js';
import { errorHandler } from './plugins/errorHandler.js';
import { startCleanupCron } from './services/cleanup.service.js';
import { closeAudioQueue } from './queue/audioQueue.js';
import { verifyAccessToken } from './services/auth.service.js';
import type { FastifyRequest, FastifyReply } from 'fastify';

async function main() {
  await initializeDatabase();

  const app = Fastify({ logger: true });

  await app.register(cors, { origin: config.corsOrigin });
  await app.register(rateLimit, {
    max: config.rateLimitMax,
    timeWindow: '1 minute',
  });

  app.setErrorHandler(errorHandler);

  app.decorate('authenticate', async function (request: FastifyRequest, reply: FastifyReply) {
    const authHeader = request.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Missing or invalid authorization header',
      });
    }

    const token = authHeader.substring(7);
    try {
      const payload = verifyAccessToken(token);
      request.user = payload;
    } catch (err) {
      const message = err instanceof Error && err.name === 'TokenExpiredError'
        ? 'Token expired'
        : 'Invalid token';
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message,
      });
    }
  });

  await app.register(authRoutes, { prefix: '/api/auth' });
  await app.register(audioRoutes, { prefix: '/api/audio' });
  await app.register(syncRoutes, { prefix: '/api' });
  await app.register(healthRoutes, { prefix: '/api' });
  await app.register(historyRoutes, { prefix: '/api' });

  startCleanupCron();

  cron.schedule('0 */6 * * *', () => {
    deleteExpiredRefreshTokens().catch((err) => {
      console.error('Refresh token cleanup failed:', err);
    });
  });

  const signals: NodeJS.Signals[] = ['SIGINT', 'SIGTERM'];
  for (const signal of signals) {
    process.on(signal, async () => {
      console.log(`Received ${signal}, shutting down...`);
      await app.close();
      await closeAudioQueue();
      await closeDatabase();
      process.exit(0);
    });
  }

  try {
    await app.listen({ port: config.port, host: config.host });
    console.log(`Server listening on ${config.host}:${config.port}`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

main();

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
}
