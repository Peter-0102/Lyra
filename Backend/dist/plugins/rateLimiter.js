import rateLimit from '@fastify/rate-limit';
import { config } from '../config.js';
export async function registerRateLimiter(app) {
    await app.register(rateLimit, {
        max: config.rateLimitMax,
        timeWindow: '1 minute',
        keyGenerator: (request) => {
            return request.ip;
        },
        errorResponseBuilder: (request, context) => {
            return {
                statusCode: 429,
                error: 'Too Many Requests',
                message: `Rate limit exceeded. Max ${context.max} requests per minute. Try again later.`,
            };
        },
    });
}
//# sourceMappingURL=rateLimiter.js.map