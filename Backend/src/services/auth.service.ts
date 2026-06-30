import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import crypto from 'node:crypto';
import { config } from '../config.js';
import type { JwtPayload, AuthTokens } from '../types/auth.types.js';

const SALT_ROUNDS = 12;

export function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

export function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

export function generateAccessToken(payload: JwtPayload): string {
  return jwt.sign(payload, config.jwtSecret, {
    expiresIn: config.jwtExpiresInSec,
  });
}

export function verifyAccessToken(token: string): JwtPayload {
  return jwt.verify(token, config.jwtSecret) as JwtPayload;
}

export function generateRefreshToken(): string {
  return uuidv4() + '-' + uuidv4();
}

export function hashRefreshToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function generateTokens(userId: string, email: string): AuthTokens {
  const accessToken = generateAccessToken({ userId, email });
  const refreshToken = generateRefreshToken();
  return { accessToken, refreshToken };
}

export function getRefreshTokenExpiry(): number {
  return Date.now() + config.refreshTokenExpiresInMs;
}

export function generateResetCode(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}

export function hashResetToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function getResetTokenExpiry(): number {
  return Date.now() + config.resetTokenExpiresInMs;
}
