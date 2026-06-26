export interface User {
    id: string;
    email: string;
    username: string;
    avatar_url: string | null;
    created_at: number;
    updated_at: number;
}
export interface UserRow {
    id: string;
    email: string;
    password_hash: string;
    username: string;
    avatar_url: string | null;
    created_at: number;
    updated_at: number;
}
export interface RefreshTokenRow {
    id: string;
    user_id: string;
    token_hash: string;
    expires_at: number;
    created_at: number;
}
export interface UserSettingRow {
    id: string;
    user_id: string;
    key: string;
    value: Record<string, unknown>;
    created_at: number;
    updated_at: number;
}
export interface RegisterBody {
    email: string;
    password: string;
    username: string;
}
export interface LoginBody {
    email: string;
    password: string;
}
export interface RefreshBody {
    refreshToken: string;
}
export interface AuthTokens {
    accessToken: string;
    refreshToken: string;
}
export interface UserProfile {
    id: string;
    email: string;
    username: string;
    avatarUrl: string | null;
    createdAt: number;
}
export interface JwtPayload {
    userId: string;
    email: string;
}
declare module 'fastify' {
    interface FastifyRequest {
        user?: JwtPayload;
    }
}
//# sourceMappingURL=auth.types.d.ts.map