# Jiki API

Rails 8 API-only application that serves as the backend for Jiki, a Learn to Code platform.

This files contains:
- API Endpoints
- Setup Instructions
- Development Instructions
- Testing Instructions
- Additional Context

---

## API Endpoints

All endpoints require authentication via Bearer token in the `Authorization` header (except authentication endpoints).

See Serializers below for Lesson, UserLesson, etc. 
These should have equivelent fe types.

### Authentication

- **POST** `/v1/auth/signup` - Register a new user
  - **Params (required):** `email`, `password`, `password_confirmation`
  - **Response:** JWT token in `Authorization` header

- **POST** `/v1/auth/login` - Sign in and receive JWT token
  - **Params (required):** `email`, `password`
  - **Response:** JWT token in `Authorization` header

- **DELETE** `/v1/auth/logout` - Sign out (invalidate token)
  - **Response:** 204 No Content

- **POST** `/v1/auth/password` - Request password reset
  - **Params (required):** `email`
  - **Response:** 200 OK

### Levels

- **GET** `/v1/levels` - Get all levels with nested lessons (basic info only)
  - **Response:**
    ```json
    {
      "levels": [Level, Level, ...]
    }
    ```

### Lessons

- **GET** `/v1/lessons/:slug` - Get a single lesson with full data
  - **Params (required):** `slug` (in URL)
  - **Response:**
    ```json
    {
      "lesson": Lesson
    }
    ```

### User Levels

- **GET** `/v1/user_levels` - Get current user's levels with progress
  - **Response:**
    ```json
    {
      "user_levels": [UserLevel, UserLevel, ...]
    }
    ```

### User Lessons

- **GET** `/v1/user_lessons/:lesson_slug` - Get user's progress on a specific lesson
  - **Params (required):** `lesson_slug` (in URL)
  - **Response:**
    ```json
    {
      "user_lesson": UserLesson
    }
    ```
  - **Error:** Returns 404 if user hasn't started the lesson

- **POST** `/v1/user_lessons/:lesson_slug/start` - Start a lesson
  - **Params (required):** `lesson_slug` (in URL)
  - **Response:** `{}`

- **PATCH** `/v1/user_lessons/:lesson_slug/complete` - Complete a lesson
  - **Params (required):** `lesson_slug` (in URL)
  - **Response:** `{}`

### Exercise Submissions

- **POST** `/v1/lessons/:slug/exercise_submissions` - Submit code for an exercise
  - **Params (required):** `slug` (in URL), `submission` (object with `files` array)
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
  - **Response:** `{}`
  - **Notes:**
    - Files are stored using Active Storage
    - Each file gets a digest calculated using XXHash64 for deduplication
    - UTF-8 encoding is automatically sanitized
    - Creates or updates the UserLesson for the current user

### Admin

All admin endpoints require authentication and admin privileges (403 Forbidden for non-admin users).

#### Email Templates

- **GET** `/v1/admin/email_templates` - List all email templates
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

- **GET** `/v1/admin/email_templates/types` - Get available email template types
  - **Response:**
    ```json
    {
      "types": ["level_completion"]
    }
    ```

- **GET** `/v1/admin/email_templates/summary` - Get summary of all templates grouped by type and slug
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

- **GET** `/v1/admin/email_templates/:id` - Get a single email template with full data
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

- **POST** `/v1/admin/email_templates` - Create a new email template
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

- **PATCH** `/v1/admin/email_templates/:id` - Update an email template
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

- **DELETE** `/v1/admin/email_templates/:id` - Delete an email template
  - **Params (required):** `id` (in URL)
  - **Response:** 204 No Content

---

## Serializers

All API responses use serializers to format data consistently. Below are the data shapes for each serializer.

### Level

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

**Note:** Level serialization only includes basic lesson info (slug and type). Use `GET /v1/lessons/:slug` to fetch full lesson data including the `data` field.

### Lesson

```json
{
  "slug": "hello-world",
  "type": "exercise",
  "data": {
    "slug": "basic-movement"
  }
}
```

### UserLesson

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

### UserLevel

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

**Note:** UserLevel only includes basic lesson progress (slug and status). Use `GET /v1/user_lessons/:lesson_slug` to fetch detailed progress including submission data.

### EmailTemplate (Admin only)

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
- The list view (used by `GET /v1/admin/email_templates`) returns basic info only
- The detail view (used by `GET /show`, `POST /create`, `PATCH /update`) includes full email content
- `type` must be one of the available types (see `GET /types` endpoint)
- `slug` + `locale` + `type` combination must be unique

---

## Ruby Version

Ruby 3.4.4

## Setup

### Prerequisites

- Ruby 3.4.4 (see `.ruby-version`)
- PostgreSQL
- Bundler
- Redis (for Sidekiq background jobs)
- Hivemind (for running multiple processes)
  - **macOS**: `brew install hivemind`
  - **Linux**: Download from [releases](https://github.com/DarthSim/hivemind/releases)
  - **Alternative**: Use `foreman` gem (`gem install foreman` and run `foreman start -f Procfile.dev`)

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

This starts both the Rails server (port 3061) and Sidekiq worker using Hivemind.

**Note:** Redis must be running for Sidekiq. Start Redis with `brew services start redis` if needed.

## Tests

### Running Tests

```bash
bin/rails test
```

### Linting

```bash
bin/rubocop
```

### Security Checks

```bash
bin/brakeman
```

## Additional Documentation

For detailed development guidelines, architecture decisions, and patterns, see the `.context/` directory:
- `.context/README.md` - Overview and index of all context files
- `.context/commands.md` - Development commands reference
- `.context/architecture.md` - Rails API structure and patterns
- `.context/controllers.md` - Controller patterns and helper methods
- `.context/testing.md` - Testing guidelines and FactoryBot usage

See `CLAUDE.md` for AI assistant guidelines.

---

Copyright (c) 2025 Jiki Ltd. All rights reserved.
