# Video Production Services

This directory contains Lambda functions and related infrastructure for the Jiki video production pipeline.

## Overview

The video production system uses a hybrid architecture:
- **Rails API** orchestrates the workflow and manages database state
- **Lambda functions** handle heavy processing (FFmpeg operations)
- **External APIs** (HeyGen, ElevenLabs, Veo 3) generate AI content
- **Sidekiq jobs** coordinate async operations and polling

## Directory Structure

```
services/
├── shared/                      # Shared TypeScript utilities
│   ├── src/utils.ts            # S3, callback, and file utilities
│   ├── package.json
│   └── tsconfig.json
│
└── video_production/
    ├── README.md                # This file
    ├── template.yaml            # AWS SAM deployment configuration
    │
    └── video-merger/            # Lambda: FFmpeg video concatenation
        ├── src/index.ts         # Lambda handler (TypeScript)
        ├── dist/index.js        # Compiled handler
        ├── scripts/deploy.rb    # Local deployment script
        ├── package.json
        └── tsconfig.json
```

## Lambda Functions

### video-merger

Concatenates multiple video files using FFmpeg's concat demuxer.

**Technology:** TypeScript → Node.js 20.x + FFmpeg layer
**Memory:** 3008 MB
**Timeout:** 15 minutes
**Ephemeral Storage:** 10 GB
**Shared Utilities:** Uses `@jiki/shared` for S3 and callback operations

See [video-merger/README.md](./video-merger/README.md) for details.

## Deployment

### Prerequisites

1. **AWS CLI** configured with credentials
2. **AWS SAM CLI** installed ([installation guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html))
3. **Node.js 20.x** for local testing
4. **Docker** for SAM local invoke

### Deploy to AWS

```bash
# From this directory
cd services/video_production

# Build Lambda functions
sam build

# Deploy (first time - guided)
sam deploy --guided

# Deploy (subsequent times)
sam deploy
```

### Deployment Parameters

During `sam deploy --guided`, you'll be prompted for:

- **Stack Name**: `jiki-video-production-dev` (or `-staging`, `-production`)
- **AWS Region**: `us-east-1` (or your preferred region)
- **Environment**: `development`, `staging`, or `production`
- **S3BucketName**: `jiki-videos-dev` (must exist beforehand)

### Local Testing

```bash
# Install dependencies for a function
cd video-merger
npm install

# Test locally with SAM
cd ..
sam local invoke VideoMergerFunction --event video-merger/test-event.json
```

## Integration with Rails

### Invoking Lambdas from Rails

Use the `VideoProduction::InvokeLambda` command:

```ruby
result = VideoProduction::InvokeLambda.(
  'jiki-video-merger-production',
  {
    input_videos: ['s3://bucket/video1.mp4', 's3://bucket/video2.mp4'],
    output_bucket: 'jiki-videos',
    output_key: 'pipelines/123/nodes/456/output.mp4'
  }
)

# Returns: { s3_key:, duration:, size:, statusCode: 200 }
```

### Local Lambda Execution (Development Only)

For rapid development iteration, you can execute Lambda handlers **locally without deployment** using `VideoProduction::InvokeLambdaLocal`:

```bash
# Enable local execution mode (automatically builds TypeScript)
INVOKE_LAMBDA_LOCALLY=true bin/local/test-video-merge
```

**How it works:**
- Compiles TypeScript to JavaScript automatically
- Runs Lambda handler via Node.js: `node -e "require('./dist/index.js').handler(event)"`
- Uses system FFmpeg on macOS, bundled FFmpeg on Linux
- No deployment needed - instant feedback (~5 seconds vs ~2 minutes)
- Still uses LocalStack S3 for full integration testing
- AWS configuration passed as environment variables

**When to use:**
- ✅ Developing/debugging Lambda functions
- ✅ Testing FFmpeg commands
- ✅ Rapid iteration during development
- ❌ Never in production (use `InvokeLambda` for deployed Lambdas)

See `.context/video_production.md` for implementation details.

### Environment Variables

Add to Rails `.env` files:

```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_S3_BUCKET=jiki-videos-dev

# Lambda Function Names
VIDEO_MERGER_LAMBDA_NAME=jiki-video-merger-development

# External API Keys
ELEVENLABS_API_KEY=your_elevenlabs_key
ELEVENLABS_DEFAULT_VOICE_ID=default_voice_id
```

## External API Integrations

### ElevenLabs (Text-to-Speech)

**Ruby Commands:**
- `VideoProduction::APIs::ElevenLabs::GenerateAudio` - Submit TTS job
- `VideoProduction::APIs::ElevenLabs::CheckForResult` - Poll for completion

**Executor:**
- `VideoProduction::Node::Executors::GenerateVoiceover`

**Flow:**
1. Executor calls `GenerateAudio`
2. `GenerateAudio` submits to ElevenLabs API, stores `audio_id` in node metadata
3. `GenerateAudio` queues `CheckForResult` job for 10 seconds later
4. `CheckForResult` polls ElevenLabs every 10 seconds (max 60 attempts = 10 minutes)
5. When complete, downloads audio and uploads to S3
6. Updates node status to `completed` with S3 key

### Future APIs

Similar patterns will be used for:
- **HeyGen** - Talking head video generation
- **Veo 3** - AI animation generation
- **Runway** - Video generation (alternative to Veo 3)

## Architecture Patterns

### Lambda Functions

- **Stateless**: No local state between invocations
- **Synchronous**: Rails waits for Lambda response (RequestResponse invocation)
- **Error handling**: Return `{ error:, statusCode: 500 }` on failure
- **Cleanup**: Always clean up `/tmp` files

### External API Polling

- **Self-rescheduling**: Polling job reschedules itself if not complete
- **Max attempts**: Prevent infinite polling (typically 60 attempts)
- **Exponential backoff**: Can be added if APIs are rate-limited
- **Webhook fallback**: Future enhancement for APIs with webhooks

### Database Updates

All executor database updates use JSONB partial updates to avoid race conditions:

```ruby
sql = <<~SQL
  UPDATE video_production_nodes
  SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{key}', $1)
  WHERE pipeline_id = $2 AND id = $3
SQL
```

## Cost Estimates

### Lambda Costs (us-east-1)

**video-merger** (3008 MB, avg 2 minutes):
- Compute: $0.00001667 per GB-second × 3 GB × 120s = **$0.006 per merge**
- Requests: $0.20 per 1M requests = **~$0.0000002 per merge**
- **Total: ~$0.006 per video merge**

For 50 videos with 3 merges each: **~$0.90**

### External API Costs

- **ElevenLabs**: ~$0.30 per 1000 characters, or ~$0.15-0.30 per minute of audio
- **HeyGen**: $20-50 per video (depends on length, avatar)
- **Veo 3**: Pricing TBD (currently limited access)

### S3 Storage

- **Standard storage**: $0.023 per GB/month
- **Data transfer out**: $0.09 per GB (after 100 GB free tier)

## Monitoring

### CloudWatch Logs

Each Lambda function has a log group with 14-day retention:

```bash
# View logs
aws logs tail /aws/lambda/jiki-video-merger-production --follow

# View specific invocation
aws logs get-log-events \
  --log-group-name /aws/lambda/jiki-video-merger-production \
  --log-stream-name 2024/10/19/[$LATEST]abc123
```

### Lambda Metrics

Monitor in AWS Console → Lambda → Functions → [Function Name] → Monitoring:

- **Invocations**: Number of times function was called
- **Duration**: Execution time (should be < 15 minutes)
- **Errors**: Failed invocations
- **Throttles**: Rate limit exceeded (should be zero)

### Rails Logs

Executors log to Rails logs:

```bash
# Development
tail -f log/development.log | grep VideoProduction

# Production (assuming Papertrail or similar)
# Filter by: app[worker] AND VideoProduction
```

## Troubleshooting

### Lambda function times out

- Increase `Timeout` in `template.yaml`
- Check if input videos are too large (>500 MB each)
- Verify FFmpeg is working: `sam local invoke` with test event

### Lambda "out of memory"

- Increase `MemorySize` in `template.yaml`
- Check `/tmp` usage - might need more `EphemeralStorage`

### ElevenLabs polling never completes

- Check CloudWatch logs for API errors
- Verify API key is valid: `ELEVENLABS_API_KEY`
- Check node metadata for `audio_id` and `attempt` count
- Max attempts reached? Increase `MAX_ATTEMPTS` or fix API call

### S3 permission denied

- Verify IAM role has `S3ReadPolicy` and `S3WritePolicy`
- Check bucket name matches `S3BucketName` parameter
- Ensure bucket exists and is in same region

### Cannot find Lambda function

- Check function name: `jiki-video-merger-{environment}`
- Verify deployment: `sam list stack-outputs`
- Update Rails env var: `VIDEO_MERGER_LAMBDA_NAME`

## Development Workflow

### Local Development (TypeScript)

1. **Make changes** to Lambda code in `video-merger/src/index.ts`
2. **Test locally** with `INVOKE_LAMBDA_LOCALLY=true bin/local/test-video-merge` (auto-builds TypeScript)
3. **Deploy to LocalStack** with `bin/deploy-lambdas --deploy-all`
4. **Test deployed version** with `bin/local/test-video-merge`

### Production Deployment (AWS)

1. **Build** with `cd services/video_production && sam build`
2. **Deploy** with `sam deploy`
3. **Update Rails** environment variables if function name changed
4. **Test integration** with Rails executor

## Security

### Secrets Management

- **Never commit** AWS credentials or API keys
- Use **Rails credentials** or **AWS Secrets Manager** for production
- Lambda IAM roles should follow **least privilege** principle

### S3 Access

- Lambda functions can only read/write to specific bucket (via IAM policy)
- Consider **S3 bucket encryption** for sensitive content
- Enable **S3 versioning** for video assets (optional)

## Future Enhancements

- [ ] Add more Lambda functions (audio-mixer, video-composer)
- [ ] Implement webhook endpoints for external APIs
- [ ] Add CloudWatch alarms for failed invocations
- [ ] Set up X-Ray tracing for debugging
- [ ] Add VPC configuration if needed for security
- [ ] Implement dead letter queue (DLQ) for failed jobs
- [ ] Add API Gateway for webhook receivers

## Related Documentation

- **Rails Commands**: `app/commands/video_production/`
- **Executors**: `app/commands/video_production/node/executors/`
- **API Clients**: `app/commands/video_production/apis/`
- **Context**: `.context/video_production.md`
