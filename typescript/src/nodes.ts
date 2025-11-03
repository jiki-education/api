/**
 * Video Production Node Types
 * Auto-generated from Rails schemas
 * DO NOT EDIT MANUALLY
 *
 * Source: app/commands/video_production/node/schemas/
 */

// ============================================================================
// Video Production Node Types
// ============================================================================

/** Asset node type (inputs + config) */
export type AssetNode = {
  type: 'asset';
  inputs: {};
  config: {};
};

/** ComposeVideo node type (inputs + config) */
export type ComposeVideoNode = {
  type: 'compose-video';
  inputs: {
    background: string;
    overlay: string;
  };
  config: {
      rounded: boolean;
      cropTop?: number;
      cropLeft?: number;
      cropWidth?: number;
      cropHeight?: number;
      provider: 'ffmpeg';
    };
};

/** GenerateAnimation node type (inputs + config) */
export type GenerateAnimationNode = {
  type: 'generate-animation';
  inputs: {
    prompt?: string;
    referenceImage?: string;
  };
  config: {
      provider: 'veo3' | 'runway' | 'stability';
    };
};

/** GenerateTalkingHead node type (inputs + config) */
export type GenerateTalkingHeadNode = {
  type: 'generate-talking-head';
  inputs: {
    audio: string;
    background?: string;
  };
  config: {
      provider: 'heygen';
      avatarId: string;
      width?: number;
      height?: number;
    };
};

/** GenerateVoiceover node type (inputs + config) */
export type GenerateVoiceoverNode = {
  type: 'generate-voiceover';
  inputs: {
    script?: string;
  };
  config: {
      provider: 'elevenlabs';
    };
};

/** MergeVideos node type (inputs + config) */
export type MergeVideosNode = {
  type: 'merge-videos';
  inputs: {
    segments: string[];
  };
  config: {
      provider: 'ffmpeg';
    };
};

/** MixAudio node type (inputs + config) */
export type MixAudioNode = {
  type: 'mix-audio';
  inputs: {
    video: string;
    audio: string;
  };
  config: {
      provider: 'ffmpeg';
    };
};

/** RenderCode node type (inputs + config) */
export type RenderCodeNode = {
  type: 'render-code';
  inputs: {
    config?: string;
  };
  config: {
      provider: 'remotion';
    };
};

// ============================================================================
// Union Type for All Nodes
// ============================================================================

/** Union type of all video production node types */
export type VideoProductionNode =
    AssetNode
  | ComposeVideoNode
  | GenerateAnimationNode
  | GenerateTalkingHeadNode
  | GenerateVoiceoverNode
  | MergeVideosNode
  | MixAudioNode
  | RenderCodeNode
;
