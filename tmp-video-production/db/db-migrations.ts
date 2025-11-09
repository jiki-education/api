/**
 * Database Schema Migrations
 *
 * Creates the PostgreSQL schema for pipeline orchestration.
 * This module is idempotent - safe to run multiple times.
 */

import type { Pool } from "pg";

/**
 * Creates the database schema if it doesn't exist
 */
export async function createSchema(pool: Pool): Promise<void> {
  const client = await pool.connect();

  try {
    // Create pipelines table
    await client.query(`
      CREATE TABLE IF NOT EXISTS pipelines (
        id TEXT PRIMARY KEY,
        version TEXT NOT NULL DEFAULT '1.0',
        title TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
        config JSONB NOT NULL,      -- { storage: {...}, workingDirectory: "..." }
        metadata JSONB NOT NULL     -- { totalCost, estimatedTotalCost, progress: {...} }
      )
    `);

    // Create nodes table with composite primary key
    await client.query(`
      CREATE TABLE IF NOT EXISTS nodes (
        id TEXT NOT NULL,
        pipeline_id TEXT NOT NULL,
        title TEXT NOT NULL,       -- Display title for the node

        -- Structure (editable by UI)
        type TEXT NOT NULL,        -- 'asset', 'render-code', 'talking-head', etc.
        inputs JSONB NOT NULL,     -- { "config": "code_config", "segments": ["a", "b"] }
        config JSONB NOT NULL,     -- { provider: "remotion", compositionId: "..." }
        asset JSONB,               -- For asset nodes: { source: "...", type: "..." }

        -- Execution state (editable by Executor only)
        status TEXT NOT NULL DEFAULT 'pending',  -- 'pending'|'in_progress'|'completed'|'failed'
        metadata JSONB,            -- { startedAt, completedAt, jobId, cost, retries }
        output JSONB,              -- { type, localFile, s3Key, duration, size }

        PRIMARY KEY (pipeline_id, id),
        FOREIGN KEY (pipeline_id) REFERENCES pipelines(id) ON DELETE CASCADE
      )
    `);

    // Create indexes for fast queries
    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_nodes_status
      ON nodes(pipeline_id, status)
    `);

    await client.query(`
      CREATE INDEX IF NOT EXISTS idx_pipelines_updated
      ON pipelines(updated_at DESC)
    `);

    console.log("✓ Database schema created successfully");
  } finally {
    client.release();
  }
}

/**
 * Drops all tables (use for testing/reset)
 */
export async function dropSchema(pool: Pool): Promise<void> {
  const client = await pool.connect();

  try {
    await client.query("DROP TABLE IF EXISTS nodes CASCADE");
    await client.query("DROP TABLE IF NOT EXISTS pipelines CASCADE");
    console.log("✓ Database schema dropped");
  } finally {
    client.release();
  }
}
