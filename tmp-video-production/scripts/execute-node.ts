/**
 * Execute Node CLI
 *
 * Executes a single node in a pipeline.
 *
 * Usage:
 *   pnpm exec:node <pipeline-id> <node-id>
 *
 * Example:
 *   pnpm exec:node test-merge merged
 */

import "dotenv/config";
import { getNode } from "../db-executors";
import { executeMergeVideos } from "../executors/merge-videos";
import { closePool } from "@/lib/db";

async function main() {
  const args = process.argv.slice(2);

  if (args.length !== 2) {
    console.error("Usage: pnpm exec:node <pipeline-id> <node-id>");
    console.error("Example: pnpm exec:node test-merge merged");
    process.exit(1);
  }

  const [pipelineId, nodeId] = args;

  try {
    // Load node to determine type
    const node = await getNode(pipelineId, nodeId);

    if (!node) {
      throw new Error(`Node not found: ${pipelineId}/${nodeId}`);
    }

    // Dispatch to appropriate executor
    switch (node.type) {
      case "merge-videos":
        await executeMergeVideos(pipelineId, nodeId);
        break;

      case "asset":
        break;

      case "talking-head":
      case "generate-animation":
      case "generate-voiceover":
      case "render-code":
      case "mix-audio":
      case "compose-video":
        throw new Error(`Executor not yet implemented for node type: ${node.type}`);

      default:
        throw new Error(`Unknown node type: ${node.type}`);
    }

    process.exit(0);
  } catch (error) {
    console.error("\n" + "=".repeat(60));
    console.error("Execution FAILED!");
    console.error("=".repeat(60));

    if (error instanceof Error) {
      console.error("\nError:", error.message);
      if (error.stack !== null && error.stack !== undefined) {
        console.error("\nStack trace:");
        console.error(error.stack);
      }
    } else {
      console.error("\nError:", String(error));
    }

    console.error("\n" + "=".repeat(60) + "\n");

    process.exit(1);
  } finally {
    // Close database connection
    await closePool();
  }
}

void main();
