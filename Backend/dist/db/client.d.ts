import pg from 'pg';
export declare function getPool(): pg.Pool;
export declare function query(text: string, params?: unknown[]): Promise<pg.QueryResult>;
export declare function initializeDatabase(): Promise<void>;
export declare function closeDatabase(): Promise<void>;
//# sourceMappingURL=client.d.ts.map