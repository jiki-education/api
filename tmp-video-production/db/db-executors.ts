/**
 * Database Functions for Executor
 *
 * Functions for updating node execution state (status, metadata, output).
 * These are called by node executors during pipeline execution.
 *
 * IMPORTANT: All updates use JSONB partial updates (jsonb_set) to preserve
 * other fields that may be updated by UI or other processes concurrently.
 */

import { getPool } from "@/lib/db";
import type { Node, NodeOutput } from "@/lib/types";

/**
 * Marks a node as started (in_progress)
 *
 * Updates:
 * - status: 'in_progress'
 * - metadata.startedAt: NOW()
 *
 * @param pipelineId - The pipeline ID
 * @param nodeId - The node ID
 */
export async function setNodeStarted(pipelineId: string, nodeId: string): Promise<void> {
  const pool = getPool();

  await pool.query(
    `
    UPDATE nodes
    SET
      status = 'in_progress',
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('startedAt', NOW())
    WHERE pipeline_id = $1 AND id = $2
  `,
    [pipelineId, nodeId]
  );
}

/**
 * Marks a node as completed with output
 *
 * Updates:
 * - status: 'completed'
 * - metadata.completedAt: NOW()
 * - output: full output object
 *
 * @param pipelineId - The pipeline ID
 * @param nodeId - The node ID
 * @param output - The node output
 */
export async function setNodeCompleted(pipelineId: string, nodeId: string, output: NodeOutput): Promise<void> {
  const pool = getPool();

  await pool.query(
    `
    UPDATE nodes
    SET
      status = 'completed',
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object('completedAt', NOW()),
      output = $3
    WHERE pipeline_id = $1 AND id = $2
  `,
    [pipelineId, nodeId, output]
  );
}

/**
 * Marks a node as failed with error message
 *
 * Updates:
 * - status: 'failed'
 * - metadata.completedAt: NOW()
 * - metadata.error: error message
 *
 * @param pipelineId - The pipeline ID
 * @param nodeId - The node ID
 * @param error - The error message
 */
export async function setNodeFailed(pipelineId: string, nodeId: string, error: string): Promise<void> {
  const pool = getPool();

  await pool.query(
    `
    UPDATE nodes
    SET
      status = 'failed',
      metadata = COALESCE(metadata, '{}'::jsonb) || jsonb_build_object(
        'completedAt', NOW(),
        'error', $3
      )
    WHERE pipeline_id = $1 AND id = $2
  `,
    [pipelineId, nodeId, error]
  );

  console.error(`[DB] Node failed: ${pipelineId}/${nodeId} - ${error}`);
}

/**
 * Gets a node from the database
 *
 * @param pipelineId - The pipeline ID
 * @param nodeId - The node ID
 * @returns The node or null if not found
 */
export async function getNode(pipelineId: string, nodeId: string): Promise<Node | null> {
  const pool = getPool();

  const result = await pool.query(
    `
    SELECT * FROM nodes
    WHERE pipeline_id = $1 AND id = $2
  `,
    [pipelineId, nodeId]
  );

  if (result.rows.length === 0) {
    return null;
  }

  return result.rows[0] as Node;
}

/**
 * Gets multiple nodes by their IDs
 *
 * @param pipelineId - The pipeline ID
 * @param nodeIds - Array of node IDs
 * @returns Array of nodes (in same order as nodeIds)
 */
export async function getNodes(pipelineId: string, nodeIds: string[]): Promise<Node[]> {
  const pool = getPool();

  const result = await pool.query(
    `
    SELECT * FROM nodes
    WHERE pipeline_id = $1 AND id = ANY($2::text[])
  `,
    [pipelineId, nodeIds]
  );

  // Return in same order as input nodeIds
  const nodesMap = new Map<string, Node>();
  for (const row of result.rows) {
    nodesMap.set(row.id, row as Node);
  }

  return nodeIds.map((id) => nodesMap.get(id)).filter((node): node is Node => node !== undefined);
}
