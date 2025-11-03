/**
 * Video Merger Lambda Function
 *
 * Downloads video segments from S3, concatenates them with FFmpeg,
 * and uploads the result back to S3.
 *
 * Designed to run on AWS Lambda with FFmpeg layer.
 */

import { spawn, ChildProcess } from 'child_process';
import { promises as fs } from 'fs';
import * as fsSync from 'fs';
import * as path from 'path';
import { randomUUID } from 'crypto';
import {
  downloadFromS3,
  uploadToS3,
  cleanupFiles,
  sendCallback,
  type CallbackPayload
} from '@jiki/shared/dist/utils';

/**
 * Lambda event payload structure
 */
interface LambdaEvent {
  input_videos: string[];
  output_bucket: string;
  output_key: string;
  callback_url?: string;
  node_uuid?: string;
  executor_type?: string;
  process_uuid?: string;
}

/**
 * Lambda response structure
 */
interface LambdaResponse {
  statusCode: number;
  error?: string;
}


/**
 * Lambda handler
 *
 * Expected event format:
 * {
 *   input_videos: ["s3://bucket/path1.mp4", "s3://bucket/path2.mp4"],
 *   output_bucket: "jiki-videos",
 *   output_key: "pipelines/123/nodes/456/output.mp4",
 *   callback_url: "http://local.jiki.io:3060/spi/video_production/executor_callback",
 *   node_uuid: "...",
 *   executor_type: "merge-videos"
 * }
 */
export const handler = async (event: LambdaEvent): Promise<LambdaResponse> => {
  const { input_videos, output_bucket, output_key, callback_url, node_uuid, executor_type, process_uuid } = event;

  // Validate inputs
  if (!Array.isArray(input_videos) || input_videos.length < 2) {
    return {
      error: 'At least 2 input videos required',
      statusCode: 400
    };
  }

  if (!output_bucket || !output_key) {
    return {
      error: 'output_bucket and output_key are required',
      statusCode: 400
    };
  }

  const tempDir = '/tmp';
  const inputPaths: string[] = [];
  const outputPath = path.join(tempDir, `output-${randomUUID()}.mp4`);
  const concatFilePath = path.join(tempDir, `concat-${randomUUID()}.txt`);

  try {
    console.error(`[VideoMerger] Processing ${input_videos.length} videos`);

    // 1. Download videos from S3
    for (let i = 0; i < input_videos.length; i++) {
      const s3Url = input_videos[i];
      const localPath = path.join(tempDir, `input-${i}-${randomUUID()}.mp4`);

      console.error(`[VideoMerger] Downloading ${s3Url} to ${localPath}`);
      await downloadFromS3(s3Url, localPath);
      inputPaths.push(localPath);
    }

    // 2. Create FFmpeg concat file
    const concatContent = inputPaths.map(p => `file '${p}'`).join('\n');
    await fs.writeFile(concatFilePath, concatContent, 'utf-8');
    console.error(`[VideoMerger] Created concat file with ${inputPaths.length} videos`);

    // 3. Run FFmpeg to merge videos
    const duration = await mergeVideosWithFFmpeg(concatFilePath, outputPath);
    console.error(`[VideoMerger] Merge completed, duration: ${duration}s`);

    // 4. Get output file stats
    const stats = await fs.stat(outputPath);
    const size = stats.size;

    // 5. Upload to S3
    console.error(`[VideoMerger] Uploading to s3://${output_bucket}/${output_key}`);
    await uploadToS3(outputPath, output_bucket, output_key);

    // 6. Clean up temp files
    await cleanupFiles([...inputPaths, outputPath, concatFilePath]);

    // 7. Callback with success
    if (callback_url) {
      await sendCallback(callback_url, {
        node_uuid: node_uuid,
        executor_type: executor_type,
        process_uuid: process_uuid,
        result: {
          s3_key: output_key,
          duration: duration,
          size: size
        }
      });
    }

    return { statusCode: 200 };

  } catch (error) {
    console.error('[VideoMerger] Error:', error);

    // Clean up on error
    try {
      await cleanupFiles([...inputPaths, outputPath, concatFilePath]);
    } catch (cleanupError) {
      console.warn('[VideoMerger] Cleanup error:', cleanupError);
    }

    // Callback with error
    if (callback_url) {
      await sendCallback(callback_url, {
        node_uuid: node_uuid,
        executor_type: executor_type,
        process_uuid: process_uuid,
        error: error instanceof Error ? error.message : String(error),
        error_type: 'ffmpeg_error'
      });
    }

    return { statusCode: 500 };
  }
};

/**
 * Merge videos using FFmpeg
 * @param {string} concatFilePath - Path to concat demuxer file
 * @param {string} outputPath - Output file path
 * @returns {Promise<number>} Duration in seconds
 */
function mergeVideosWithFFmpeg(concatFilePath: string, outputPath: string): Promise<number> {
  return new Promise((resolve, reject) => {
    // Use bundled FFmpeg binary if available (Lambda), otherwise use system ffmpeg
    // Note: __dirname is 'dist' after compilation, so go up one level to find bin/ffmpeg
    // Also check if we're on Linux (Lambda) vs macOS (local dev) - the bundled binary is Linux-only
    const bundledFfmpeg = path.join(__dirname, '..', 'bin', 'ffmpeg');
    const isLinux = process.platform === 'linux';
    const ffmpegPath = (fsSync.existsSync(bundledFfmpeg) && isLinux)
      ? bundledFfmpeg
      : 'ffmpeg';

    const args = [
      '-f', 'concat',
      '-safe', '0',
      '-i', concatFilePath,
      '-c', 'copy',
      '-y', // Overwrite output file
      outputPath
    ];

    console.error(`[FFmpeg] Running: ${ffmpegPath} ${args.join(' ')}`);

    const ffmpeg: ChildProcess = spawn(ffmpegPath, args);
    let stderr = '';

    ffmpeg.stderr?.on('data', (data: Buffer) => {
      stderr += data.toString();
    });

    ffmpeg.on('close', (code: number | null) => {
      if (code !== 0) {
        console.error('[FFmpeg] stderr:', stderr);
        reject(new Error(`FFmpeg failed with code ${code}`));
        return;
      }

      // Extract duration from FFmpeg output
      const durationMatch = stderr.match(/Duration: (\d{2}):(\d{2}):(\d{2}\.\d{2})/);
      let duration = 0;

      if (durationMatch) {
        const hours = parseInt(durationMatch[1], 10);
        const minutes = parseInt(durationMatch[2], 10);
        const seconds = parseFloat(durationMatch[3]);
        duration = hours * 3600 + minutes * 60 + seconds;
      }

      resolve(duration);
    });

    ffmpeg.on('error', (error: Error) => {
      reject(new Error(`FFmpeg spawn error: ${error.message}`));
    });
  });
}

