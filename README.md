# Jiki API

Rails 8 API-only application that serves as the backend for Jiki, a Learn to Code platform.

This files contains:
- Jiki Concepts
- API Endpoints
- Setup Instructions
- Development Instructions
- Testing Instructions
- Additional Context

---

## Jiki Concepts

Understanding the core models and concepts in Jiki:

- **Level**: Top-level container for a group of related lessons (e.g., "Basics", "Advanced"). Levels contain multiple lessons and are presented to users sequentially.

- **Lesson**: A single learning unit within a level. Can be different types (exercise, tutorial, video, etc.). Contains curriculum data and tracks user progress.

- **UserLevel**: Tracks a user's progress through a specific level, including status of all lessons within that level.

- **UserLesson**: Tracks a user's progress on a specific lesson. Stores status (started/completed) and links to exercise submissions if applicable.

- **Project**: A larger, more comprehensive coding challenge that users can work on. Similar to lessons but typically more open-ended and complex. Can have associated exercise submissions.

- **UserProject**: Tracks a user's progress on a specific project, similar to UserLesson but for projects.

- **Concept**: Educational content explaining programming concepts. Includes markdown content and can have standard/premium video content from supported providers (YouTube or Mux).

- **ExerciseSubmission**: Represents code submitted by a user for either a lesson or project exercise. Uses a polymorphic `context` association to link to either UserLesson or UserProject. Stores multiple files with deduplication via XXHash64 digests.

- **EmailTemplate**: Admin-managed email templates for various system emails (e.g., level completion notifications). Supports MJML and plain text formats with internationalization.

- **VideoProduction::Pipeline**: Container for video production workflows. Manages a DAG (directed acyclic graph) of nodes that process video content.

- **VideoProduction::Node**: Individual processing step in a video production pipeline. Can represent assets, transformations (e.g., talking head generation, voiceovers, merging), and outputs.

---

## API Endpoints

The API is organized into four main namespaces:

- **`/auth/*`** - Authentication endpoints (signup, login, logout, password reset) - No auth required
- **`/external/*`** - Public unauthenticated endpoints for marketing/preview - No auth required
- **`/internal/*`** - Authenticated user endpoints (lessons, progress, submissions) - Auth required
- **`/admin/*`** - Admin-only endpoints (content management, user management) - Auth + admin required

See Serializers below for Lesson, UserLesson, etc.
These should have equivalent fe types.

### Authentication (`/auth/*`)

- **POST** `/auth/signup` - Register a new user
  - **Params (required):** `email`, `password`, `password_confirmation`
  - **Response:** JWT token in `Authorization` header

- **POST** `/auth/login` - Sign in and receive JWT token
  - **Params (required):** `email`, `password`
  - **Response:** JWT token in `Authorization` header

- **DELETE** `/auth/logout` - Sign out (invalidate token)
  - **Response:** 204 No Content

- **POST** `/auth/password` - Request password reset
  - **Params (required):** `email`
  - **Response:** 200 OK

### External Endpoints (`/external/*`)

Public endpoints accessible without authentication. Used for marketing and preview purposes.

#### Concepts

- **GET** `/external/concepts` - Browse all concepts without authentication
  - **Query Params (optional):** `title` (filter), `page`, `per`
  - **Response:**
    ```json
    {
      "results": [Concept, Concept, ...],
      "meta": {
        "current_page": 1,
        "total_pages": 3,
        "total_count": 60
      }
    }
    ```

- **GET** `/external/concepts/:concept_slug` - View any concept without authentication
  - **Params (required):** `concept_slug` (in URL)
  - **Response:**
    ```json
    {
      "concept": Concept
    }
    ```

### Internal Endpoints (`/internal/*`)

Authenticated user endpoints. All require Bearer token in `Authorization` header.

#### Levels

- **GET** `/internal/levels` - Get all levels with nested lessons (basic info only)
  - **Response:**
    ```json
    {
      "levels": [Level, Level, ...]
    }
    ```

#### Lessons

- **GET** `/internal/lessons/:slug` - Get a single lesson with full data
  - **Params (required):** `slug` (in URL)
  - **Response:**
    ```json
    {
      "lesson": Lesson
    }
    ```

#### User Levels

- **GET** `/internal/user_levels` - Get current user's levels with progress
  - **Response:**
    ```json
    {
      "user_levels": [UserLevel, UserLevel, ...]
    }
    ```

#### User Lessons

- **GET** `/internal/user_lessons/:lesson_slug` - Get user's progress on a specific lesson
  - **Params (required):** `lesson_slug` (in URL)
  - **Response:**
    ```json
    {
      "user_lesson": UserLesson
    }
    ```
  - **Error:** Returns 404 if user hasn't started the lesson

#### Concepts

- **GET** `/internal/concepts` - Get concepts unlocked for current user
  - **Query Params (optional):** `title` (filter), `page`, `per`
  - **Response:**
    ```json
    {
      "results": [Concept, Concept, ...],
      "meta": {
        "current_page": 1,
        "total_pages": 2,
        "total_count": 45
      }
    }
    ```
  - **Notes:** Only returns concepts the user has unlocked through lesson completion

- **GET** `/internal/concepts/:concept_slug` - Get a single unlocked concept
  - **Params (required):** `concept_slug` (in URL)
  - **Response:**
    ```json
    {
      "concept": Concept
    }
    ```
  - **Error:** Returns 403 Forbidden if concept is locked for the user

#### Projects

- **GET** `/internal/projects` - Get projects available to current user
  - **Query Params (optional):** `title` (filter), `page`, `per`
  - **Response:**
    ```json
    {
      "results": [Project, Project, ...],
      "meta": {
        "current_page": 1,
        "total_pages": 1,
        "total_count": 5
      }
    }
    ```

- **POST** `/internal/user_lessons/:lesson_slug/start` - Start a lesson
  - **Params (required):** `lesson_slug` (in URL)
  - **Response:** `{}`

- **PATCH** `/internal/user_lessons/:lesson_slug/complete` - Complete a lesson
  - **Params (required):** `lesson_slug` (in URL)
  - **Response:** `{}`

#### Exercise Submissions

- **POST** `/internal/lessons/:slug/exercise_submissions` - Submit code for a lesson-based exercise
  - **Params (required):** `slug` (lesson slug in URL), `submission` (object with `files` array)
  - **Request Body:**
    ```json
    {
      "submission": {
        "files": [
          {"filename": "main.rb", "code": "puts 'hello'"},
          {"filename": "helper.rb", "code": "def help\nend"}
        ]
      }
    }
    ```
  - **Response:** `{}` (201 Created)
  - **Notes:**
    - Creates ExerciseSubmission with UserLesson as polymorphic context
    - Creates or updates the UserLesson for the current user

- **POST** `/internal/projects/:slug/exercise_submissions` - Submit code for a project-based exercise
  - **Params (required):** `slug` (project slug in URL), `submission` (object with `files` array)
  - **Request Body:** Same format as lesson submissions
  - **Response:** `{}` (201 Created)
  - **Notes:**
    - Creates ExerciseSubmission with UserProject as polymorphic context
    - Creates or updates the UserProject for the current user

**Common features for exercise submission endpoints:**
- Files are stored using Active Storage
- Each file gets a digest calculated using XXHash64 for deduplication
- UTF-8 encoding is automatically sanitized
- **Error responses** (422 Unprocessable Entity):
  - `duplicate_filename` - Multiple files with same filename
  - `file_too_large` - File exceeds size limit
  - `too_many_files` - Exceeds maximum file count
  - `invalid_submission` - Invalid submission format

### Admin Endpoints (`/admin/*`)

All admin endpoints require authentication and admin privileges (403 Forbidden for non-admin users).

#### Email Templates

- **GET** `/admin/email_templates` - List all email templates
  - **Response:**
    ```json
    {
      "email_templates": [
        {
          "id": 1,
          "type": "level_completion",
          "slug": "level-1",
          "locale": "en"
        }
      ]
    }
    ```

- **GET** `/admin/email_templates/types` - Get available email template types
  - **Response:**
    ```json
    {
      "types": ["level_completion"]
    }
    ```

- **GET** `/admin/email_templates/summary` - Get summary of all templates grouped by type and slug
  - **Response:**
    ```json
    {
      "email_templates": [
        {
          "type": "level_completion",
          "slug": "level-1",
          "locales": ["en", "hu"]
        },
        {
          "type": "level_completion",
          "slug": "level-2",
          "locales": ["en"]
        }
      ],
      "locales": {
        "supported": ["en", "hu"],
        "wip": ["fr"]
      }
    }
    ```

- **GET** `/admin/email_templates/:id` - Get a single email template with full data
  - **Params (required):** `id` (in URL)
  - **Response:**
    ```json
    {
      "email_template": {
        "id": 1,
        "type": "level_completion",
        "slug": "level-1",
        "locale": "en",
        "subject": "Congratulations!",
        "body_mjml": "<mjml>...</mjml>",
        "body_text": "Congratulations on completing level 1!"
      }
    }
    ```

- **POST** `/admin/email_templates` - Create a new email template
  - **Params (required):** `email_template` object
  - **Request Body:**
    ```json
    {
      "email_template": {
        "type": "level_completion",
        "slug": "level-1",
        "locale": "en",
        "subject": "Congratulations!",
        "body_mjml": "<mjml>...</mjml>",
        "body_text": "Congratulations!"
      }
    }
    ```
  - **Response:** Created template (same format as GET single)
  - **Status:** 201 Created

- **PATCH** `/admin/email_templates/:id` - Update an email template
  - **Params (required):** `id` (in URL), `email_template` object with fields to update
  - **Request Body:**
    ```json
    {
      "email_template": {
        "subject": "New Subject",
        "body_mjml": "<mjml>...</mjml>"
      }
    }
    ```
  - **Response:** Updated template (same format as GET single)

- **DELETE** `/admin/email_templates/:id` - Delete an email template
  - **Params (required):** `id` (in URL)
  - **Response:** 204 No Content

#### Video Production

Admin endpoints for managing video production pipelines and nodes. See `.context/video_production.md` for detailed implementation guide.

**Pipelines:**

- **GET** `/admin/video_production/pipelines` - List all pipelines with pagination
  - **Query Params (optional):** `page`, `per` (default: 25)
  - **Response:**
    ```json
    {
      "results": [Pipeline, Pipeline, ...],
      "meta": {
        "current_page": 1,
        "total_pages": 5,
        "total_count": 120
      }
    }
    ```

- **GET** `/admin/video_production/pipelines/:uuid` - Get a single pipeline with all nodes
  - **Params (required):** `uuid` (in URL)
  - **Response:**
    ```json
    {
      "pipeline": Pipeline (with nodes array)
    }
    ```

- **POST** `/admin/video_production/pipelines` - Create a new pipeline
  - **Params (required):** `pipeline` object with `title`, `version`, `config`, `metadata`
  - **Response:** Created pipeline
  - **Status:** 201 Created

- **PATCH** `/admin/video_production/pipelines/:uuid` - Update a pipeline
  - **Params (required):** `uuid` (in URL), `pipeline` object with fields to update
  - **Response:** Updated pipeline

- **DELETE** `/admin/video_production/pipelines/:uuid` - Delete a pipeline (cascades to nodes)
  - **Params (required):** `uuid` (in URL)
  - **Response:** 204 No Content

**Nodes:**

- **GET** `/admin/video_production/pipelines/:pipeline_uuid/nodes` - List all nodes in a pipeline
  - **Params (required):** `pipeline_uuid` (in URL)
  - **Response:**
    ```json
    {
      "nodes": [Node, Node, ...]
    }
    ```

- **GET** `/admin/video_production/pipelines/:pipeline_uuid/nodes/:uuid` - Get a single node
  - **Params (required):** `pipeline_uuid` and `uuid` (in URL)
  - **Response:**
    ```json
    {
      "node": Node
    }
    ```

- **POST** `/admin/video_production/pipelines/:pipeline_uuid/nodes` - Create a new node
  - **Params (required):** `pipeline_uuid` (in URL), `node` object with `title`, `type`, `inputs`, `config`, `asset`
  - **Response:** Created node
  - **Status:** 201 Created
  - **Notes:** Validates inputs against node type schema

- **PATCH** `/admin/video_production/pipelines/:pipeline_uuid/nodes/:uuid` - Update a node
  - **Params (required):** `pipeline_uuid` and `uuid` (in URL), `node` object with fields to update
  - **Response:** Updated node
  - **Notes:** Resets status to `pending` if structure fields change; validates inputs

- **DELETE** `/admin/video_production/pipelines/:pipeline_uuid/nodes/:uuid` - Delete a node
  - **Params (required):** `pipeline_uuid` and `uuid` (in URL)
  - **Response:** 204 No Content
  - **Notes:** Removes references from other nodes' inputs

#### Projects

- **GET** `/admin/projects` - List all projects with pagination
  - **Query Params (optional):** `title` (filter), `page`, `per` (default: 25)
  - **Response:**
    ```json
    {
      "results": [Project, Project, ...],
      "meta": {
        "current_page": 1,
        "total_pages": 5,
        "total_count": 120
      }
    }
    ```

- **GET** `/admin/projects/:id` - Get a single project
  - **Params (required):** `id` (in URL)
  - **Response:**
    ```json
    {
      "project": Project
    }
    ```

- **POST** `/admin/projects` - Create a new project
  - **Params (required):** `project` object with fields
  - **Request Body:**
    ```json
    {
      "project": {
        "title": "Build a Todo App",
        "slug": "build-todo-app",
        "description": "Create a full-featured todo application",
        "exercise_slug": "todo-app",
        "unlocked_by_lesson_id": 42
      }
    }
    ```
  - **Response:** Created project (same format as GET single)
  - **Status:** 201 Created

- **PATCH** `/admin/projects/:id` - Update a project
  - **Params (required):** `id` (in URL), `project` object with fields to update
  - **Request Body:**
    ```json
    {
      "project": {
        "title": "Updated Title",
        "description": "Updated description"
      }
    }
    ```
  - **Response:** Updated project (same format as GET single)

- **DELETE** `/admin/projects/:id` - Delete a project
  - **Params (required):** `id` (in URL)
  - **Response:** 204 No Content

#### Concepts

- **GET** `/admin/concepts` - List all concepts with pagination
  - **Query Params (optional):** `title` (filter), `page`, `per` (default: 25)
  - **Response:**
    ```json
    {
      "results": [Concept, Concept, ...],
      "meta": {
        "current_page": 1,
        "total_pages": 3,
        "total_count": 60
      }
    }
    ```

- **GET** `/admin/concepts/:id` - Get a single concept
  - **Params (required):** `id` (in URL)
  - **Response:**
    ```json
    {
      "concept": Concept
    }
    ```

- **POST** `/admin/concepts` - Create a new concept
  - **Params (required):** `concept` object with fields
  - **Request Body:**
    ```json
    {
      "concept": {
        "title": "Variables in Ruby",
        "slug": "variables-ruby",
        "description": "Learn about variables and data types",
        "content_markdown": "# Variables\n\nVariables store data...",
        "standard_video_provider": "youtube",
        "standard_video_id": "abc123",
        "premium_video_provider": "mux",
        "premium_video_id": "xyz789"
      }
    }
    ```
  - **Response:** Created concept (same format as GET single)
  - **Status:** 201 Created

- **PATCH** `/admin/concepts/:id` - Update a concept
  - **Params (required):** `id` (in URL), `concept` object with fields to update
  - **Request Body:**
    ```json
    {
      "concept": {
        "title": "Updated Title",
        "content_markdown": "# Updated Content"
      }
    }
    ```
  - **Response:** Updated concept (same format as GET single)

- **DELETE** `/admin/concepts/:id` - Delete a concept
  - **Params (required):** `id` (in URL)
  - **Response:** 204 No Content

---

## Serializers

All API responses use serializers to format data consistently. Below are the data shapes for each serializer.

### User Serializers

#### Level

```json
{
  "slug": "basics",
  "lessons": [
    {
      "slug": "hello-world",
      "type": "exercise"
    },
    ...
  ]
}
```

**Note:** Level serialization only includes basic lesson info (slug and type). Use `GET /internal/lessons/:slug` to fetch full lesson data including the `data` field.

#### Lesson

```json
{
  "slug": "hello-world",
  "type": "exercise",
  "data": {
    "slug": "basic-movement"
  }
}
```

#### UserLesson

The UserLesson serializer returns different data based on the lesson type:

**Non-exercise lesson (tutorial, video, etc.):**
```json
{
  "lesson_slug": "intro-tutorial",
  "status": "started|completed",
  "data": {}
}
```

**Exercise lesson with submission:**
```json
{
  "lesson_slug": "hello-world",
  "status": "completed",
  "data": {
    "last_submission": {
      "uuid": "abc-123",
      "files": [
        {
          "filename": "solution.rb",
          "content": "puts 'Hello World'"
        }
      ]
    }
  }
}
```

**Exercise lesson without submission:**
```json
{
  "lesson_slug": "hello-world",
  "status": "started",
  "data": {
    "last_submission": null
  }
}
```

#### UserLevel

The UserLevel serializer inlines lesson data for optimal query performance:

```json
{
  "level_slug": "basics",
  "user_lessons": [
    {
      "lesson_slug": "hello-world",
      "status": "completed"
    },
    {
      "lesson_slug": "variables",
      "status": "started"
    }
  ]
}
```

**Note:** UserLevel only includes basic lesson progress (slug and status). Use `GET /internal/user_lessons/:lesson_slug` to fetch detailed progress including submission data.

#### ExerciseSubmission

```json
{
  "uuid": "abc-123-def-456",
  "context_type": "UserLesson",
  "context_slug": "hello-world",
  "files": [
    {
      "filename": "solution.rb",
      "digest": "a1b2c3d4e5f6"
    },
    {
      "filename": "helper.rb",
      "digest": "f6e5d4c3b2a1"
    }
  ]
}
```

**Notes:**
- `context_type` can be either `"UserLesson"` or `"UserProject"` (polymorphic association)
- `context_slug` is the slug of the associated lesson or project
- `files` array contains metadata only (filename and digest), not full content
- File content can be retrieved separately via Active Storage

### Admin Serializers

#### EmailTemplate

**List View (SerializeEmailTemplates):**
```json
{
  "id": 1,
  "type": "level_completion",
  "slug": "level-1",
  "locale": "en"
}
```

**Detail View (SerializeEmailTemplate):**
```json
{
  "id": 1,
  "type": "level_completion",
  "slug": "level-1",
  "locale": "en",
  "subject": "Congratulations on completing Level 1!",
  "body_mjml": "<mjml><mj-body>...</mj-body></mjml>",
  "body_text": "Congratulations on completing Level 1!\n\nYou've made great progress..."
}
```

**Notes:**
- The list view (used by `GET /admin/email_templates`) returns basic info only
- The detail view (used by `GET /show`, `POST /create`, `PATCH /update`) includes full email content
- `type` must be one of the available types (see `GET /types` endpoint)
- `slug` + `locale` + `type` combination must be unique

#### VideoProduction::Pipeline

**List View (SerializeAdminVideoProductionPipelines):**
```json
{
  "uuid": "123e4567-e89b-12d3-a456-426614174000",
  "title": "Ruby Basics Course",
  "version": "1.0",
  "config": {
    "storage": {
      "bucket": "jiki-videos-dev",
      "prefix": "pipelines/123/"
    },
    "workingDirectory": "./output"
  },
  "metadata": {
    "totalCost": 25.50,
    "estimatedTotalCost": 30.00,
    "progress": {
      "completed": 5,
      "in_progress": 2,
      "pending": 3,
      "failed": 0,
      "total": 10
    }
  },
  "created_at": "2025-10-15T12:00:00Z",
  "updated_at": "2025-10-15T14:30:00Z"
}
```

**Detail View (SerializeAdminVideoProductionPipeline with `include_nodes: true`):**
Same as list view plus:
```json
{
  ...,
  "nodes": [Node, Node, ...]
}
```

#### VideoProduction::Node

**SerializeAdminVideoProductionNode:**
```json
{
  "uuid": "abc-123",
  "pipeline_uuid": "123e4567-e89b-12d3-a456-426614174000",
  "title": "Merge Video Segments",
  "type": "merge-videos",
  "status": "completed",
  "inputs": {
    "segments": ["node-uuid-1", "node-uuid-2"]
  },
  "config": {
    "provider": "ffmpeg"
  },
  "asset": null,
  "metadata": {
    "startedAt": "2025-10-15T13:00:00Z",
    "completedAt": "2025-10-15T13:05:00Z",
    "cost": 0.05,
    "jobId": "sidekiq-job-123"
  },
  "output": {
    "type": "video",
    "s3Key": "pipelines/123/nodes/abc/output.mp4",
    "duration": 120.5,
    "size": 10485760
  },
  "created_at": "2025-10-15T12:00:00Z",
  "updated_at": "2025-10-15T13:05:00Z"
}
```

**Node Types:**
- `asset` - Static file references (no inputs)
- `talking-head` - HeyGen talking head videos
- `generate-animation` - Veo 3 / Runway animations
- `generate-voiceover` - ElevenLabs text-to-speech
- `render-code` - Remotion code screen animations
- `mix-audio` - FFmpeg audio replacement
- `merge-videos` - FFmpeg video concatenation
- `compose-video` - FFmpeg picture-in-picture overlays

**Node Status Values:**
- `pending` - Not yet started
- `in_progress` - Currently executing
- `completed` - Successfully finished
- `failed` - Execution failed (see metadata.error)

#### Project

**List View (SerializeAdminProjects):**
```json
{
  "id": 1,
  "title": "Build a Todo App",
  "slug": "build-todo-app",
  "description": "Create a full-featured todo application",
  "exercise_slug": "todo-app"
}
```

**Detail View (SerializeAdminProject):**
```json
{
  "id": 1,
  "title": "Build a Todo App",
  "slug": "build-todo-app",
  "description": "Create a full-featured todo application",
  "exercise_slug": "todo-app"
}
```

**Notes:**
- Both list and detail views return the same fields for Projects
- `exercise_slug` references the exercise definition in the curriculum
- `unlocked_by_lesson_id` is accepted on create/update but not serialized in responses

#### Concept

**List View (SerializeAdminConcepts):**
```json
{
  "id": 1,
  "title": "Variables in Ruby",
  "slug": "variables-ruby",
  "description": "Learn about variables and data types",
  "standard_video_provider": "youtube",
  "standard_video_id": "abc123",
  "premium_video_provider": "mux",
  "premium_video_id": "xyz789"
}
```

**Detail View (SerializeAdminConcept):**
```json
{
  "id": 1,
  "title": "Variables in Ruby",
  "slug": "variables-ruby",
  "description": "Learn about variables and data types",
  "content_markdown": "# Variables\n\nVariables are used to store data...",
  "standard_video_provider": "youtube",
  "standard_video_id": "abc123",
  "premium_video_provider": "mux",
  "premium_video_id": "xyz789"
}
```

**Notes:**
- The detail view includes `content_markdown` which is not present in the list view
- Video providers must be either `"youtube"` or `"mux"` (validated by model)
- Video IDs are provider-specific identifiers
- Standard vs premium videos allow different access levels for users

---

## Ruby Version

Ruby 3.4.4

## Setup

### Prerequisites

**Core Dependencies:**

- **Ruby 3.4.4** (see `.ruby-version`)
  - **macOS/Linux**: Use [rbenv](https://github.com/rbenv/rbenv) or [asdf](https://asdf-vm.com/)
- **PostgreSQL**
  - **macOS**: `brew install postgresql`
  - **Linux**: `sudo apt-get install postgresql postgresql-contrib`
- **Bundler**
  - Install: `gem install bundler`
- **Redis** (for Sidekiq background jobs)
  - **macOS**: `brew install redis`
  - **Linux**: `sudo apt-get install redis-server`
  - Start: `brew services start redis` (macOS) or `sudo service redis-server start` (Linux)
- **Hivemind** (for running multiple processes)
  - **macOS**: `brew install hivemind`
  - **Linux**: Download from [releases](https://github.com/DarthSim/hivemind/releases)
  - **Alternative**: Use `foreman` gem (`gem install foreman` and run `foreman start -f Procfile.dev`)

**Video Production Dependencies** (optional, only needed for video production features):

- **Docker** (for running LocalStack container)
  - **macOS**: [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
  - **Linux**: `sudo apt-get install docker.io`
  - **Note**: LocalStack image is automatically pulled by Docker when running `bin/dev` - no separate installation needed
- **jq** (JSON processor for reading `.dockerimages.json`)
  - **macOS**: `brew install jq`
  - **Linux**: `sudo apt-get install jq`
- **Node.js** (for Lambda function dependencies)
  - **macOS/Linux**: Use [nvm](https://github.com/nvm-sh/nvm) or [asdf](https://asdf-vm.com/)
  - Recommended: Node.js 20.x or later
- **curl** and **zip** (for FFmpeg download and packaging)
  - Usually pre-installed on macOS/Linux
  - **Linux**: `sudo apt-get install curl zip` if missing
- **FFmpeg** (optional, for creating test videos)
  - **macOS**: `brew install ffmpeg`
  - **Linux**: `sudo apt-get install ffmpeg`

### Installation

1. **Install dependencies:**
   ```bash
   bundle install
   ```

2. **Configure local config gem** (required for development):
   ```bash
   # Tell Bundler to use the local config repo instead of GitHub
   bundle config set --local local.jiki-config ../config
   ```

   **Note:** The `jiki-config` gem contains environment-specific settings. In development, we use the local `../config` repository for faster iteration. CI and production use the GitHub source automatically.

3. **Set up the database:**
   ```bash
   # Create, load schema, and seed with user and curriculum data
   bin/rails db:setup
   ```

4. **Reset curriculum data (optional):**
   ```bash
   # Delete and reload all levels and lessons from curriculum.json
   ruby scripts/bootstrap_levels.rb --delete-existing
   ```

## Development

### Starting the Server

```bash
bin/dev
```

This starts both the Rails server (port 3060) and Sidekiq worker using Hivemind.

**Note:** Redis must be running for Sidekiq. Start Redis with `brew services start redis` if needed.

### Stopping LocalStack

If you're working with video production features, `bin/dev` also starts a LocalStack container. To stop and remove all LocalStack containers:

```bash
bin/local/teardown-localstack
```

This will:
- Stop the main LocalStack container
- Remove all LocalStack containers (including Lambda execution containers)

## Tests

### Running Tests

```bash
bin/rails test
```

### Linting

```bash
bin/rubocop -a
```

### Security Checks

```bash
bin/brakeman
```

## Production Access

### Bastion Host

Secure access to production database and Rails console via ECS Exec with MFA authentication:

```bash
# Connect as rails user (default)
./bin/bastion

# Connect as root (for system administration)
./bin/bastion --root

# Keep bastion running for multiple connections
./bin/bastion --keep-alive

# Both flags together
./bin/bastion --keep-alive --root
```

**Inside bastion:**
```bash
./bin/rails console     # Rails console
./bin/rails dbconsole   # Database console
./bin/rails runner ...  # Run Ruby code
```

**Requirements:**
- aws-vault configured with MFA (Authy)
- IP whitelisted (86.104.250.204, 124.34.215.153, 180.50.134.226)
- Session Manager plugin installed: `brew install --cask session-manager-plugin`

**Security:**
- MFA required (12-hour sessions)
- IP-restricted access
- All sessions logged to CloudWatch
- Auto-cleanup on exit

See `DEPLOYMENT_PLAN.md` for detailed bastion documentation.

## Additional Documentation

For detailed development guidelines, architecture decisions, and patterns, see the `.context/` directory:
- `.context/commands.md` - Development commands reference
- `.context/architecture.md` - Rails API structure and patterns
- `.context/controllers.md` - Controller patterns and helper methods
- `.context/testing.md` - Testing guidelines and FactoryBot usage
- `.context/video_production.md` - Video production pipeline implementation guide

See `CLAUDE.md` for AI assistant guidelines and a full index of context files.

---

Copyright (c) 2025 Jiki Ltd. All rights reserved.
