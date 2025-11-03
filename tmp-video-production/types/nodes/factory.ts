/**
 * Node Factory Functions
 *
 * Converts between database rows and type-safe Node domain objects.
 *
 * Design: The database stores nodes with a flexible JSONB schema.
 * These factory functions provide a type-safe bridge between DB and application code.
 */

import type { Node as DBNode } from "@/lib/types";
import type { Node } from "./types";

// ============================================================================
// DB → Domain Conversion
// ============================================================================

/**
 * Converts a database node row to a type-safe Node object
 *
 * The database uses snake_case (pipeline_id) but our domain models use camelCase (pipelineId).
 * This function handles the conversion.
 *
 * @param row - Raw database row
 * @returns Type-safe Node object
 *
 * Example:
 *   const dbRow = await pool.query('SELECT * FROM nodes WHERE id = $1', ['node-1']);
 *   const node = nodeFromDB(dbRow.rows[0]);
 *   if (node.type === 'talking-head') {
 *     console.log(node.config.provider); // TypeScript knows this exists
 *   }
 */
export function nodeFromDB(row: DBNode): Node {
  return {
    id: row.id,
    pipelineId: row.pipeline_id,
    title: row.title,
    type: row.type,
    inputs: row.inputs,
    config: row.config,
    ...(row.asset && { asset: row.asset }),
    status: row.status,
    metadata: row.metadata,
    output: row.output
  } as Node;
}

/**
 * Converts multiple database rows to Node objects
 *
 * @param rows - Array of database rows
 * @returns Array of type-safe Node objects
 */
export function nodesFromDB(rows: DBNode[]): Node[] {
  return rows.map(nodeFromDB);
}

// ============================================================================
// Domain → DB Conversion
// ============================================================================

/**
 * Converts a Node domain object to a database row format
 *
 * @param node - Type-safe Node object
 * @returns Database row format (snake_case fields)
 *
 * Example:
 *   const node: TalkingHeadNode = { ... };
 *   const dbRow = nodeToDB(node);
 *   await pool.query('INSERT INTO nodes (...) VALUES (...)', dbRow);
 */
export function nodeToDB(node: Node): DBNode {
  return {
    id: node.id,
    pipeline_id: node.pipelineId,
    title: node.title,
    type: node.type,
    inputs: node.inputs,
    config: node.config,
    ...(node.type === "asset" && { asset: node.asset }),
    status: node.status,
    metadata: node.metadata,
    output: node.output
  };
}

/**
 * Converts multiple Node objects to database row format
 *
 * @param nodes - Array of Node objects
 * @returns Array of database rows
 */
export function nodesToDB(nodes: Node[]): DBNode[] {
  return nodes.map(nodeToDB);
}

// ============================================================================
// Validation Helpers
// ============================================================================

/**
 * Validates a node's inputs based on its type
 *
 * @param node - Node to validate
 * @returns Validation result with errors if any
 *
 * Example:
 *   const result = validateNode(node);
 *   if (!result.valid) {
 *     console.error('Validation errors:', result.errors);
 *   }
 */
export function validateNode(node: Node): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  switch (node.type) {
    case "asset":
      if (node.asset === undefined) {
        errors.push("Asset node missing asset configuration");
      }
      break;

    case "talking-head":
      if (node.config.provider === undefined || node.config.provider === null || node.config.provider === "") {
        errors.push("Talking head node missing provider");
      }
      break;

    case "generate-animation":
      if (node.config.provider === undefined || node.config.provider === null || node.config.provider === "") {
        errors.push("Animation node missing provider");
      }
      break;

    case "generate-voiceover":
      if (node.config.provider === undefined || node.config.provider === null || node.config.provider === "") {
        errors.push("Voiceover node missing provider");
      }
      break;

    case "render-code":
      if (node.config.provider === undefined || node.config.provider === null || node.config.provider === "") {
        errors.push("Render code node missing provider");
      }
      if (node.inputs.config === undefined || node.inputs.config === null || node.inputs.config.length === 0) {
        errors.push("Render code node missing config input");
      }
      break;

    case "mix-audio":
      if (node.config.provider === undefined || node.config.provider === null || node.config.provider === "") {
        errors.push("Mix audio node missing provider");
      }
      if (
        node.inputs.video === undefined ||
        node.inputs.video === null ||
        node.inputs.video.length === 0 ||
        node.inputs.audio === undefined ||
        node.inputs.audio === null ||
        node.inputs.audio.length === 0
      ) {
        errors.push("Mix audio node missing video or audio input");
      }
      break;

    case "merge-videos":
      if (node.config.provider === undefined || node.config.provider === null || node.config.provider === "") {
        errors.push("Merge videos node missing provider");
      }
      if (node.inputs.segments === undefined || node.inputs.segments === null || node.inputs.segments.length === 0) {
        errors.push("Merge videos node missing segments");
      }
      break;

    case "compose-video":
      if (node.config.provider === undefined || node.config.provider === null || node.config.provider === "") {
        errors.push("Compose video node missing provider");
      }
      if (
        node.inputs.background === undefined ||
        node.inputs.background === null ||
        node.inputs.background.length === 0 ||
        node.inputs.overlay === undefined ||
        node.inputs.overlay === null ||
        node.inputs.overlay.length === 0
      ) {
        errors.push("Compose video node missing background or overlay input");
      }
      break;
  }

  return { valid: errors.length === 0, errors };
}
