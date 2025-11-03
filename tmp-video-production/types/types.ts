/**
 * Database Types for Jiki Pipeline System
 *
 * These types represent the SQLite schema for pipeline orchestration.
 * Structure fields (type, inputs, config) are edited by the UI.
 * State fields (status, metadata, output) are edited by the Executor.
 */

// ============================================================================
// Pipeline Types
// ============================================================================

export interface Pipeline {
  id: string;
  version: string;
  title: string;
  created_at: Date;
  updated_at: Date;
  config: PipelineConfig;
  metadata: PipelineMetadata;
}

export interface PipelineConfig {
  storage?: {
    bucket: string;
    prefix: string;
  };
  workingDirectory?: string;
  [key: string]: unknown; // Allow additional config fields
}

export interface PipelineMetadata {
  totalCost: number;
  estimatedTotalCost: number;
  progress: {
    completed: number;
    in_progress: number;
    pending: number;
    failed: number;
    total: number;
  };
  [key: string]: unknown; // Allow additional metadata fields
}

// ============================================================================
// Node Types
// ============================================================================

export type NodeStatus = "pending" | "in_progress" | "completed" | "failed";

export type NodeType =
  | "asset"
  | "talking-head"
  | "generate-animation"
  | "generate-voiceover"
  | "render-code"
  | "mix-audio"
  | "merge-videos"
  | "compose-video";

export interface Node {
  id: string;
  pipeline_id: string;
  title: string; // Display title for the node

  // Structure (editable by UI)
  type: NodeType;
  inputs: NodeInputs;
  config: NodeConfig;
  asset?: AssetConfig;

  // Execution state (editable by Executor only)
  status: NodeStatus;
  metadata: NodeMetadata | null;
  output: NodeOutput | null;
}

// Node inputs can be single node references or arrays of node references
export interface NodeInputs {
  [key: string]: string | string[];
}

// Node config varies by type and provider
export interface NodeConfig {
  provider?: string;
  [key: string]: unknown;
}

// Asset nodes reference external files
export interface AssetConfig {
  source: string;
  type: "text" | "json" | "image" | "video" | "audio";
}

// Metadata tracks execution details
export interface NodeMetadata {
  startedAt?: Date;
  completedAt?: Date;
  jobId?: string; // External service job ID
  cost?: number;
  retries?: number;
  error?: string;
  [key: string]: unknown;
}

// Output tracks generated artifacts
export interface NodeOutput {
  type: "text" | "json" | "image" | "video" | "audio";
  localFile?: string;
  s3Key?: string;
  duration?: number; // For video/audio
  size?: number; // File size in bytes
  [key: string]: unknown;
}

// ============================================================================
// Input Types for Database Operations
// ============================================================================

// For createNode - only structure fields
export interface CreateNodeInput {
  id: string;
  type: NodeType;
  inputs: NodeInputs;
  config: NodeConfig;
  asset?: AssetConfig;
}

// For updateNodeConfig
export interface UpdateNodeConfigInput {
  config: NodeConfig;
}

// For updateNodeType
export interface UpdateNodeTypeInput {
  type: NodeType;
}

// ============================================================================
// Remotion Code Screen Types (for src/components/AnimatedCode.tsx)
// ============================================================================

export type TypingSpeed = "slow" | "normal" | "fast";

export const CHARS_PER_SECOND: Record<TypingSpeed, number> = {
  slow: 10,
  normal: 15,
  fast: 25
};

export interface TypeAction {
  type: "type";
  code: string;
  speed: TypingSpeed | TypingSpeed[];
  language?: string;
}

export interface PauseAction {
  type: "pause";
  duration: number;
}

export type Action = TypeAction | PauseAction;

export interface SceneConfig {
  title: string;
  theme?: "dark" | "light";
  backgroundColor?: string;
  actions: Action[];
}
