/**
 * Atomic Database Operations
 *
 * Each function performs a single, well-defined operation on the database.
 * These functions are wrapped by Server Actions in app/pipelines/[id]/actions.ts.
 *
 * Design principles:
 * - Single responsibility: Each function does one thing
 * - Atomic: All operations use PostgreSQL transactions
 * - Preserves state: Structure updates never touch execution state
 * - Type safe: All parameters strongly typed
 */

import { getPool } from "./db";
import type { CreateNodeInput, Node, NodeInputs } from "./types";

// ============================================================================
// Node Operations
// ============================================================================

/**
 * Creates a new node in the pipeline
 *
 * @param pipelineId - The pipeline ID
 * @param node - Node structure (id, type, inputs, config, asset)
 * @returns The created node
 *
 * Example:
 *   await createNode('lesson-001', {
 *     id: 'code_screen',
 *     type: 'render-code',
 *     inputs: { config: 'code_config' },
 *     config: { provider: 'remotion', compositionId: 'code-scene' }
 *   })
 */
export async function createNode(pipelineId: string, node: CreateNodeInput): Promise<Node> {
  const pool = getPool();

  // Validate pipeline exists
  const pipelineCheck = await pool.query("SELECT id FROM pipelines WHERE id = $1", [pipelineId]);

  if (pipelineCheck.rows.length === 0) {
    throw new Error(`Pipeline not found: ${pipelineId}`);
  }

  // Validate node doesn't already exist
  const nodeCheck = await pool.query("SELECT id FROM nodes WHERE pipeline_id = $1 AND id = $2", [pipelineId, node.id]);

  if (nodeCheck.rows.length > 0) {
    throw new Error(`Node already exists: ${pipelineId}/${node.id}`);
  }

  // Insert node with default status='pending'
  const result = await pool.query(
    `
    INSERT INTO nodes (
      id, pipeline_id, type, inputs, config, asset, status, metadata, output
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    RETURNING *
  `,
    [
      node.id,
      pipelineId,
      node.type,
      node.inputs, // JSONB - no need to stringify
      node.config,
      node.asset || null,
      "pending",
      null,
      null
    ]
  );

  // Update pipeline timestamp
  await pool.query("UPDATE pipelines SET updated_at = NOW() WHERE id = $1", [pipelineId]);

  return result.rows[0] as Node;
}

/**
 * Deletes a node from the pipeline
 *
 * Also cleans up references to this node in other nodes' inputs.
 * For single-value inputs: removes the entire input key.
 * For array inputs: removes the node ID from the array.
 *
 * @param pipelineId - The pipeline ID
 * @param nodeId - The node ID to delete
 *
 * Example:
 *   await deleteNode('lesson-001', 'code_screen')
 */
export async function deleteNode(pipelineId: string, nodeId: string): Promise<void> {
  const pool = getPool();
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    // 1. Get all nodes in the pipeline (to clean up references)
    const nodesResult = await client.query("SELECT * FROM nodes WHERE pipeline_id = $1", [pipelineId]);
    const nodes = nodesResult.rows as Node[];

    // 2. Clean up references in other nodes' inputs
    for (const node of nodes) {
      if (node.id === nodeId) continue; // Skip the node being deleted

      const inputs: NodeInputs = node.inputs;
      let modified = false;

      // Check each input
      for (const [key, value] of Object.entries(inputs)) {
        if (typeof value === "string" && value === nodeId) {
          // Single-value input: remove the key
          delete inputs[key];
          modified = true;
        } else if (Array.isArray(value) && value.includes(nodeId)) {
          // Array input: remove this node ID
          inputs[key] = value.filter((id) => id !== nodeId);
          modified = true;
        }
      }

      // Update node if inputs were modified
      if (modified) {
        await client.query("UPDATE nodes SET inputs = $1 WHERE pipeline_id = $2 AND id = $3", [
          inputs,
          pipelineId,
          node.id
        ]);
      }
    }

    // 3. Delete the node
    const deleteResult = await client.query("DELETE FROM nodes WHERE pipeline_id = $1 AND id = $2", [
      pipelineId,
      nodeId
    ]);

    if (deleteResult.rowCount === 0) {
      throw new Error(`Node not found: ${pipelineId}/${nodeId}`);
    }

    // 4. Update pipeline timestamp
    await client.query("UPDATE pipelines SET updated_at = NOW() WHERE id = $1", [pipelineId]);

    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Connects two nodes by appending to the target node's input array
 *
 * Appends sourceNodeId to targetNode.inputs[inputKey] array
 * Prevents duplicate connections to the same input
 *
 * @param pipelineId - The pipeline ID
 * @param sourceNodeId - The source node (providing output)
 * @param targetNodeId - The target node (receiving input)
 * @param inputKey - The input key on the target node
 *
 * Example:
 *   await connectNodes('lesson-001', 'code_config', 'code_screen', 'config')
 *   // Appends 'code_config' to code_screen.inputs.config array
 */
export async function connectNodes(
  pipelineId: string,
  sourceNodeId: string,
  targetNodeId: string,
  inputKey: string
): Promise<void> {
  const pool = getPool();

  // Validate both nodes exist
  const sourceCheck = await pool.query("SELECT id FROM nodes WHERE pipeline_id = $1 AND id = $2", [
    pipelineId,
    sourceNodeId
  ]);

  if (sourceCheck.rows.length === 0) {
    throw new Error(`Source node not found: ${pipelineId}/${sourceNodeId}`);
  }

  const targetResult = await pool.query("SELECT * FROM nodes WHERE pipeline_id = $1 AND id = $2", [
    pipelineId,
    targetNodeId
  ]);

  if (targetResult.rows.length === 0) {
    throw new Error(`Target node not found: ${pipelineId}/${targetNodeId}`);
  }

  // Check if already connected (prevent duplicates)
  const targetNode = targetResult.rows[0];
  const existingInput = targetNode.inputs[inputKey];

  if (Array.isArray(existingInput) && existingInput.includes(sourceNodeId)) {
    // Already connected, no-op
    return;
  }

  // Append to array using jsonb_set with path '{inputKey,-1}'
  // -1 means append to end of array
  // COALESCE ensures we start with empty array if input doesn't exist yet
  await pool.query(
    `
    UPDATE nodes
    SET inputs = jsonb_set(
      inputs,
      $1,
      COALESCE(inputs->$2, '[]'::jsonb) || to_jsonb($3::text),
      true
    )
    WHERE pipeline_id = $4 AND id = $5
  `,
    [
      `{${inputKey}}`, // JSONB path
      inputKey, // Key to get existing array
      sourceNodeId, // Value to append
      pipelineId,
      targetNodeId
    ]
  );

  // Update pipeline timestamp
  await pool.query("UPDATE pipelines SET updated_at = NOW() WHERE id = $1", [pipelineId]);
}

/**
 * Reorders the inputs array for a specific input key on a node
 *
 * Updates the order of node IDs in targetNode.inputs[inputKey] array
 * and sets the node status to 'pending' since the pipeline structure changed.
 *
 * @param pipelineId - The pipeline ID
 * @param nodeId - The node ID to update
 * @param inputKey - The input key containing the array to reorder
 * @param newOrder - The new array of node IDs in desired order
 *
 * Example:
 *   await reorderNodeInputs('lesson-001', 'final_video', 'segments', ['intro', 'body', 'outro'])
 *   // Sets final_video.inputs.segments = ['intro', 'body', 'outro']
 *   // Sets final_video.status = 'pending'
 */
export async function reorderNodeInputs(
  pipelineId: string,
  nodeId: string,
  inputKey: string,
  newOrder: string[]
): Promise<void> {
  const pool = getPool();

  // Validate node exists
  const nodeResult = await pool.query("SELECT * FROM nodes WHERE pipeline_id = $1 AND id = $2", [pipelineId, nodeId]);

  if (nodeResult.rows.length === 0) {
    throw new Error(`Node not found: ${pipelineId}/${nodeId}`);
  }

  const node = nodeResult.rows[0];
  const existingInput = node.inputs[inputKey];

  // Validate that the input key exists and is an array
  if (!Array.isArray(existingInput)) {
    throw new Error(`Input key "${inputKey}" is not an array for node: ${pipelineId}/${nodeId}`);
  }

  // Validate that newOrder contains the same node IDs (just reordered)
  const existingSet = new Set(existingInput);
  const newSet = new Set(newOrder);

  if (existingSet.size !== newSet.size || ![...existingSet].every((id) => newSet.has(id))) {
    throw new Error(
      `New order must contain the same node IDs as existing input. Expected: [${[...existingSet].join(", ")}], Got: [${newOrder.join(", ")}]`
    );
  }

  // Update the input array and set status to pending
  // Using jsonb_set to update only the specific input key
  await pool.query(
    `
    UPDATE nodes
    SET
      inputs = jsonb_set(inputs, $1, $2::jsonb),
      status = 'pending'
    WHERE pipeline_id = $3 AND id = $4
  `,
    [
      `{${inputKey}}`, // JSONB path
      JSON.stringify(newOrder), // New array as JSON
      pipelineId,
      nodeId
    ]
  );

  // Update pipeline timestamp
  await pool.query("UPDATE pipelines SET updated_at = NOW() WHERE id = $1", [pipelineId]);
}
