import Database from 'better-sqlite3';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { config } from '../config.js';
const __dirname = dirname(fileURLToPath(import.meta.url));
let db;
export function getDb() {
    if (!db) {
        throw new Error('Database not initialized. Call initializeDatabase() first.');
    }
    return db;
}
export async function initializeDatabase() {
    db = new Database(config.databasePath);
    db.pragma('journal_mode = WAL');
    db.pragma('foreign_keys = ON');
    const migrationPath = join(__dirname, 'migrations', '001_init.sql');
    const migration = readFileSync(migrationPath, 'utf-8');
    db.exec(migration);
    console.log('Database initialized successfully');
}
//# sourceMappingURL=client.js.map