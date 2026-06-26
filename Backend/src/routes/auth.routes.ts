import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import * as authRepository from '../db/auth.repository.js';
import {
  hashPassword,
  verifyPassword,
  generateTokens,
  hashRefreshToken,
  getRefreshTokenExpiry,
} from '../services/auth.service.js';
import type {
  RegisterBody,
  LoginBody,
  RefreshBody,
  AuthTokens,
  UserProfile,
} from '../types/auth.types.js';

const emailSchema = z.string().email('Invalid email format');
const passwordSchema = z.string().min(6, 'Password must be at least 6 characters');
const usernameSchema = z.string().min(2, 'Username must be at least 2 characters').max(50);

const registerSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  username: usernameSchema,
});

const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1, 'Password is required'),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

const settingsBodySchema = z.record(z.string(), z.unknown());

function toProfile(user: { id: string; email: string; username: string; avatar_url: string | null; created_at: number }): UserProfile {
  return {
    id: user.id,
    email: user.email,
    username: user.username,
    avatarUrl: user.avatar_url,
    createdAt: user.created_at,
  };
}

export async function authRoutes(app: FastifyInstance) {
  app.post<{ Body: RegisterBody }>('/register', async (request: FastifyRequest<{ Body: RegisterBody }>, reply: FastifyReply) => {
    const { email, password, username } = registerSchema.parse(request.body);

    const existing = await authRepository.findUserByEmail(email);
    if (existing) {
      return reply.status(409).send({
        statusCode: 409,
        error: 'Conflict',
        message: 'Email already registered',
      });
    }

    try {
      const passwordHash = await hashPassword(password);
      const user = await authRepository.createUser(email, passwordHash, username);

      const tokens = generateTokens(user.id, user.email);
      const refreshTokenHash = hashRefreshToken(tokens.refreshToken);
      await authRepository.createRefreshToken(user.id, refreshTokenHash, getRefreshTokenExpiry());

      return reply.status(201).send({
        user: toProfile(user),
        ...tokens,
      });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Registration failed. Please try again.',
      });
    }
  });

  app.post<{ Body: LoginBody }>('/login', async (request: FastifyRequest<{ Body: LoginBody }>, reply: FastifyReply) => {
    const { email, password } = loginSchema.parse(request.body);

    try {
      const user = await authRepository.findUserByEmail(email);
      if (!user) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Invalid email or password',
        });
      }

      const valid = await verifyPassword(password, user.password_hash);
      if (!valid) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Invalid email or password',
        });
      }

      const tokens = generateTokens(user.id, user.email);
      const refreshTokenHash = hashRefreshToken(tokens.refreshToken);
      await authRepository.createRefreshToken(user.id, refreshTokenHash, getRefreshTokenExpiry());

      return reply.send({
        user: toProfile(user),
        ...tokens,
      });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Login failed. Please try again.',
      });
    }
  });

  app.post<{ Body: RefreshBody }>('/refresh', async (request: FastifyRequest<{ Body: RefreshBody }>, reply: FastifyReply) => {
    const { refreshToken } = refreshSchema.parse(request.body);

    try {
      const tokenHash = hashRefreshToken(refreshToken);
      const storedToken = await authRepository.findRefreshTokenByHash(tokenHash);

      if (!storedToken) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Invalid or expired refresh token',
        });
      }

      await authRepository.deleteRefreshToken(storedToken.id);

      const user = await authRepository.findUserById(storedToken.user_id);
      if (!user) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'User not found',
        });
      }

      const tokens = generateTokens(user.id, user.email);
      const newRefreshTokenHash = hashRefreshToken(tokens.refreshToken);
      await authRepository.createRefreshToken(user.id, newRefreshTokenHash, getRefreshTokenExpiry());

      return reply.send({
        user: toProfile(user),
        ...tokens,
      });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Session refresh failed. Please login again.',
      });
    }
  });

  app.get('/me', { preHandler: [app.authenticate] }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = await authRepository.findUserById(request.user!.userId);
      if (!user) {
        return reply.status(404).send({
          statusCode: 404,
          error: 'Not Found',
          message: 'User not found',
        });
      }

      return reply.send({ user: toProfile(user) });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to load profile.',
      });
    }
  });

  app.get('/settings', { preHandler: [app.authenticate] }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const settings = await authRepository.findUserSettings(request.user!.userId);
      const result: Record<string, unknown> = {};
      for (const s of settings) {
        result[s.key] = s.value;
      }
      return reply.send({ settings: result });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to load settings.',
      });
    }
  });

  app.put<{ Body: Record<string, unknown> }>('/settings', { preHandler: [app.authenticate] }, async (request: FastifyRequest<{ Body: Record<string, unknown> }>, reply: FastifyReply) => {
    const body = settingsBodySchema.parse(request.body);
    const userId = request.user!.userId;

    try {
      const results: Record<string, unknown> = {};
      for (const [key, value] of Object.entries(body)) {
        const setting = await authRepository.upsertUserSetting(userId, key, value as Record<string, unknown>);
        results[key] = setting.value;
      }

      return reply.send({ settings: results });
    } catch (err) {
      request.log.error(err);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to save settings.',
      });
    }
  });
}
