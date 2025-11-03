# Video Merger Lambda Function

AWS Lambda function that concatenates multiple video files using FFmpeg.

## Overview

This Lambda function:
1. Downloads video segments from S3
2. Concatenates them using FFmpeg's concat demuxer (fast, no re-encoding)
3. Uploads the merged video back to S3
4. Returns metadata (duration, size, S3 key)

## Requirements

- **Runtime**: Node.js 20.x
- **Memory**: 3008 MB (recommended for large videos)
- **Timeout**: 15 minutes
- **Ephemeral Storage**: 10 GB
- **Layer**: FFmpeg static binary (see below)

## FFmpeg Layer

This function requires an FFmpeg layer. You can use:

**Option 1: Pre-built Layer**
- [serverless-ffmpeg](https://github.com/serverlesspub/ffmpeg-aws-lambda-layer)
- ARN: `arn:aws:lambda:us-east-1:145266761615:layer:ffmpeg:4`

**Option 2: Build Your Own**
```bash
# Download static FFmpeg build
wget https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz
tar xf ffmpeg-release-amd64-static.tar.xz

# Create layer structure
mkdir -p layer/bin
cp ffmpeg-*-amd64-static/ffmpeg layer/bin/
chmod +x layer/bin/ffmpeg

# Package layer
cd layer
zip -r ../ffmpeg-layer.zip .
```

## Event Schema

```json
{
  "input_videos": [
    "s3://jiki-videos/pipelines/123/nodes/456/output.mp4",
    "s3://jiki-videos/pipelines/123/nodes/789/output.mp4"
  ],
  "output_bucket": "jiki-videos",
  "output_key": "pipelines/123/nodes/abc/output.mp4"
}
```

## Response Schema

**Success:**
```json
{
  "s3_key": "pipelines/123/nodes/abc/output.mp4",
  "duration": 120.5,
  "size": 10485760,
  "statusCode": 200
}
```

**Error:**
```json
{
  "error": "At least 2 input videos required",
  "statusCode": 400
}
```

## Local Testing

```bash
# Install dependencies
npm install

# Create test event
cat > test-event.json <<EOF
{
  "input_videos": [
    "s3://jiki-videos-dev/test/video1.mp4",
    "s3://jiki-videos-dev/test/video2.mp4"
  ],
  "output_bucket": "jiki-videos-dev",
  "output_key": "test/merged.mp4"
}
EOF

# Test with AWS SAM CLI (requires FFmpeg layer)
sam local invoke VideoMerger --event test-event.json
```

## Deployment

See `../template.yaml` for SAM deployment configuration.

```bash
# From services/video_production directory
sam build
sam deploy --guided
```

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::jiki-videos*/*"
    }
  ]
}
```

## Error Handling

- **400**: Invalid input (missing videos, wrong format)
- **500**: FFmpeg error, S3 error, or other runtime error

All temporary files in `/tmp` are cleaned up regardless of success/failure.

## Performance Notes

- Uses FFmpeg's `-c copy` (stream copy) - no re-encoding, very fast
- Videos must have compatible codecs/formats for concat demuxer
- Lambda `/tmp` storage is limited to 10 GB
- For very large videos (>1 GB each), consider increasing ephemeral storage
