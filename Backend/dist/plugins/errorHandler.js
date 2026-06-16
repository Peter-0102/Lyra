import { ZodError } from 'zod';
export function errorHandler(error, request, reply) {
    if (error instanceof ZodError) {
        return reply.status(400).send({
            statusCode: 400,
            error: 'Bad Request',
            message: 'Invalid input',
            details: error.flatten().fieldErrors,
        });
    }
    if ('statusCode' in error && typeof error.statusCode === 'number') {
        const fastifyError = error;
        return reply.status(fastifyError.statusCode).send({
            statusCode: fastifyError.statusCode,
            error: fastifyError.code ?? 'Error',
            message: fastifyError.message,
        });
    }
    request.log.error(error);
    return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'An unexpected error occurred',
    });
}
//# sourceMappingURL=errorHandler.js.map