/**
 * S3 Storage Client
 *
 * Handles downloading assets from S3 and uploading outputs.
 * Integrates with local cache to avoid redundant downloads.
 */

import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { Upload } from "@aws-sdk/lib-storage";
import { createReadStream } from "fs";
import { randomUUID } from "crypto";
import { getCachedPath, saveToCacheAndReturn } from "./cache";

// Initialize S3 client
const s3Client = new S3Client({
  region:
    process.env.AWS_REGION !== null && process.env.AWS_REGION !== undefined ? process.env.AWS_REGION : "us-east-1",
  credentials:
    process.env.AWS_ACCESS_KEY_ID !== null &&
    process.env.AWS_ACCESS_KEY_ID !== undefined &&
    process.env.AWS_SECRET_ACCESS_KEY !== null &&
    process.env.AWS_SECRET_ACCESS_KEY !== undefined
      ? {
          accessKeyId: process.env.AWS_ACCESS_KEY_ID,
          secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
        }
      : undefined // Use default credential chain if not provided
});

const DEFAULT_BUCKET =
  process.env.AWS_S3_BUCKET !== null && process.env.AWS_S3_BUCKET !== undefined ? process.env.AWS_S3_BUCKET : "";

/**
 * Parses an S3 URL and returns bucket and key
 *
 * Supports formats:
 * - s3://bucket/key/path.mp4
 * - https://bucket.s3.region.amazonaws.com/key/path.mp4
 * - https://s3.region.amazonaws.com/bucket/key/path.mp4
 */
function parseS3Url(url: string): { bucket: string; key: string } {
  if (url.startsWith("s3://")) {
    const withoutProtocol = url.slice(5);
    const firstSlash = withoutProtocol.indexOf("/");
    const bucket = withoutProtocol.slice(0, firstSlash);
    const key = withoutProtocol.slice(firstSlash + 1);
    return { bucket, key };
  }

  if (url.startsWith("https://")) {
    const urlObj = new URL(url);
    const hostname = urlObj.hostname;

    // Format: bucket.s3.region.amazonaws.com
    if (hostname.includes(".s3.") && hostname.includes(".amazonaws.com")) {
      const bucket = hostname.split(".")[0];
      const key = urlObj.pathname.slice(1); // Remove leading slash
      return { bucket, key };
    }

    // Format: s3.region.amazonaws.com/bucket/key
    if (hostname.startsWith("s3.") && hostname.includes(".amazonaws.com")) {
      const pathParts = urlObj.pathname.slice(1).split("/");
      const bucket = pathParts[0];
      const key = pathParts.slice(1).join("/");
      return { bucket, key };
    }
  }

  throw new Error(`Unable to parse S3 URL: ${url}`);
}

/**
 * Downloads an asset from S3 or cache
 *
 * @param nodeId - The node ID requesting the asset (for cache key)
 * @param url - The S3 URL (s3:// or https://)
 * @returns Local file path
 */
export async function downloadAsset(nodeId: string, url: string): Promise<string> {
  // Check cache first
  const cachedPath = getCachedPath(nodeId, url);
  if (cachedPath !== null && cachedPath !== undefined) {
    return cachedPath;
  }

  const { bucket, key } = parseS3Url(url);

  const command = new GetObjectCommand({
    Bucket: bucket,
    Key: key
  });

  const response = await s3Client.send(command);

  if (!response.Body) {
    throw new Error(`S3 object has no body: ${url}`);
  }

  // Convert stream to buffer
  const chunks: Uint8Array[] = [];
  const stream = response.Body as NodeJS.ReadableStream;

  for await (const chunk of stream) {
    chunks.push(chunk as Uint8Array);
  }

  const buffer = Buffer.concat(chunks);

  // Save to cache and return path
  return saveToCacheAndReturn(nodeId, url, buffer);
}

/**
 * Uploads a file to S3
 *
 * @param filePath - Local file path to upload
 * @param pipelineId - Pipeline ID (for S3 key prefix)
 * @param nodeId - Node ID (for S3 key prefix)
 * @param bucket - S3 bucket (optional, uses default from env)
 * @returns Object with S3 URL and key
 */
export async function uploadAsset(
  filePath: string,
  pipelineId: string,
  nodeId: string,
  bucket: string = DEFAULT_BUCKET
): Promise<{ url: string; key: string }> {
  if (!bucket) {
    throw new Error("S3 bucket not specified. Set AWS_S3_BUCKET environment variable.");
  }

  // Generate secure random UUID for filename
  const uuid = randomUUID();
  const extension =
    filePath.match(/\.[^.]+$/)?.[0] !== null && filePath.match(/\.[^.]+$/)?.[0] !== undefined
      ? filePath.match(/\.[^.]+$/)?.[0]
      : ".mp4";
  const key = `${pipelineId}/${nodeId}/${uuid}${extension}`;

  const fileStream = createReadStream(filePath);

  const upload = new Upload({
    client: s3Client,
    params: {
      Bucket: bucket,
      Key: key,
      Body: fileStream,
      ContentType: "video/mp4"
    }
  });

  await upload.done();

  const url = `https://${bucket}.s3.${process.env.AWS_REGION !== null && process.env.AWS_REGION !== undefined ? process.env.AWS_REGION : "us-east-1"}.amazonaws.com/${key}`;

  return { url, key };
}

/**
 * Gets the S3 client instance (for advanced operations)
 */
export function getS3Client(): S3Client {
  return s3Client;
}
