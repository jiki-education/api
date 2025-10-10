# AGENTS.md

This file provides guidance to Agents (e.g. Claude Code) when working with code in this repository.

## How to work in this project

### Context for Agents

There is a `.context` folder, which contains files explaining how everything in this project works.
You should read any files relevant to the task you are asked to work on.
Start by running:

```bash
cat .context/README.md
ls .context/
```

### How to complex a task

#### 1. Determine a plan and get sign off.

Work with the user to come up with a clear plan. Ask clarifying questions. Minimise assumptions. 

Only continue to (2) once the user has given signoff on the plan.

#### 2. Write a PLAN.md 

Write a PLAN.md document that lists the plan with checkboxes to tick off. 

#### 3. Work through the plan

As you work through the plan, add new checkboxes if new tasks are added, and check off checkboxes as needed.

## 4. Before Committing

Always perform these checks before committing code:

1. **Run Tests**: `bin/rails test`
2. **Run Linting**: `bin/rubocop`
3. **Security Check**: `bin/brakeman`
4. **Update Context Files**: Review if any `.context/` files need updating based on your changes
5. **Commit Message**: Use clear, descriptive commit messages that explain the "why"

## 5. Git Workflow for Agents (Committing)

**REQUIRED**: When completing any task, agents MUST follow this workflow:

1. **Create Feature Branch**: Always work on a descriptively named feature branch (e.g., `setup-factorybot`, `add-user-authentication`)
2. **Implement Changes**: Make all necessary code and documentation changes
3. **Quality Checks**: Run tests, linting, and security checks
4. **Commit Changes**: Create a clear, descriptive commit message
5. **Push Branch**: Push the feature branch to the remote repository
6. **Create Pull Request**: Always create a PR with a comprehensive description of changes

This ensures proper code review, maintains git history, and follows professional development practices.

### Related Repositories

This repo is part of a set of repos:
- **Frontend** (`../fe`) - React/Next.js application
- **Curriculum** (`../curriculum`) - Learning content and exercises
- **Interpreters** (`../interpreters`) - Code execution engines
- **Overview** (`../overview`) - Business requirements and system design

You can look into those repos if you need to understand how they integrate with this API.

## Project Context

This is the Jiki API - a Rails 8 API-only application that serves as the backend for Jiki, a Learn to Code platform. Jiki provides structured, linear learning pathways for coding beginners through problem-solving and interactive exercises.

## Core Business Requirements

Based on `/overview/tech/backend.md`:
- **Linear Learning Path**: Users progress through lessons sequentially
- **Exercise State Management**: Server stores all exercise submissions and progress
- **PPP Pricing**: Geographic-based pricing with Stripe integration
- **Internationalization**: Database-stored translations generated to i18n files
- **Integration with Exercism**: Shares infrastructure patterns but different user journey

## Quick Reference

For detailed information, see the context files:
- **Commands**: `.context/commands.md` - All development, testing, and deployment commands
- **Architecture**: `.context/architecture.md` - Rails API structure and design patterns
- **Controllers**: `.context/controllers.md` - Controller patterns and helper methods
- **Configuration**: `.context/configuration.md` - Jiki config gem pattern, CORS, storage setup
- **Testing**: `.context/testing.md` - Testing framework and patterns

## Next Implementation Priorities

Based on business requirements, these features need implementation:
1. User model with progression tracking
2. Lesson/Exercise models with state management
3. JWT authentication
4. API versioning (controllers/api/v1/)
5. CORS configuration for frontend
6. Stripe integration for PPP pricing
7. I18n database storage and file generation