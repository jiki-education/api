/**
 * Local File Cache
 *
 * Caches downloaded assets locally to avoid redundant downloads.
 * Cache directory: ./tmp/asset-cache/
 * Cache key format: {nodeId}-{sanitizedFilename}
 */

import { existsSync } from "fs";
import { mkdir, writeFile } from "fs/promises";
import { join } from "path";
import { createHash } from "crypto";

const CACHE_DIR = join(process.cwd(), "tmp", "asset-cache");

/**
 * Ensures the cache directory exists
 */
async function ensureCacheDir(): Promise<void> {
  if (!existsSync(CACHE_DIR)) {
    await mkdir(CACHE_DIR, { recursive: true });
  }
}

/**
 * Sanitizes a URL or filename to create a safe cache key
 */
function sanitizeUrl(url: string): string {
  // Create a hash of the URL to ensure uniqueness and avoid filesystem issues
  const hash = createHash("md5").update(url).digest("hex");
  // Extract extension from URL if possible
  const urlObj = new URL(url.startsWith("http") ? url : `http://dummy/${url}`);
  const pathname = urlObj.pathname;
  const ext =
    pathname.match(/\.[^.]+$/)?.[0] !== null && pathname.match(/\.[^.]+$/)?.[0] !== undefined
      ? pathname.match(/\.[^.]+$/)?.[0]
      : "";
  return `${hash}${ext}`;
}

/**
 * Generates a cache key for a given node and URL
 */
function getCacheKey(nodeId: string, url: string): string {
  const sanitized = sanitizeUrl(url);
  return `${nodeId}-${sanitized}`;
}

/**
 * Gets the full path for a cache key
 */
function getCachePath(cacheKey: string): string {
  return join(CACHE_DIR, cacheKey);
}

/**
 * Checks if a file exists in cache and returns its path
 *
 * @param nodeId - The node ID requesting the asset
 * @param url - The URL of the asset
 * @returns The local file path if cached, null otherwise
 */
export function getCachedPath(nodeId: string, url: string): string | null {
  const cacheKey = getCacheKey(nodeId, url);
  const path = getCachePath(cacheKey);

  if (existsSync(path)) {
    return path;
  }

  return null;
}

/**
 * Saves a buffer to cache and returns the local path
 *
 * @param nodeId - The node ID requesting the asset
 * @param url - The URL of the asset
 * @param buffer - The file data
 * @returns The local file path
 */
export async function saveToCacheAndReturn(nodeId: string, url: string, buffer: Buffer): Promise<string> {
  await ensureCacheDir();

  const cacheKey = getCacheKey(nodeId, url);
  const path = getCachePath(cacheKey);

  await writeFile(path, buffer);

  return path;
}

/**
 * Gets the cache directory path (for cleanup or debugging)
 */
export function getCacheDirectory(): string {
  return CACHE_DIR;
}
