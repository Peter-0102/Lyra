import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import crypto from 'node:crypto';
import { config } from '../config.js';
const SALT_ROUNDS = 12;
export function hashPassword(password) {
    return bcrypt.hash(password, SALT_ROUNDS);
}
export function verifyPassword(password, hash) {
    return bcrypt.compare(password, hash);
}
export function generateAccessToken(payload) {
    return jwt.sign(payload, config.jwtSecret, {
        expiresIn: config.jwtExpiresInSec,
    });
}
export function verifyAccessToken(token) {
    return jwt.verify(token, config.jwtSecret);
}
export function generateRefreshToken() {
    return uuidv4() + '-' + uuidv4();
}
export function hashRefreshToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
}
export function generateTokens(userId, email) {
    const accessToken = generateAccessToken({ userId, email });
    const refreshToken = generateRefreshToken();
    return { accessToken, refreshToken };
}
export function getRefreshTokenExpiry() {
    return Date.now() + config.refreshTokenExpiresInMs;
}
//# sourceMappingURL=auth.service.js.map