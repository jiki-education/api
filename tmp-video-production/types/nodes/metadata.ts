/**
 * Node Input Configuration Metadata
 *
 * Defines input specifications for each node type, including connection limits,
 * ordering requirements, and display labels.
 */

import type { NodeType } from "./types";

export interface InputConfig {
  maxConnections: number; // -1 = unlimited, 0 = no inputs, 1+ = specific limit
  ordered: boolean; // true = order matters (e.g., video segments)
  label: string; // Display name for the input
  required: boolean; // true = must have at least 1 connection
}

/**
 * Input configuration for each node type
 *
 * This metadata drives:
 * - React Flow connection validation
 * - Visual handle rendering
 * - Input reordering UI (for ordered inputs)
 */
export const NODE_INPUT_CONFIG: Record<NodeType, Record<string, InputConfig>> = {
  asset: {
    // No inputs - assets are source nodes
  },

  "talking-head": {
    script: {
      maxConnections: 1,
      ordered: false,
      label: "Script",
      required: false // Optional - can generate from config
    }
  },

  "generate-animation": {
    prompt: {
      maxConnections: 1,
      ordered: false,
      label: "Prompt",
      required: false // Can use config-based prompt instead
    },
    referenceImage: {
      maxConnections: 1,
      ordered: false,
      label: "Reference Image",
      required: false // Optional reference
    }
  },

  "generate-voiceover": {
    script: {
      maxConnections: 1,
      ordered: false,
      label: "Script",
      required: true
    }
  },

  "render-code": {
    config: {
      maxConnections: 1,
      ordered: false,
      label: "Config",
      required: true // Must reference Remotion config asset
    }
  },

  "mix-audio": {
    video: {
      maxConnections: 1,
      ordered: false,
      label: "Video",
      required: true
    },
    audio: {
      maxConnections: 1,
      ordered: false,
      label: "Audio",
      required: true
    }
  },

  "merge-videos": {
    segments: {
      maxConnections: -1, // Unlimited
      ordered: true, // Order determines video sequence
      label: "Video Segments",
      required: true // Need at least 2 segments to merge
    }
  },

  "compose-video": {
    background: {
      maxConnections: 1,
      ordered: false,
      label: "Background",
      required: true
    },
    overlay: {
      maxConnections: 1,
      ordered: false,
      label: "Overlay",
      required: true // PiP overlay video
    }
  }
};

/**
 * Get input configuration for a specific node type
 */
export function getNodeInputConfig(nodeType: NodeType): Record<string, InputConfig> {
  return NODE_INPUT_CONFIG[nodeType] ?? {};
}

/**
 * Check if a node type has any inputs
 */
export function hasInputs(nodeType: NodeType): boolean {
  const config = getNodeInputConfig(nodeType);
  return Object.keys(config).length > 0;
}

/**
 * Get the maximum number of connections allowed for a specific input
 */
export function getMaxConnections(nodeType: NodeType, inputKey: string): number {
  const config = getNodeInputConfig(nodeType);
  return config[inputKey]?.maxConnections ?? 1; // Default to 1 if not specified
}

/**
 * Check if an input allows unlimited connections
 */
export function isUnlimitedInput(nodeType: NodeType, inputKey: string): boolean {
  return getMaxConnections(nodeType, inputKey) === -1;
}

/**
 * Check if an input's order matters
 */
export function isOrderedInput(nodeType: NodeType, inputKey: string): boolean {
  const config = getNodeInputConfig(nodeType);
  return config[inputKey]?.ordered ?? false;
}
