/**
 * Shared utilities for video production Lambda functions
 */

import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { promises as fs } from 'fs';
import { Readable } from 'stream';

/**
 * S3 client configuration
 */
interface S3ClientConfig {
  region: string;
  endpoint?: string;
  forcePathStyle?: boolean;
}

// Configure S3 client with LocalStack support
const s3ClientConfig: S3ClientConfig = {
  region: process.env.AWS_REGION || 'us-east-1'
};

// Use LocalStack endpoint if AWS_ENDPOINT_URL is set (for local development)
if (process.env.AWS_ENDPOINT_URL) {
  s3ClientConfig.endpoint = process.env.AWS_ENDPOINT_URL;
  s3ClientConfig.forcePathStyle = true; // Required for LocalStack
}

export const s3Client = new S3Client(s3ClientConfig);

/**
 * Download file from S3
 * @param s3Url - S3 URL (s3://bucket/key)
 * @param localPath - Local file path
 */
export async function downloadFromS3(s3Url: string, localPath: string): Promise<void> {
  const match = s3Url.match(/^s3:\/\/([^/]+)\/(.+)$/);
  if (!match) {
    throw new Error(`Invalid S3 URL: ${s3Url}`);
  }

  const [, bucket, key] = match;

  const command = new GetObjectCommand({ Bucket: bucket, Key: key });
  const response = await s3Client.send(command);

  // Convert stream to buffer and write to file
  const chunks: Uint8Array[] = [];
  for await (const chunk of response.Body as Readable) {
    chunks.push(chunk);
  }
  const buffer = Buffer.concat(chunks);
  await fs.writeFile(localPath, buffer);
}

/**
 * Upload file to S3
 * @param localPath - Local file path
 * @param bucket - S3 bucket name
 * @param key - S3 key
 */
export async function uploadToS3(localPath: string, bucket: string, key: string): Promise<void> {
  const fileBuffer = await fs.readFile(localPath);

  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: fileBuffer,
    ContentType: 'video/mp4'
  });

  await s3Client.send(command);
}

/**
 * Clean up temporary files
 * @param paths - Array of file paths to delete
 */
export async function cleanupFiles(paths: string[]): Promise<void> {
  for (const filePath of paths) {
    try {
      await fs.unlink(filePath);
    } catch (error) {
      // Ignore errors (file might not exist)
    }
  }
}

/**
 * Callback payload structure
 */
export interface CallbackPayload {
  node_uuid?: string;
  executor_type?: string;
  process_uuid?: string;
  result?: {
    s3_key: string;
    duration: number;
    size: number;
  };
  error?: string;
  error_type?: string;
}

/**
 * Send callback to Rails SPI endpoint
 * @param url - Callback URL
 * @param payload - Callback payload
 */
export async function sendCallback(url: string, payload: CallbackPayload): Promise<void> {
  try {
    console.error(`[Callback] Sending to ${url}`);
    console.error(`[Callback] Payload: ${JSON.stringify(payload)}`);

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      console.error(`[Callback] Failed with status ${response.status}`);
      const text = await response.text();
      console.error(`[Callback] Response: ${text}`);
    } else {
      console.error(`[Callback] Successful`);
    }
  } catch (error) {
    console.error(`[Callback] Failed to send: ${error instanceof Error ? error.message : String(error)}`);
    // Don't throw - callback failure shouldn't crash Lambda
  }
}
