declare function loadConfig(): {
    port: number;
    host: string;
    redisUrl: string;
    databaseUrl: string;
    audioDir: string;
    fileTtlHours: number;
    fileTtlMs: number;
    rateLimitMax: number;
    corsOrigin: string;
    jwtSecret: string;
    jwtExpiresInMs: number;
    jwtExpiresInSec: number;
    refreshTokenExpiresInMs: number;
};
export declare const config: {
    port: number;
    host: string;
    redisUrl: string;
    databaseUrl: string;
    audioDir: string;
    fileTtlHours: number;
    fileTtlMs: number;
    rateLimitMax: number;
    corsOrigin: string;
    jwtSecret: string;
    jwtExpiresInMs: number;
    jwtExpiresInSec: number;
    refreshTokenExpiresInMs: number;
};
export type Config = ReturnType<typeof loadConfig>;
export {};
//# sourceMappingURL=config.d.ts.map