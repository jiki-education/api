/**
 * Database Connection Pool
 *
 * Provides a PostgreSQL connection pool for the entire application.
 * Automatically initializes schema on first access.
 *
 * Usage:
 *   import { getPool, query } from '@/lib/db';
 *   const result = await query('SELECT * FROM pipelines WHERE id = $1', ['pipeline-1']);
 */

import { Pool } from "pg";
import { createSchema } from "./db-migrations";

let pool: Pool | null = null;
let schemaInitialized = false;

/**
 * Gets the singleton database connection pool
 * Reads connection string from DATABASE_URL environment variable
 */
export function getPool(): Pool {
  if (pool) {
    return pool;
  }

  const connectionString = process.env.DATABASE_URL;

  if (connectionString === undefined || connectionString === "") {
    throw new Error(
      "DATABASE_URL environment variable is not set. Please create a .env file with DATABASE_URL=postgresql://localhost:5432/jiki_video_pipelines"
    );
  }

  // Create connection pool
  pool = new Pool({
    connectionString,
    max: 20, // Maximum number of clients in the pool
    idleTimeoutMillis: 30000, // Close idle clients after 30 seconds
    connectionTimeoutMillis: 2000 // Return an error after 2 seconds if unable to connect
  });

  console.log("✓ PostgreSQL connection pool created");

  return pool;
}

/**
 * Initializes the database schema
 * This is called automatically on first query, but can be called manually for initialization scripts
 */
export async function initializeSchema(): Promise<void> {
  if (schemaInitialized) {
    return;
  }

  const pool = getPool();
  await createSchema(pool);
  schemaInitialized = true;
}

/**
 * Helper function for executing parameterized queries
 * Automatically initializes schema on first use
 */
export async function query<T = unknown>(text: string, params?: unknown[]): Promise<T[]> {
  if (!schemaInitialized) {
    await initializeSchema();
  }

  const pool = getPool();
  const result = await pool.query(text, params);
  return result.rows as T[];
}

/**
 * Closes the database connection pool
 * Typically only needed for graceful shutdown or testing
 */
export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
    schemaInitialized = false;
    console.log("✓ PostgreSQL connection pool closed");
  }
}

/**
 * Resets the connection pool (for testing)
 */
export function resetPool(): void {
  pool = null;
  schemaInitialized = false;
}
