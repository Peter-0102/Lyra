import { verifyAccessToken } from '../services/auth.service.js';
export async function authPlugin(app) {
    app.decorate('authenticate', async function (request, reply) {
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
        }
        catch (err) {
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
}
//# sourceMappingURL=auth.js.map