declare function loadConfig(): {
    port: number;
    host: string;
    redisUrl: string;
    databasePath: string;
    audioDir: string;
    fileTtlHours: number;
    fileTtlMs: number;
    rateLimitMax: number;
    corsOrigin: string;
};
export declare const config: {
    port: number;
    host: string;
    redisUrl: string;
    databasePath: string;
    audioDir: string;
    fileTtlHours: number;
    fileTtlMs: number;
    rateLimitMax: number;
    corsOrigin: string;
};
export type Config = ReturnType<typeof loadConfig>;
export {};
//# sourceMappingURL=config.d.ts.map