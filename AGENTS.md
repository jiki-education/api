# Instructions for Coding Agents.

This file provides guidance to Agents (e.g. Claude Code) when working with code in this repository.

## Overview

This is a Rails API project for Jiki, a Learn to Code platform. Jiki provides structured, linear learning pathways for coding beginners through problem-solving and interactive exercises.

### Front End

This app integrates with a front end, which is a monorepo available for you to read at `../front-end`. The core is the NextJS app at `../front-end/app`. 

### Deployment

This API is deployed onto ECS servers and a Postgres Aurora Serverless 2 database. It uses Terraform to deploy. You can read the full terraform config at `../terraform`.

### Local Development

The local server is started via `./bin/dev`. This is nearly always running - you should NOT run it yourself.

## Application Information

- **Authentication**: Devise with session-based auth. Admin users require TOTP 2FA.
- **Membership tiers**: `standard` (free), `premium`. Check access via `user.premium?`.
- **Subscriptions**: Stripe for payments. Status tracked in `User::Data` with webhooks handling state changes.
- **Learning content**: Courses contain Levels, Levels contain Lessons. Lessons can unlock Concepts. Users progress linearly.
- **i18n**: Database-backed translations via `*::Translation` models. LLM translation via Gemini API.

### Nomenclature

- **Jiki**: A learn to code platform.
- **Exercism**: The coding education platform. Developed by the same team as Jiki. You can read the Exercism website codebase at `../../exercism/website` if the user asks you how Exercism does something.
- **language**: Always refers to programming language (e.g., JavaScript, Python)
- **locale**: Always refers to natural/human language (e.g., English, Hungarian)


## Coding Standards

### Overview

This is a Rails 8, API-only project. JSON responses only. No views. It uses Solid Queue for async processing.

The project is built around a command-pattern. All functionality is encapsulated in commands, including data serialization. The project values a strong separation of concerns.

Testing happens with Rails Test Unit supported by FactoryBot.

### Commands

This project relies heavily on commands, which live in the `app/commands` directory, and are used for most business logic. Commands use the Mandate gem (which is maintained by the same team)

A command will look like this:

```ruby
class User::Create
  include Mandate

  # Supports args and kwargs.
  initialize_with :params

  # The overarching structure goes into the call method
  def call
    # Functionality is broken into small methods
    validate!

    # Often calls ActiveRecord methods or communicates
    # with other gems or APIs.
    User.create!(
      email: params[:email],
      name: params[:name],
      password: params[:password]
    ).tap do |user|
      # Sometimes side effects are called in a tap
      # block like this. These will be either calls
      # to methods or to other commands
      User::Badge::Create.(user, :member)
    end
  end

  # Normally only the call method is public. Everything
  # else is private.
  private

  def validate!
    raise ValidationError, errors unless valid?
  end

  # Always use Mandate's memoize method rather than 
  # manual ||= patterns. memoize automatically adds memoization
  # to the method that comes after it.
  memoize

  # Always use one-line methods for simple code like this
  def valid? = errors.empty? 

  # Rather than having methods like "generate_errors", just
  # have a method that represents the data and memoize it.
  memoize
  def errors
    {}.tap do |errs|
      errs[:email] = ["can't be blank"] if params[:email].blank?
      errs[:name] = ["can't be blank"] if params[:name].blank?
      errs[:password] = ["is too short"] if params[:password].to_s.length < 8
    end
  end
end
```

#### Notes

- Mandate commands are called with either `SomeCommand.(...)` or with `SomeCommand.defer(...)` for async
- Use Bang methods (`!`) for methods that perform actions or can raise exceptions. Use regular methods for computed values or queries.
- Only return values when the caller needs them. If a command performs an action with no meaningful return (delete, send email), don't return anything.
- For background execution: use `queue_as :queue_name` at class level, `requeue_job!(seconds)` to retry later
- Search commands follow consistent pattern: `DEFAULT_PAGE`, `DEFAULT_PER` constants, private filter methods, Kaminari pagination
- Always use `sanitize_sql_like()` before adding `%` wildcards in LIKE queries

#### Organization

Commands are organized by domain in `app/commands/`. For example, we might choose to organise like this:

```
app/commands/
├── user/
│   ├── create.rb         # User registration
│   ├── update.rb         # Profile updates
│   ├── authenticate.rb   # Login logic
│   └── reset_password.rb # Password reset
├── lesson/
│   ├── create.rb         # Create new lesson
│   ├── update.rb         # Update lesson content
│   ├── complete.rb       # Mark lesson as complete
│   └── unlock_next.rb    # Unlock next lesson
└── exercise/
    ├── submit.rb         # Submit solution
    ├── evaluate.rb       # Run tests
    ├── complete.rb       # Mark as complete
    └── unlock_hint.rb    # Unlock hints
```

#### When to Use Commands

Use commands for:
- **Business operations**: Creating, updating, deleting records with business logic
- **Complex queries**: When queries involve business rules or multiple steps
- **External integrations**: API calls, payment processing, email sending
- **Multi-step processes**: Operations that coordinate multiple models
- **Validation logic**: Complex validation that goes beyond ActiveRecord validations

Don't use commands for:
- **Simple ActiveRecord operations**: Direct `find`, `where` without business logic
- **Pure data transformations**: Use serializers or presenters instead
- **View logic**: Use helpers or view components

### Models

This repository generally uses standard ActiveRecord patterns for models.

- Models should stay extremely thin. For complex or mutating methods, use Commands.
- Prefer association methods for creating records: use `level.lessons.create!(attrs)` not `Lesson.create!(attrs.merge(level_id: level.id))`

#### Specific Models

- **User::Data**: Extended user metadata is stored in `User::Data`, not on `User` directly. The `User` model uses `method_missing` to delegate, so call `user.some_method` not `user.data.some_method`. Only use `user.data.x` when there's a name clash (e.g., `user.data.id`).

- **Translation models**: Translatable models (e.g., `Level`, `Lesson`) have separate `*::Translation` models. English content stays on the main model; other locales use the translation table. Include the `Translatable` concern for this pattern.

### Serializers

Serializers are used to transform data into the structures the API outputs. They provide a single consistent data-format. They live in `app/serializers`, are normally called from controllers, and use the same Mandate pattern as commands: `include Mandate`, `initialize_with`, called with `.()`. 

- Don't include `created_at`/`updated_at` timestamps unless there's a specific business requirement.
- No business logic in serializers - only data transformation. Logic belongs in models/commands.
- Use `SerializePaginatedCollection` for paginated endpoints (wraps with `results` and `meta` containing pagination info).
- Group vs Individual serializers: Sometimes `SerializeLessons` calls `SerializeLesson` in a loop, sometimes it inlines. If calling singular, guard all N+1s in the plural serializer. Always ask the user which approach to use - do not guess.

### Controllers

Controllers are thin - delegate to commands, handle exceptions, render responses. No business logic.

- **Namespace structure**: Different namespaces with different auth levels:
  - `External::` - Public, unauthenticated endpoints
  - `Internal::` - Requires authenticated user
  - `Admin::` - Requires authenticated admin
  - `Auth::` - Authentication endpoints (login, signup, etc.)
  - `Webhooks::` - Webhook receivers (e.g., Stripe)
  - Auth is enforced at the namespace base controller level (e.g., `Internal::BaseController`), not globally in ApplicationController.
- **Error responses**: Use `render_401`, `render_403`, `render_404`, `render_422` helpers from ApplicationController. Also use `use_lesson!`, `use_concept!`, `use_project!` for resource lookup with automatic 404 handling.
- **Class naming**: Use `class Internal::LessonsController` not `module Internal; class LessonsController; end; end`
- If you find yourself adding business logic to a controller, stop and move it into a command instead.

### Mailers

Mailers use MJML (via MRML Rust compiler) for responsive HTML emails. Development uses Letter Opener; production uses SES v2 API.

- **Set email category**: Every mailer must set `self.email_category = :transactional | :notifications | :marketing` to determine from address and SES configuration.
- **Never call `mail()` directly**: Use `mail_to_user(user, unsubscribe_key:, **args)` instead. It handles preference checking, locale, and unsubscribe headers.
- **File extension**: MJML templates use `.mjml` extension (not `.html.mjml`) due to MRML compatibility.
- **Always both formats**: Include HTML (`.mjml`) and text (`.text.erb`) versions.

### Configuration

Never use `ENV` or Rails credentials directly in application code. Always use the Jiki config gem:

- `Jiki.config.*` for configuration values (e.g., `Jiki.config.frontend_base_url`). Stored in YAML files (`../config/settings/`) for dev/test, DynamoDB for production.
- `Jiki.secrets.*` for sensitive values (e.g., `Jiki.secrets.stripe_api_key`). Stored in YAML files (`../config/settings/`) for dev/test, AWS Secrets Manager for production.

If you need to add a new config key, include a PR to the config gem (`../config`) as part of your plan.

### Migrations

- **Never** use `RAILS_ENV=test` to run any database commands. If you encounter test database issues, ask the user what to do.
- Rails handles the test DB automatically when running tests.

### Exceptions

Any exceptions that are referenced outside of the file in which they're raised, should be defined in `config/initializers/exceptions.rb`. This allows exceptions to be shared across multiple commands and accessed throughout the application.

## Testing

### Overview

- **Tests**: `bin/rails test` (Rails TestUnit with FactoryBot)
- **Linting**: `bin/rubocop -a` (auto-fixes issues)
- **Security**: `bin/brakeman`

**IMPORTANT:** All three are run automatically by the git pre-commit hook. For basic changes, you don't need to run these yourself - just let the git hook handle it when you commit. For more complex changes, run tests manually during development, but leave rubocop and brakeman to the git hook.

Always read `test/test_helper.rb` to understand available helpers and configuration.

#### Libraries
- **FactoryBot** - Test data generation. Use `create` for DB, `build` for in-memory, `attributes_for` for hashes.
- **Mocha** - Mocking and stubbing. Use `expects`, `returns`, `raises`.
- **WebMock** - HTTP request stubbing for external APIs.
- **Prosopite** - N+1 query detection.

### Testing Commands

- Aim for 100% test coverage of all command functionality.
- Do NOT test functionality encapsulated in other commands - just mock those commands and verify they're called with the correct arguments.

### Testing Serializers

- Cover the default/happy path with a full JSON comparison.
- For variants that change individual keys, only assert on those specific keys.
- If there are multiple large forks in logic, use full JSON comparisons for each fork.

### Testing Controllers

- **Don't manually test authentication**: Use `guard_incorrect_token!` macro (auto-generates 2 tests) or `guard_admin!` macro for admin endpoints (auto-generates 3 tests). Never write manual auth tests.
- **Test all code paths**: If a controller has multiple rescue blocks or conditionals, test each one.
- **Use serializers in assertions**: Always reference the serializer, never manually write out JSON:
  ```ruby
  # CORRECT
  assert_json_response({ success: true, user: SerializeUser.(user) })

  # WRONG - never do this
  assert_json_response({ success: true, user: { id: 1, name: "..." } })
  ```
- Use `setup_user` helper in setup block for authenticated endpoints.

### Application Specific

- **Lesson factory**: Always use `:exercise` or `:video` trait when creating lessons - the factory requires it for validation.

## Git Workflow

- Always use a feature branch based off `main` and create a PR.
- If you're already on a feature branch, check it has a relevant name for the current task. **If unsure, ask the user.**
- **Never** `git stash drop` or lose stashed content.
- **Never** `git reset --hard`, `git checkout .`, or any command that loses uncommitted changes.
- **Never** reset, checkout, or discard content in files you haven't edited yourself.

---

## Editing This File

When editing this file, keep things concise and only provide information that is not-standard. Give enough information that Claude can determine what's meant - do not give unncessary examples.