/**
 * FFmpeg Video Merger
 *
 * Concatenates multiple video files using FFmpeg's concat demuxer.
 */

import { exec } from "child_process";
import { promisify } from "util";
import { writeFile, unlink, stat } from "fs/promises";
import { join } from "path";
import { randomUUID } from "crypto";

const execAsync = promisify(exec);

/**
 * Merges multiple video files into a single output file
 *
 * @param inputPaths - Array of local video file paths (must be same format/codec)
 * @param outputPath - Output file path
 * @returns Object with duration (seconds) and size (bytes)
 */
export async function mergeVideos(
  inputPaths: string[],
  outputPath: string
): Promise<{ duration: number; size: number }> {
  if (inputPaths.length === 0) {
    throw new Error("No input videos provided");
  }

  if (inputPaths.length === 1) {
    throw new Error("At least 2 videos required for merging");
  }

  // Create concat demuxer file list
  const listPath = join(process.cwd(), "tmp", `concat-${randomUUID()}.txt`);
  const listContent = inputPaths.map((path) => `file '${path}'`).join("\n");

  await writeFile(listPath, listContent, "utf-8");

  try {
    // Run FFmpeg concat
    // -f concat: use concat demuxer
    // -safe 0: allow absolute paths
    // -i: input file list
    // -c copy: copy streams without re-encoding (fast)
    const command = `ffmpeg -f concat -safe 0 -i "${listPath}" -c copy "${outputPath}"`;

    const { stderr } = await execAsync(command);

    // Get output file stats
    const stats = await stat(outputPath);

    // Extract duration from FFmpeg output
    const durationMatch = stderr.match(/Duration: (\d{2}):(\d{2}):(\d{2}\.\d{2})/);
    let duration = 0;

    if (durationMatch) {
      const hours = parseInt(durationMatch[1], 10);
      const minutes = parseInt(durationMatch[2], 10);
      const seconds = parseFloat(durationMatch[3]);
      duration = hours * 3600 + minutes * 60 + seconds;
    }

    return {
      duration,
      size: stats.size
    };
  } catch (error) {
    const err = error as Error & { stdout?: string; stderr?: string };
    console.error(`[FFmpeg] Error: ${err.message}`);
    if (err.stderr !== null && err.stderr !== undefined) {
      console.error(`[FFmpeg] stderr:\n${err.stderr}`);
    }
    throw new Error(`FFmpeg merge failed: ${err.message}`);
  } finally {
    // Clean up concat list file
    try {
      await unlink(listPath);
    } catch {
      console.warn(`[FFmpeg] Failed to delete concat list: ${listPath}`);
    }
  }
}

/**
 * Validates that all input videos exist
 *
 * @param inputPaths - Array of local video file paths
 * @throws Error if any file doesn't exist
 */
export async function validateInputVideos(inputPaths: string[]): Promise<void> {
  for (const path of inputPaths) {
    try {
      await stat(path);
    } catch {
      throw new Error(`Input video not found: ${path}`);
    }
  }
}
