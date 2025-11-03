/**
 * Type-Safe Node Discriminated Unions
 *
 * These types represent the domain model for pipeline nodes.
 * Each node type has specific inputs and config schemas.
 *
 * Design: Using discriminated unions allows TypeScript to narrow types
 * based on the `type` field, giving us compile-time safety when working
 * with different node types.
 */

import type { NodeStatus, NodeMetadata, NodeOutput, AssetConfig } from "@/lib/types";

// ============================================================================
// Base Node Interface
// ============================================================================

interface BaseNode {
  id: string;
  pipelineId: string;
  title: string; // Display title for the node
  status: NodeStatus;
  metadata: NodeMetadata | null;
  output: NodeOutput | null;
}

// ============================================================================
// Specific Node Types
// ============================================================================

export interface AssetNode extends BaseNode {
  type: "asset";
  inputs: Record<string, never>; // Assets have no inputs
  config: Record<string, unknown>;
  asset: AssetConfig;
}

export interface TalkingHeadNode extends BaseNode {
  type: "talking-head";
  inputs: {
    script?: string[]; // Reference to asset node with script
  };
  config: {
    provider: string; // e.g., "heygen", "elevenlabs"
    avatarId?: string;
    voice?: string;
    [key: string]: unknown; // Allow provider-specific config
  };
}

export interface GenerateAnimationNode extends BaseNode {
  type: "generate-animation";
  inputs: {
    prompt?: string[]; // Reference to asset node with prompt
    referenceImage?: string[]; // Optional reference image
  };
  config: {
    provider: string; // e.g., "veo3", "runway"
    duration?: number;
    aspectRatio?: string;
    [key: string]: unknown;
  };
}

export interface GenerateVoiceoverNode extends BaseNode {
  type: "generate-voiceover";
  inputs: {
    script?: string[]; // Reference to asset node with script
  };
  config: {
    provider: string; // e.g., "elevenlabs", "heygen"
    voice?: string;
    speed?: number;
    [key: string]: unknown;
  };
}

export interface RenderCodeNode extends BaseNode {
  type: "render-code";
  inputs: {
    config?: string[]; // Reference to asset node with Remotion config JSON
  };
  config: {
    provider: string; // e.g., "remotion"
    compositionId?: string;
    [key: string]: unknown;
  };
}

export interface MixAudioNode extends BaseNode {
  type: "mix-audio";
  inputs: {
    video?: string[]; // Reference to video node
    audio?: string[]; // Reference to audio node
  };
  config: {
    provider: string; // e.g., "ffmpeg"
    mode?: "replace" | "overlay";
    volume?: number;
    [key: string]: unknown;
  };
}

export interface MergeVideosNode extends BaseNode {
  type: "merge-videos";
  inputs: {
    segments?: string[]; // Array of video node references
  };
  config: {
    provider: string; // e.g., "ffmpeg"
    transitions?: string;
    [key: string]: unknown;
  };
}

export interface ComposeVideoNode extends BaseNode {
  type: "compose-video";
  inputs: {
    background?: string[]; // Background video
    overlay?: string[]; // Overlay video (e.g., talking head)
  };
  config: {
    provider: string; // e.g., "ffmpeg"
    position?: string; // e.g., "bottom-right"
    scale?: number;
    [key: string]: unknown;
  };
}

// ============================================================================
// Discriminated Union
// ============================================================================

/**
 * Node is a discriminated union of all node types.
 * TypeScript can narrow the type based on the `type` field.
 *
 * Example:
 *   function handleNode(node: Node) {
 *     if (node.type === 'talking-head') {
 *       // TypeScript knows node is TalkingHeadNode here
 *       console.log(node.config.provider);
 *     }
 *   }
 */
export type Node =
  | AssetNode
  | TalkingHeadNode
  | GenerateAnimationNode
  | GenerateVoiceoverNode
  | RenderCodeNode
  | MixAudioNode
  | MergeVideosNode
  | ComposeVideoNode;

/**
 * Extract the type field from all node types
 */
export type NodeType = Node["type"];

// ============================================================================
// Type Guards
// ============================================================================

export function isAssetNode(node: Node): node is AssetNode {
  return node.type === "asset";
}

export function isTalkingHeadNode(node: Node): node is TalkingHeadNode {
  return node.type === "talking-head";
}

export function isGenerateAnimationNode(node: Node): node is GenerateAnimationNode {
  return node.type === "generate-animation";
}

export function isGenerateVoiceoverNode(node: Node): node is GenerateVoiceoverNode {
  return node.type === "generate-voiceover";
}

export function isRenderCodeNode(node: Node): node is RenderCodeNode {
  return node.type === "render-code";
}

export function isMixAudioNode(node: Node): node is MixAudioNode {
  return node.type === "mix-audio";
}

export function isMergeVideosNode(node: Node): node is MergeVideosNode {
  return node.type === "merge-videos";
}

export function isComposeVideoNode(node: Node): node is ComposeVideoNode {
  return node.type === "compose-video";
}
