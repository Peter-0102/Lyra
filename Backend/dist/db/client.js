import pg from 'pg';
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { config } from '../config.js';
const __dirname = dirname(fileURLToPath(import.meta.url));
let pool;
export function getPool() {
    if (!pool) {
        throw new Error('Database not initialized. Call initializeDatabase() first.');
    }
    return pool;
}
export async function query(text, params) {
    return getPool().query(text, params);
}
export async function initializeDatabase() {
    pool = new pg.Pool({
        connectionString: config.databaseUrl,
        max: 10,
    });
    await runMigrations();
    console.log('Database initialized successfully');
}
async function runMigrations() {
    const client = await pool.connect();
    try {
        await client.query(`
      CREATE TABLE IF NOT EXISTS _migrations (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      )
    `);
        const migrationsDir = join(__dirname, 'migrations');
        const files = readdirSync(migrationsDir)
            .filter(f => f.endsWith('.sql'))
            .sort();
        const { rows: applied } = await client.query('SELECT name FROM _migrations');
        const appliedNames = new Set(applied.map((r) => r.name));
        for (const file of files) {
            if (appliedNames.has(file)) {
                console.log(`Migration already applied: ${file}`);
                continue;
            }
            const sql = readFileSync(join(migrationsDir, file), 'utf-8');
            console.log(`Applying migration: ${file}`);
            await client.query(sql);
            await client.query('INSERT INTO _migrations (name) VALUES ($1)', [file]);
            console.log(`Migration applied: ${file}`);
        }
    }
    finally {
        client.release();
    }
}
export async function closeDatabase() {
    if (pool) {
        await pool.end();
        pool = undefined;
    }
}
//# sourceMappingURL=client.js.map