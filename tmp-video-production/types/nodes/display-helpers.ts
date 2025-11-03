/**
 * Node Display Helper Functions
 *
 * Utilities for formatting node display information, determining output types,
 * and mapping data types to visual attributes (colors, icons, etc.)
 */

import type { Node, NodeType } from "./types";
import type { NodeOutput } from "@/lib/types";

// ============================================================================
// Output Type Detection
// ============================================================================

/**
 * Determines the data type of a node's output based on its type and config
 */
export function getOutputDataType(node: Node): "video" | "image" | "audio" | "text" | "json" | "unknown" {
  // If node has output, use that
  if (node.output?.type != null) {
    return node.output.type as "video" | "image" | "audio" | "text" | "json";
  }

  // Otherwise infer from node type
  switch (node.type) {
    case "asset":
      if (node.asset != null) {
        return node.asset.type as "video" | "image" | "audio" | "text" | "json";
      }
      return "unknown";

    case "talking-head":
    case "generate-animation":
    case "render-code":
    case "merge-videos":
    case "compose-video":
      return "video";

    case "generate-voiceover":
    case "mix-audio":
      return "audio";

    default:
      return "unknown";
  }
}

/**
 * Determines the data type for a specific input handle
 */
export function getInputDataType(
  nodeType: NodeType,
  inputKey: string
): "video" | "image" | "audio" | "text" | "json" | "generic" {
  // Map input keys to their expected data types
  const inputTypeMap: Record<NodeType, Record<string, "video" | "image" | "audio" | "text" | "json" | "generic">> = {
    asset: {},
    "talking-head": {
      script: "text"
    },
    "generate-animation": {
      prompt: "text",
      referenceImage: "image"
    },
    "generate-voiceover": {
      script: "text"
    },
    "render-code": {
      config: "json"
    },
    "mix-audio": {
      video: "video",
      audio: "audio"
    },
    "merge-videos": {
      segments: "video"
    },
    "compose-video": {
      background: "video",
      overlay: "video"
    }
  };

  return inputTypeMap[nodeType]?.[inputKey] || "generic";
}

// ============================================================================
// Color Mapping
// ============================================================================

/**
 * Returns background color value for handle based on data type
 */
export function getHandleColorValue(
  dataType: "video" | "image" | "audio" | "text" | "json" | "generic" | "unknown"
): string {
  const colorMap = {
    video: "#a855f7", // purple-500
    image: "#22c55e", // green-500
    audio: "#f97316", // orange-500
    text: "#3b82f6", // blue-500
    json: "#3b82f6", // blue-500
    generic: "#6b7280", // gray-500
    unknown: "#9ca3af" // gray-400
  };

  return colorMap[dataType];
}

/**
 * Returns Tailwind CSS classes for handle colors based on data type
 */
export function getHandleColor(
  dataType: "video" | "image" | "audio" | "text" | "json" | "generic" | "unknown"
): string {
  const colorMap = {
    video: "bg-purple-500 hover:bg-purple-600",
    image: "bg-green-500 hover:bg-green-600",
    audio: "bg-orange-500 hover:bg-orange-600",
    text: "bg-blue-500 hover:bg-blue-600",
    json: "bg-blue-500 hover:bg-blue-600",
    generic: "bg-gray-500 hover:bg-gray-600",
    unknown: "bg-gray-400 hover:bg-gray-500"
  };

  return colorMap[dataType];
}

/**
 * Returns color value for output handle based on node's output type
 */
export function getOutputHandleColorValue(node: Node): string {
  const dataType = getOutputDataType(node);
  return getHandleColorValue(dataType);
}

/**
 * Returns color value for input handle
 */
export function getInputHandleColorValue(nodeType: NodeType, inputKey: string): string {
  const dataType = getInputDataType(nodeType, inputKey);
  return getHandleColorValue(dataType);
}

/**
 * Returns Tailwind CSS classes for output handle colors based on node's output type
 */
export function getOutputHandleColor(node: Node): string {
  const dataType = getOutputDataType(node);
  return getHandleColor(dataType);
}

/**
 * Returns Tailwind CSS classes for input handle colors
 */
export function getInputHandleColor(nodeType: NodeType, inputKey: string): string {
  const dataType = getInputDataType(nodeType, inputKey);
  return getHandleColor(dataType);
}

// ============================================================================
// Display Name Formatting
// ============================================================================

/**
 * Formats a node's type and provider into a display string
 * Example: "Talking Head - HeyGen", "Image Generation - Veo 3"
 */
export function getNodeDisplayName(node: Node): string {
  const typeNames: Record<NodeType, string> = {
    asset: "Asset",
    "talking-head": "Talking Head",
    "generate-animation": "Animation Generation",
    "generate-voiceover": "Voiceover Generation",
    "render-code": "Code Screen",
    "mix-audio": "Audio Mixing",
    "merge-videos": "Video Merging",
    "compose-video": "Video Composition"
  };

  const typeName = typeNames[node.type] ?? node.type;
  const provider = node.config.provider;

  if (provider != null && provider !== "") {
    // Capitalize provider name
    const providerName = (provider as string).charAt(0).toUpperCase() + (provider as string).slice(1);
    return `${typeName} - ${providerName}`;
  }

  return typeName;
}

// ============================================================================
// Output Preview
// ============================================================================

/**
 * Gets the URL for an output preview (thumbnail, audio file, etc.)
 */
export function getOutputPreviewUrl(output: NodeOutput | null): string | null {
  if (output == null) return null;

  // Check for S3 URL first
  if (output.s3Key != null && output.s3Key !== "") {
    return output.s3Key as string;
  }

  // Check for local file
  if (output.localFile != null && output.localFile !== "") {
    return output.localFile as string;
  }

  // Check for url in output
  if (output.url != null && output.url !== "") {
    return output.url as string;
  }

  return null;
}

/**
 * Checks if an output has a previewable URL
 */
export function hasOutputPreview(output: NodeOutput | null): boolean {
  return getOutputPreviewUrl(output) !== null;
}
