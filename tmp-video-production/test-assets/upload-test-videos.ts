/**
 * Upload Test Videos to S3
 *
 * Uploads test videos from Downloads folder to S3 for the test-merge pipeline.
 */

import "dotenv/config";
import { readFile, writeFile } from "fs/promises";
import { join } from "path";
import { S3Client } from "@aws-sdk/client-s3";
import { Upload } from "@aws-sdk/lib-storage";
import { createReadStream } from "fs";
import { stat } from "fs/promises";

if (
  process.env.AWS_ACCESS_KEY_ID === null ||
  process.env.AWS_ACCESS_KEY_ID === undefined ||
  process.env.AWS_SECRET_ACCESS_KEY === null ||
  process.env.AWS_SECRET_ACCESS_KEY === undefined
) {
  throw new Error("AWS credentials not found in environment variables");
}

const s3Client = new S3Client({
  region:
    process.env.AWS_REGION !== null && process.env.AWS_REGION !== undefined ? process.env.AWS_REGION : "us-east-1",
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
  }
});

const BUCKET =
  process.env.AWS_S3_BUCKET !== null && process.env.AWS_S3_BUCKET !== undefined
    ? process.env.AWS_S3_BUCKET
    : "jiki-videos";
const DOWNLOADS_DIR = join(
  process.env.HOME !== null && process.env.HOME !== undefined ? process.env.HOME : "",
  "Downloads"
);

async function uploadVideo(filename: string, s3Key: string): Promise<string> {
  const filePath = join(DOWNLOADS_DIR, filename);

  const fileStream = createReadStream(filePath);
  await stat(filePath);

  const upload = new Upload({
    client: s3Client,
    params: {
      Bucket: BUCKET,
      Key: s3Key,
      Body: fileStream,
      ContentType: "video/mp4"
    }
  });

  await upload.done();

  const url = `s3://${BUCKET}/${s3Key}`;

  return url;
}

async function main() {
  try {
    // Upload videos
    const video1Url = await uploadVideo("A3607FBB-C1C2-46B8-9F69-96BDB50201B5.mp4", "test-assets/video1.mp4");
    const video2Url = await uploadVideo("A126493C-EAFA-4A30-AA21-DFCC7AE44291.mp4", "test-assets/video2.mp4");

    // Update pipeline.json
    const pipelinePath = join(process.cwd(), "lessons", "test-merge", "pipeline.json");
    const pipelineContent = await readFile(pipelinePath, "utf-8");
    const pipeline = JSON.parse(pipelineContent);

    // Update asset sources
    pipeline.nodes[0].asset.source = video1Url;
    pipeline.nodes[1].asset.source = video2Url;

    await writeFile(pipelinePath, JSON.stringify(pipeline, null, 2) + "\n", "utf-8");
  } catch (error) {
    console.error("\n" + "=".repeat(60));
    console.error("FAILED!");
    console.error("=".repeat(60));
    console.error("\nError:", error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

void main();
