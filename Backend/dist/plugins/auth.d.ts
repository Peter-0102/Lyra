import { FastifyInstance, FastifyReply } from 'fastify';
export declare function authPlugin(app: FastifyInstance): Promise<void>;
declare module 'fastify' {
    interface FastifyInstance {
        authenticate: (request: FastifyRequest, reply: FastifyReply) => Promise<void>;
    }
}
//# sourceMappingURL=auth.d.ts.map