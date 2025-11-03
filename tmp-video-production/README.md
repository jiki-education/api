# Temporary Video Production Reference Code

This directory contains reference implementations from the Next.js `code-videos` repository. These files serve as **reference material** for implementing the Rails API video production system.

## Purpose

This code is **NOT production code**. It's here to:
- Provide reference implementations for Node.js/TypeScript patterns
- Show how FFmpeg operations were structured
- Document the original database schema and operations
- Help translate Node.js logic to Ruby/Rails equivalents

## Directory Structure

```
tmp-video-production/
├── README.md                    # This file
│
├── executors/                   # Node executors (reference)
│   └── merge-videos.ts          # FFmpeg video concatenation logic
│
├── ffmpeg/                      # FFmpeg utilities (reference)
│   └── merge.ts                 # Video merging with FFmpeg
│
├── storage/                     # S3 storage utilities (reference)
│   ├── s3.ts                    # S3 upload/download operations
│   └── cache.ts                 # Local file caching
│
├── db/                          # Database operations (reference)
│   ├── db.ts                    # PostgreSQL connection pool
│   ├── db-operations.ts         # CRUD operations with JSONB partial updates
│   ├── db-migrations.ts         # Schema creation SQL
│   └── db-executors.ts          # Execution state update functions
│
├── types/                       # Type definitions (reference)
│   ├── types.ts                 # Database types (Pipeline, Node, NodeOutput)
│   └── nodes/                   # Node-specific types
│       ├── types.ts             # Discriminated union types for all 8 node types
│       ├── factory.ts           # DB ↔ Domain object conversion
│       ├── metadata.ts          # Node input/output metadata
│       └── display-helpers.ts   # UI display utilities
│
├── scripts/                     # CLI scripts (reference)
│   └── execute-node.ts          # Original CLI execution script
│
└── test-assets/                 # Test utilities (reference)
    └── upload-test-videos.ts    # Script for uploading test videos to S3
```

## How to Use This Code

### 1. Database Schema Translation

**Reference:** `db/db-migrations.ts`

```typescript
// TypeScript/PostgreSQL
CREATE TABLE pipelines (
  id TEXT PRIMARY KEY,
  config JSONB NOT NULL,
  metadata JSONB NOT NULL
);
```

**Translate to Rails:**

```ruby
# db/migrate/XXX_create_video_production_pipelines.rb
create_table :video_production_pipelines, id: :string do |t|
  t.jsonb :config, null: false, default: {}
  t.jsonb :metadata, null: false, default: {}
  t.timestamps
end
```

### 2. JSONB Partial Updates

**Reference:** `db/db-operations.ts`

```typescript
// TypeScript - Using pg driver
await pool.query(`
  UPDATE nodes
  SET metadata = jsonb_set(metadata, '{startedAt}', to_jsonb($1))
  WHERE pipeline_id = $2 AND id = $3
`, [new Date().toISOString(), pipelineId, nodeId]);
```

**Translate to Rails:**

```ruby
# Ruby - Using ActiveRecord with raw SQL
sql = <<~SQL
  UPDATE video_production_nodes
  SET metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{startedAt}', $1)
  WHERE pipeline_id = $2 AND id = $3
SQL

ActiveRecord::Base.connection.execute(
  ActiveRecord::Base.sanitize_sql([sql, Time.current.to_json, pipeline_id, node_id])
)
```

### 3. FFmpeg Operations

**Reference:** `ffmpeg/merge.ts`

```typescript
// TypeScript - Using fluent-ffmpeg
const command = ffmpeg();
inputs.forEach(input => command.input(input));
command
  .on('end', () => resolve())
  .on('error', (err) => reject(err))
  .mergeToFile(outputPath, tmpDir);
```

**Translate to Rails Lambda:**

```javascript
// JavaScript - Lambda function
const { spawnSync } = require('child_process');
const result = spawnSync('ffmpeg', [
  '-f', 'concat',
  '-safe', '0',
  '-i', concatFile,
  '-c', 'copy',
  outputPath
]);
```

### 4. S3 Operations

**Reference:** `storage/s3.ts`

```typescript
// TypeScript - AWS SDK v3
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
const client = new S3Client({ region: 'us-east-1' });
await client.send(new PutObjectCommand({
  Bucket: bucket,
  Key: key,
  Body: fileStream
}));
```

**Translate to Rails:**

```ruby
# Ruby - aws-sdk-s3 gem
require 'aws-sdk-s3'
s3 = Aws::S3::Client.new(region: 'us-east-1')
s3.put_object(
  bucket: bucket,
  key: key,
  body: File.read(file_path)
)
```

### 5. Executor Pattern

**Reference:** `executors/merge-videos.ts`

The executor shows:
- Loading node from database
- Validating inputs are ready
- Downloading input videos from S3
- Executing FFmpeg operations
- Uploading results to S3
- Updating database with results/errors

**Translate to Rails:**

```ruby
# app/commands/video_production/executors/merge_videos.rb
class VideoProduction::Executors::MergeVideos
  include Mandate

  queue_as :video_production

  initialize_with :pipeline_id, :node_id

  def call
    # Same logic, Ruby style
    update_node_status!('in_progress')
    input_urls = fetch_input_videos
    result = invoke_lambda_merge(input_urls)
    update_node_completed!(result)
  rescue => e
    update_node_failed!(e.message)
    raise
  end
end
```

### 6. Type Definitions

**Reference:** `types/nodes/types.ts`

Shows discriminated union pattern for 8 node types with TypeScript.

**Translate to Rails:**

Use Rails enums and ActiveRecord validations instead:

```ruby
# app/models/video_production/node.rb
class VideoProduction::Node < ApplicationRecord
  VALID_TYPES = %w[
    asset talking-head generate-animation generate-voiceover
    render-code mix-audio merge-videos compose-video
  ].freeze

  validates :type, inclusion: { in: VALID_TYPES }
  validates :status, inclusion: { in: %w[pending in_progress completed failed] }
end
```

## Key Patterns to Translate

### 1. Async/Await → Sidekiq Jobs
```typescript
// TypeScript
const result = await executeMergeVideos(pipelineId, nodeId);
```

```ruby
# Ruby
VideoProduction::Executors::MergeVideos.defer(pipeline_id, node_id)
```

### 2. Promise Chains → Mandate Commands
```typescript
// TypeScript
Promise.resolve()
  .then(() => downloadInputs())
  .then(() => processVideos())
  .then(() => uploadResult())
```

```ruby
# Ruby
def call
  download_inputs
  process_videos
  upload_result
end
```

### 3. Try/Catch → Begin/Rescue
```typescript
// TypeScript
try {
  await operation();
} catch (error) {
  console.error(error);
  throw error;
}
```

```ruby
# Ruby
begin
  operation
rescue StandardError => e
  Rails.logger.error(e.message)
  raise
end
```

## What NOT to Use

- **Don't copy-paste this code** - It's Node.js/TypeScript, not Ruby
- **Don't import these files** - They're reference only
- **Don't run these scripts** - They expect the old Next.js environment

## When to Delete This Directory

Delete `tmp-video-production/` when:
- [ ] All executors implemented in Rails
- [ ] Database schema migrated
- [ ] FFmpeg operations working in Lambda
- [ ] S3 integration complete
- [ ] All tests passing
- [ ] Production deployment successful

Estimated timeline: After Phase 6 completion (see VIDEO_PRODUCTION_PLAN.md)

---

**Next Steps:**
1. Read VIDEO_PRODUCTION_PLAN.md for implementation roadmap
2. Use this code as reference while building Rails equivalents
3. Test Rails implementations against this reference behavior
4. Delete this directory once migration is complete
