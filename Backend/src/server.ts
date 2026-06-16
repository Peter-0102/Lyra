import Fastify from 'fastify';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import { config } from './config.js';
import { initializeDatabase } from './db/client.js';
import { audioRoutes } from './routes/audio.routes.js';
import { healthRoutes } from './routes/health.routes.js';
import { errorHandler } from './plugins/errorHandler.js';
import { startCleanupCron } from './services/cleanup.service.js';

async function main() {
  await initializeDatabase();

  const app = Fastify({ logger: true });

  await app.register(cors, { origin: config.corsOrigin });
  await app.register(rateLimit, {
    max: config.rateLimitMax,
    timeWindow: '1 minute',
  });

  app.setErrorHandler(errorHandler);

  await app.register(audioRoutes, { prefix: '/api/audio' });
  await app.register(healthRoutes, { prefix: '/api' });

  startCleanupCron();

  try {
    await app.listen({ port: config.port, host: config.host });
    console.log(`Server listening on ${config.host}:${config.port}`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

main();
