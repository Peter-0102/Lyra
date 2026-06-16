import { FastifyError, FastifyReply, FastifyRequest } from 'fastify';
import { ZodError } from 'zod';

export function errorHandler(
  error: FastifyError | ZodError | Error,
  request: FastifyRequest,
  reply: FastifyReply
) {
  if (error instanceof ZodError) {
    return reply.status(400).send({
      statusCode: 400,
      error: 'Bad Request',
      message: 'Invalid input',
      details: error.flatten().fieldErrors,
    });
  }

  if ('statusCode' in error && typeof (error as any).statusCode === 'number') {
    const fastifyError = error as FastifyError;
    return reply.status(fastifyError.statusCode!).send({
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
