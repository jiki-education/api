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

The API is organized into these namespaces:

- **`/auth/*`** - Authentication endpoints (signup, login, logout, password reset, 2FA, OAuth) - No auth required
- **`/external/*`** - Public unauthenticated endpoints (marketing/preview, email preferences) - No auth required
- **`/internal/*`** - Authenticated user endpoints (lessons, progress, submissions, settings, subscriptions) - Auth required
- **`/admin/*`** - Admin-only endpoints (content management, user management) - Auth + admin required
- **`/webhooks/*`** - Webhook receivers (Stripe, SES) - Signature-verified

See Serializers below for Lesson, UserLesson, etc.
These should have equivalent fe types.

### Authentication (`/auth/*`)

- **POST** `/auth/signup` - Register a new user
  - **Params (required):** `email`, `password`, `password_confirmation`
  - **Response:** JWT token in `Authorization` header

- **POST** `/auth/login` - Sign in and receive JWT token
  - **Params (required):** `email`, `password`
  - **Response:** JWT token in `Authorization` header (or 2FA challenge if enabled)

- **DELETE** `/auth/logout` - Sign out (invalidate token)
  - **Response:** 204 No Content

- **POST** `/auth/password` - Request password reset
  - **Params (required):** `email`
  - **Response:** 200 OK

- **GET** `/auth/confirmation` - Confirm email address
  - **Params (required):** `confirmation_token` (in query string)

- **POST** `/auth/google` - Sign in via Google OAuth
  - **Params (required):** `code`
  - **Response:** JWT token in `Authorization` header (or 2FA challenge if enabled)

- **POST** `/auth/verify-2fa` - Verify 2FA OTP code during login
  - **Params (required):** `otp_code` (session must contain `otp_user_id`)
  - **Response:** `{ status: "success", user: User }`

- **POST** `/auth/setup-2fa` - Complete 2FA setup with OTP code
  - **Params (required):** `otp_code` (session must contain `otp_user_id`)
  - **Response:** `{ status: "success", user: User }`

- **POST** `/auth/unsubscribe/:token` - Unsubscribe from emails via token
  - **Params (required):** `token` (in URL)
  - **Response:** `{ unsubscribed: true, email: "..." }`

- **POST** `/auth/account_deletion/request` - Request account deletion (auth required)
  - **Response:** `{}`

- **POST** `/auth/account_deletion/confirm` - Confirm account deletion
  - **Params (required):** `token`
  - **Response:** `{}`

- **GET** `/auth/discourse/sso` - Discourse SSO redirect
  - **Params (required):** `sso`, `sig` (Discourse SSO params)
  - **Response:** Redirect to Discourse or frontend login

### External Endpoints (`/external/*`)

Public endpoints accessible without authentication.

#### Concepts

- **GET** `/external/concepts` - Browse all concepts
  - **Query Params (optional):** `title` (filter), `page`, `per`
  - **Response:** `{ results: [Concept, ...], meta: { current_page, total_pages, total_count } }`

- **GET** `/external/concepts/:concept_slug` - View a concept
  - **Response:** `{ concept: Concept }`

#### Email Preferences

- **GET** `/external/email_preferences/:token` - View email preferences
  - **Response:** `{ email_preferences: EmailPreferences }`

- **PATCH** `/external/email_preferences/:token` - Update email preferences
  - **Params (optional):** `newsletters`, `event_emails`, `milestone_emails`, `activity_emails`
  - **Response:** `{ email_preferences: EmailPreferences }`

- **POST** `/external/email_preferences/:token/unsubscribe_all` - Unsubscribe from all emails
  - **Response:** `{ email_preferences: EmailPreferences }`

- **POST** `/external/email_preferences/:token/subscribe_all` - Subscribe to all emails
  - **Response:** `{ email_preferences: EmailPreferences }`

### Internal Endpoints (`/internal/*`)

Authenticated user endpoints. All require Bearer token in `Authorization` header.

#### User & Profile

- **GET** `/internal/me` - Get current user
  - **Response:** `{ user: User }`

- **GET** `/internal/profile` - Get current user's profile
  - **Response:** `{ profile: Profile }`

- **PUT** `/internal/profile/avatar` - Upload avatar
  - **Content-Type:** `multipart/form-data`
  - **Params (required):** `avatar` (file, max 5MB, jpeg/png/gif/webp)
  - **Response:** `{ profile: Profile }`

- **DELETE** `/internal/profile/avatar` - Delete avatar
  - **Response:** `{ profile: Profile }`

#### Settings

- **GET** `/internal/settings` - Get current user's settings
  - **Response:** `{ settings: Settings }`

- **PATCH** `/internal/settings/name` - Update name
  - **Params (required):** `value`
  - **Response:** `{ settings: Settings }`

- **PATCH** `/internal/settings/email` - Update email
  - **Params (required):** `value`
  - **Response:** `{ settings: Settings }`

- **PATCH** `/internal/settings/password` - Update password
  - **Params (required):** `value`
  - **Response:** `{ settings: Settings }`

- **PATCH** `/internal/settings/locale` - Update locale
  - **Params (required):** `value`
  - **Response:** `{ settings: Settings }`

- **PATCH** `/internal/settings/handle` - Update handle
  - **Params (required):** `value`
  - **Response:** `{ settings: Settings }`

- **PATCH** `/internal/settings/streaks` - Toggle streaks
  - **Params (required):** `enabled`
  - **Response:** `{ settings: Settings }`

- **PATCH** `/internal/settings/notifications/:slug` - Update notification preference
  - **Params (required):** `slug` (in URL), `value`
  - **Response:** `{ settings: Settings }`

#### Courses

- **GET** `/internal/courses` - List all courses (no auth required)
  - **Response:** `{ courses: [Course, ...] }`

- **GET** `/internal/courses/:id` - Show a course (no auth required)
  - **Response:** `{ course: Course }`

#### User Courses

- **GET** `/internal/user_courses` - List user's enrolled courses
  - **Response:** `{ user_courses: [UserCourse, ...] }`

- **GET** `/internal/user_courses/:id` - Show user course progress
  - **Response:** `{ user_course: UserCourse }`

- **POST** `/internal/user_courses/:id/enroll` - Enroll in a course
  - **Response:** `{ user_course: UserCourse }`

- **PATCH** `/internal/user_courses/:id/language` - Set course programming language
  - **Params (required):** `language`
  - **Response:** `{ user_course: UserCourse }`

#### Levels

- **GET** `/internal/levels` - Get all levels with nested lessons
  - **Query Params (required):** `course_slug`
  - **Response:** `{ levels: [Level, ...] }`

- **GET** `/internal/levels/:id/milestone` - Get level milestone data
  - **Query Params (required):** `course_slug`
  - **Response:** `{ milestone: LevelMilestone }`

#### User Levels

- **GET** `/internal/user_levels` - Get current user's level progress
  - **Query Params (required):** `course_slug`
  - **Response:** `{ user_levels: [UserLevel, ...] }`

- **PATCH** `/internal/user_levels/:level_slug/complete` - Complete a level
  - **Query Params (required):** `course_slug`
  - **Response:** `{}`

#### Lessons

- **GET** `/internal/lessons/:lesson_slug` - Get a single lesson with full data
  - **Response:** `{ lesson: Lesson }`

#### User Lessons

- **GET** `/internal/user_lessons/:lesson_slug` - Get user's progress on a lesson
  - **Response:** `{ user_lesson: UserLesson }`
  - **Error:** 404 if user hasn't started the lesson

- **POST** `/internal/user_lessons/:lesson_slug/start` - Start a lesson
  - **Response:** `{}`

- **PATCH** `/internal/user_lessons/:lesson_slug/complete` - Complete a lesson
  - **Response:** `{}`

- **PATCH** `/internal/user_lessons/:lesson_slug/rate` - Rate a lesson
  - **Params (required):** `difficulty_rating`, `fun_rating`
  - **Response:** `{}`

#### Exercise Submissions

- **POST** `/internal/lessons/:slug/exercise_submissions` - Submit code for a lesson exercise
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

- **GET** `/internal/lessons/:slug/exercise_submissions/latest` - Get latest submission for a lesson
  - **Response:** `{ submission: ExerciseSubmission }`

- **POST** `/internal/projects/:slug/exercise_submissions` - Submit code for a project exercise
  - **Request Body:** Same format as lesson submissions
  - **Response:** `{}` (201 Created)

**Common features for exercise submission endpoints:**
- Files are stored using Active Storage
- Each file gets a digest calculated using XXHash64 for deduplication
- UTF-8 encoding is automatically sanitized
- **Error responses** (422 Unprocessable Entity): `duplicate_filename`, `file_too_large`, `too_many_files`, `invalid_submission`

#### Projects

- **GET** `/internal/projects` - Get projects available to current user
  - **Query Params (optional):** `title` (filter), `page`, `per`
  - **Response:** `{ results: [Project, ...], meta: { current_page, total_pages, total_count } }`

- **GET** `/internal/projects/:project_slug` - Get a single project
  - **Response:** `{ project: Project }`

#### User Projects

- **GET** `/internal/user_projects/:project_slug` - Get user's progress on a project
  - **Response:** `{ user_project: UserProject }`

#### Concepts

- **GET** `/internal/concepts` - Get concepts unlocked for current user
  - **Query Params (optional):** `title` (filter), `page`, `per`
  - **Response:** `{ results: [Concept, ...], meta: { current_page, total_pages, total_count } }`
  - **Notes:** Only returns concepts the user has unlocked through lesson completion

- **GET** `/internal/concepts/:concept_slug` - Get a single unlocked concept
  - **Response:** `{ concept: Concept }`
  - **Error:** 403 if concept is locked for the user

#### Badges

- **GET** `/internal/badges` - Get all badges for current user
  - **Response:** `{ badges: [Badge, ...], num_locked_secret_badges: 3 }`

- **PATCH** `/internal/badges/:id/reveal` - Reveal a secret badge
  - **Response:** `{ badge: AcquiredBadge }`

#### Assistant Conversations

- **POST** `/internal/assistant_conversations` - Create a new AI assistant conversation
  - **Params (required):** `lesson_slug`
  - **Response:** `{ token: "..." }`

- **POST** `/internal/assistant_conversations/user_messages` - Record a user message
  - **Params (required):** `context_type`, `context_identifier`, `content`, `timestamp`
  - **Response:** `{}`

- **POST** `/internal/assistant_conversations/assistant_messages` - Record an assistant message
  - **Params (required):** `context_type`, `context_identifier`, `content`, `timestamp`, `signature`
  - **Response:** `{}`

#### Subscriptions

- **POST** `/internal/subscriptions/checkout_session` - Create Stripe checkout session
  - **Params (optional):** `interval` (default: `"monthly"`), `return_url`
  - **Response:** `{ client_secret: "..." }`

- **POST** `/internal/subscriptions/verify_checkout` - Verify a checkout session
  - **Params (required):** `session_id`
  - **Response:** `{ success: true, interval: "monthly", payment_status: "paid", subscription_status: "active" }`

- **POST** `/internal/subscriptions/portal_session` - Create Stripe customer portal session
  - **Response:** `{ url: "..." }`

- **POST** `/internal/subscriptions/update` - Update subscription interval
  - **Params (required):** `interval`
  - **Response:** `{ success: true, interval: "yearly", effective_at: "...", subscription_valid_until: "..." }`

- **DELETE** `/internal/subscriptions/cancel` - Cancel subscription
  - **Response:** `{ success: true, cancels_at: "..." }`

- **POST** `/internal/subscriptions/reactivate` - Reactivate a cancelling subscription
  - **Response:** `{ success: true, subscription_valid_until: "..." }`

#### Payments

- **GET** `/internal/payments` - List payment history
  - **Response:** `{ payments: [Payment, ...] }`

### Admin Endpoints (`/admin/*`)

All admin endpoints require authentication and admin privileges (403 Forbidden for non-admin users).

#### Users

- **GET** `/admin/users` - List users with pagination
  - **Query Params (optional):** `name`, `email` (filters), `page`, `per`
  - **Response:** `{ results: [AdminUser, ...], meta: { current_page, total_pages, total_count } }`

- **GET** `/admin/users/:id` - Get a single user
  - **Response:** `{ user: AdminUser }`

- **PATCH** `/admin/users/:id` - Update a user
  - **Params:** `user[email]`
  - **Response:** `{ user: AdminUser }`

- **DELETE** `/admin/users/:id` - Delete a user
  - **Response:** 204 No Content

#### Levels

- **GET** `/admin/levels` - List levels with pagination
  - **Query Params (required):** `course_slug`
  - **Query Params (optional):** `title`, `slug` (filters), `page`, `per`
  - **Response:** `{ results: [AdminLevel, ...], meta: { current_page, total_pages, total_count } }`

- **POST** `/admin/levels` - Create a level
  - **Query Params (required):** `course_slug`
  - **Params (required):** `level[title, description, position, slug, milestone_summary, milestone_content]`
  - **Response:** `{ level: AdminLevel }` (201 Created)

- **PATCH** `/admin/levels/:id` - Update a level
  - **Query Params (required):** `course_slug`
  - **Params:** `level[title, description, position, slug, milestone_summary, milestone_content]`
  - **Response:** `{ level: AdminLevel }`

#### Lessons (nested under levels)

- **GET** `/admin/levels/:level_id/lessons` - List lessons in a level
  - **Response:** `{ lessons: [AdminLesson, ...] }`

- **POST** `/admin/levels/:level_id/lessons` - Create a lesson
  - **Params (required):** `lesson[slug, title, description, type, position, data]`
  - **Response:** `{ lesson: AdminLesson }` (201 Created)

- **PATCH** `/admin/levels/:level_id/lessons/:id` - Update a lesson
  - **Params:** `lesson[slug, title, description, type, position, data]`
  - **Response:** `{ lesson: AdminLesson }`

#### Translations

- **POST** `/admin/levels/:level_id/translations/translate` - Queue level translation
  - **Response:** `{ level_slug: "...", queued_locales: [...] }` (202 Accepted)

- **POST** `/admin/lessons/:lesson_id/translations/translate` - Queue lesson translation
  - **Response:** `{ lesson_slug: "...", queued_locales: [...] }` (202 Accepted)

#### Projects

- **GET** `/admin/projects` - List all projects with pagination
  - **Query Params (optional):** `title` (filter), `page`, `per`
  - **Response:** `{ results: [AdminProject, ...], meta: { current_page, total_pages, total_count } }`

- **GET** `/admin/projects/:id` - Get a single project
  - **Response:** `{ project: AdminProject }`

- **POST** `/admin/projects` - Create a project
  - **Params (required):** `project[title, slug, description, exercise_slug]`
  - **Response:** `{ project: AdminProject }` (201 Created)

- **PATCH** `/admin/projects/:id` - Update a project
  - **Response:** `{ project: AdminProject }`

- **DELETE** `/admin/projects/:id` - Delete a project
  - **Response:** 204 No Content

#### Concepts

- **GET** `/admin/concepts` - List all concepts with pagination
  - **Query Params (optional):** `title` (filter), `page`, `per`
  - **Response:** `{ results: [AdminConcept, ...], meta: { current_page, total_pages, total_count } }`

- **GET** `/admin/concepts/:id` - Get a single concept
  - **Response:** `{ concept: AdminConcept }`

- **POST** `/admin/concepts` - Create a concept
  - **Params (required):** `concept[title, slug, description, content_markdown, video_data]`
  - **Response:** `{ concept: AdminConcept }` (201 Created)

- **PATCH** `/admin/concepts/:id` - Update a concept
  - **Response:** `{ concept: AdminConcept }`

- **DELETE** `/admin/concepts/:id` - Delete a concept
  - **Response:** 204 No Content

#### Images

- **POST** `/admin/images` - Upload an image
  - **Content-Type:** `multipart/form-data`
  - **Params (required):** `image` (file)
  - **Response:** `{ url: "..." }` (201 Created)

### Webhooks (`/webhooks/*`)

Unauthenticated endpoints with signature verification.

- **POST** `/webhooks/stripe` - Stripe webhook receiver
  - Verified via `HTTP_STRIPE_SIGNATURE` header

- **POST** `/webhooks/ses` - AWS SES webhook receiver (via SNS)
  - Verified via SNS signature

### Other

- **GET** `/health-check` - ECS/ALB health check
  - **Response:** `{ ruok: true, sanity_data: { user: "..." } }`

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
    }
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
  "video_data": [
    {"provider": "youtube", "id": "abc123"},
    {"provider": "mux", "id": "xyz789"}
  ]
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
  "video_data": [
    {"provider": "youtube", "id": "abc123"},
    {"provider": "mux", "id": "xyz789"}
  ]
}
```

**Notes:**
- The detail view includes `content_markdown` which is not present in the list view
- `video_data` is an array of videos, each with `provider` and `id`
- Video providers must be either `"youtube"` or `"mux"` (validated by model)

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

This starts both the Rails server (port 3060) and Solid Queue worker using Hivemind.

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
