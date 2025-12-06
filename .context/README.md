# Context Files

This directory contains documentation that provides context to AI assistants when working with the Jiki API codebase. These files serve as a knowledge base to help maintain consistency, understand architecture decisions, and follow established patterns.

## Purpose

Context files help AI assistants:
- Understand the Rails API architecture and patterns
- Follow established coding conventions
- Make informed decisions about implementation approaches
- Maintain consistency with existing code
- Avoid common pitfalls and anti-patterns

## Directory Structure

### Core Context Files

- **[commands.md](./commands.md)** - Development commands, testing, linting, and Docker operations
- **[architecture.md](./architecture.md)** - Rails API structure, components, and design patterns
- **[controllers.md](./controllers.md)** - Controller patterns, helper methods, and conventions
- **[configuration.md](./configuration.md)** - Jiki config gem pattern, CORS, storage, and deployment config
- **[testing.md](./testing.md)** - Testing framework, FactoryBot setup, and testing patterns
- **[serializers.md](./serializers.md)** - Serializer patterns using Mandate and JSON transformation
- **[mailers.md](./mailers.md)** - Email system with MJML, HAML, and i18n patterns
- **[jobs.md](./jobs.md)** - Background jobs with Sidekiq, Mandate integration, and queue management
- **[llm.md](./llm.md)** - LLM integration for AI-powered translations via Gemini API
- **[concepts.md](./concepts.md)** - Concept model for educational content with markdown processing
- **[video_production.md](./video_production.md)** - Video production pipeline system for AI-generated content
- **[spi.md](./spi.md)** - Service Provider Interface pattern for network-guarded service-to-service communication
- **[typescript_generation.md](./typescript_generation.md)** - TypeScript type generation from Rails schemas for frontend type safety

## How to Use These Files

### For AI Assistants

1. **Start here** - Read this README first to understand available documentation
2. **Commands** - Check `commands.md` for how to run tests, lint, and perform common tasks
3. **Architecture** - Review `architecture.md` before making structural changes
4. **Controllers** - Consult `controllers.md` for controller patterns and helper methods
5. **Configuration** - Consult `configuration.md` when setting up new services or environments
6. **Testing** - Reference `testing.md` for FactoryBot patterns, test organization, and quality standards
7. **Serializers** - Reference `serializers.md` for JSON serialization patterns using Mandate
8. **Mailers** - Reference `mailers.md` for email templates, MJML/HAML patterns, and i18n
9. **Jobs** - Reference `jobs.md` for background job patterns, Sidekiq configuration, and queue management
10. **LLM** - Reference `llm.md` for AI-powered translation integration with Gemini API
11. **Concepts** - Reference `concepts.md` for educational content model and markdown processing
12. **Video Production** - Reference `video_production.md` for video pipeline system implementation
13. **SPI** - Reference `spi.md` for service-to-service communication patterns and network-guarded endpoints
14. **TypeScript Generation** - Reference `typescript_generation.md` for type generation from Rails schemas

### When to Update

Update context files when:
- Adding new architectural patterns or components
- Changing configuration approaches
- Discovering important implementation details
- Learning from mistakes that should be avoided

## Related Repositories

This API works in conjunction with:
- **Frontend** (`../fe`) - React/Next.js application
- **Curriculum** (`../curriculum`) - Learning content and exercises
- **Interpreters** (`../interpreters`) - Code execution engines
- **Overview** (`../overview`) - Business requirements and system design

## Key Principles

### Documentation is Current State
All documentation should reflect the current state of the codebase. Never use changelog format or document iterative changes. Focus on what IS, not what WAS.

### Keep It Relevant
Don't duplicate code that's easily accessible. Reference file paths and describe functionality instead of copying large code blocks.

### Continuous Improvement
When you learn something important or encounter a pattern worth documenting, update the relevant context file immediately.

## Testing & Quality Standards

### Before Committing
Always run these checks before committing code:
1. **Tests**: `bin/rails test`
2. **Linting**: `bin/rubocop -a`
3. **TypeScript Generation**: `bundle exec rake typescript:generate` (if schemas changed)
4. **Security**: `bin/brakeman`

### Context File Maintenance
Before committing, review if any context files need updating based on your changes:
- New commands added? Update `commands.md`
- Architecture changed? Update `architecture.md`
- Configuration modified? Update `configuration.md`

## Development Workflow

1. Read relevant context files before starting work
2. Make changes following established patterns
3. Run all tests and linting
4. Update context files if needed
5. Commit with clear, descriptive messages

## Rails-Specific Guidelines

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
- Queue priorities: critical > default > mailers > background > low
- See `jobs.md` for comprehensive patterns and testing

## Security Notes

### Sensitive Information
- Never commit `config/master.key`
- Use Rails credentials for secrets
- Filter sensitive parameters from logs
- Validate all input data

### API Security
- Implement rate limiting
- Use strong authentication (JWT planned)
- Validate CORS origins
- Sanitize error messages in production