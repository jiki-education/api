# CLAUDE.md

This file provides guidance to Agents (e.g. Claude Code) when working with code in this repository.

## Subagents

ALWAYS use subagents in the following situation:
- `git commit ...` or `git add ... && git commit ...`: Use the Task tool with `subagent_type: git-commit`.

## Context Files

The `.context/` directory contains detailed documentation for this codebase. **Read any files relevant to the task you are working on.**

| File | When to Read |
|------|--------------|
| `commands.md` | Running tests, linting, deployment commands |
| `architecture.md` | Understanding project structure, making structural changes |
| `controllers.md` | Adding or modifying API endpoints |
| `configuration.md` | Setting up services, environment config, CORS |
| `testing.md` | Writing tests, using FactoryBot |
| `serializers.md` | JSON response formatting |
| `mailers.md` | Email templates, MJML/HAML |
| `jobs.md` | Background job processing with Sidekiq |
| `llm.md` | AI-powered translation, Gemini API |
| `i18n.md` | Internationalization, translations, avoiding N+1 queries |
| `concepts.md` | Educational content model |
| `video_production.md` | Video pipeline system |
| `spi.md` | Service-to-service communication |
| `typescript_generation.md` | Type generation from schemas |
| `auth.md` | Authentication, JWT |
| `premium.md` | Premium/membership features |
| `stripe.md` | Payment integration |
| `api.md` | API endpoint documentation |
| `user_data.md` | User data model |
| `concept_unlocking.md` | Concept progression system |

## How to Complete a Task

### 1. Determine a plan and get sign off

Work with the user to come up with a clear plan. Ask clarifying questions. Minimise assumptions.

Only continue to (2) once the user has given signoff on the plan.

### 2. Write a PLAN.md

Write a PLAN.md document that lists the plan with checkboxes to tick off.

### 3. Work through the plan

As you work through the plan, add new checkboxes if new tasks are added, and check off checkboxes as needed.

## Before Committing

Always perform these checks before committing code:

1. **Run Tests**: `bin/rails test`
2. **Run Linting**: `bin/rubocop -a`
3. **TypeScript Generation**: Automatically handled by pre-commit hook if schemas changed
4. **Security Check**: `bin/brakeman`
5. **Update Context Files**: Review if any `.context/` files need updating based on your changes
6. **Commit Message**: Use clear, descriptive commit messages that explain the "why"

### Pre-Commit Hook

The `.husky/pre-commit` hook automatically:
- Runs linting on staged files
- Runs all tests
- Runs security scanning with Brakeman
- **Generates TypeScript types** if schema files changed
- Stages generated TypeScript files automatically

If schema files in `app/commands/video_production/node/schemas/` are staged, the hook will:
1. Detect the schema changes
2. Run `bundle exec rake typescript:generate`
3. Stage the generated files in `typescript/src/`
4. Include them in your commit

### CI Auto-Generation

If you bypass the pre-commit hook or forget to regenerate types, the CI pipeline will:
1. Detect missing type updates after merge to `main`
2. Generate the types automatically
3. Create a follow-up commit with the updated types
4. Push it to `main`

This ensures types are always in sync with schemas on the `main` branch.

## Git Workflow for Agents (Committing)

**REQUIRED**: When completing any task, agents MUST follow this workflow:

1. **Create Feature Branch**: Always work on a descriptively named feature branch (e.g., `setup-factorybot`, `add-user-authentication`)
2. **Implement Changes**: Make all necessary code and documentation changes
3. **Quality Checks**: Run tests, linting, and security checks
4. **Commit Changes**: **ALWAYS use the git-commit subagent** - Never create commits directly. The git-commit subagent will validate changes, review code quality, and execute the commit.
5. **Push Branch**: Push the feature branch to the remote repository
6. **Create Pull Request**: Always create a PR with a comprehensive description of changes

This ensures proper code review, maintains git history, and follows professional development practices.

## Project Context

This is the Jiki API - a Rails 8 API-only application that serves as the backend for Jiki, a Learn to Code platform. Jiki provides structured, linear learning pathways for coding beginners through problem-solving and interactive exercises.

### Core Business Requirements

Based on `/overview/tech/backend.md`:
- **Linear Learning Path**: Users progress through lessons sequentially
- **Exercise State Management**: Server stores all exercise submissions and progress
- **PPP Pricing**: Geographic-based pricing with Stripe integration
- **Internationalization**: Database-stored translations generated to i18n files
- **Integration with Exercism**: Shares infrastructure patterns but different user journey

### Related Repositories

This repo is part of a set of repos:
- **Frontend** (`../fe`) - React/Next.js application
- **Curriculum** (`../curriculum`) - Learning content and exercises
- **Interpreters** (`../interpreters`) - Code execution engines
- **Overview** (`../overview`) - Business requirements and system design

You can look into those repos if you need to understand how they integrate with this API.

## Key Principles

### Documentation is Current State

All documentation should reflect the current state of the codebase. Never use changelog format or document iterative changes. Focus on what IS, not what WAS.

### Keep It Relevant

Don't duplicate code that's easily accessible. Reference file paths and describe functionality instead of copying large code blocks.

### Continuous Improvement

When you learn something important or encounter a pattern worth documenting, update the relevant context file immediately.

## Rails Guidelines

### API-Only Considerations

- No views or asset pipeline
- JSON responses only
- Middleware optimized for APIs
- CORS configuration required

### Testing with Minitest and FactoryBot

- Parallel execution by default
- FactoryBot for test data generation (no fixtures)
- Test files in `test/` directory with factories in `test/factories/`
- Run specific tests with `-n` flag

### Background Jobs

- Use Sidekiq 8.0 with ActiveJob for async processing
- Integrate with Mandate using `.defer()` method
- Queue priorities: critical > default > mailers > translations > background > low
- See `.context/jobs.md` for comprehensive patterns and testing

## Security Notes

### Sensitive Information

- Never commit `config/master.key`
- Use Rails credentials for secrets
- Filter sensitive parameters from logs
- Validate all input data

### API Security

- Implement rate limiting
- Use strong authentication (JWT)
- Validate CORS origins
- Sanitize error messages in production

## AWS Deployment Status

### Completed Infrastructure (Terraform)

- **VPC & Networking**: VPC, subnets, internet gateway (`terraform/terraform/aws/vpc.tf`)
- **S3 Video Production**: Bucket and IAM user for video generation (`terraform/terraform/aws/video-production.tf`)
- **DynamoDB Config**: Configuration table with 14 items populated from Terraform (`terraform/terraform/aws/dynamodb.tf`)
  - Includes: domains, Cloudflare R2 config, database config, Stripe placeholders
  - Cost: ~$0.01/month
  - IAM policy for ECS task access included
- **Cloudflare R2**: Assets bucket with CDN (`terraform/terraform/cloudflare/r2.tf`)

### Next Implementation Priorities

Based on business requirements and deployment needs:

**AWS Infrastructure (see DEPLOYMENT_PLAN.md)**:
1. Aurora PostgreSQL Serverless v2 (0-1 ACU) - Database + Solid Queue
2. S3 bucket for Active Storage (exercise submission files)
3. ECS cluster and services (web only - Solid Queue runs in same process)
4. Application Load Balancer with ACM certificate
5. Security groups and IAM roles
6. CloudWatch logs and alarms

**Note**: No ElastiCache/Redis needed - using Solid Queue (database-backed) for jobs and memory cache

**Application Features**:
1. User model with progression tracking
2. Lesson/Exercise models with state management
3. JWT authentication
4. API versioning (controllers/api/v1/)
5. CORS configuration for frontend
6. Stripe integration for PPP pricing (update Stripe config values in DynamoDB)
7. I18n database storage and file generation
