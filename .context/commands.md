# Command Pattern with Mandate

The Jiki API uses the Mandate gem to implement the Command pattern for all business logic. This pattern separates business logic from HTTP concerns and makes the codebase more maintainable and testable.

## Overview

Commands are Ruby objects that encapsulate a single business operation. They live in `app/commands/` and are organized by model that they work from (e.g., `user/`, `lesson/`, `exercise/`).

## Basic Command Structure

(Note: These are all CONCEPTUAL commands - not commands in the codebase).

```ruby
class User::Create
  include Mandate

  initialize_with :params

  def call
    validate!

    User.create!(
      email: params[:email],
      name: params[:name],
      password: params[:password]
    )
  end

  private

  def validate!
    raise ValidationError, errors unless valid?
  end

  memoize
  def valid?
    errors.empty?
  end

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

## Key Concepts

### 1. Initialize With

The `initialize_with` macro defines constructor parameters:

```ruby
# Positional parameters (required)
initialize_with :user, :exercise

# Named parameters with defaults
initialize_with :user, page: 1, per: 20

# Mixed parameters
initialize_with :user, :exercise, force: false
```

### 2. The Call Method

Every command has a single public `call` method that:
- Performs the business operation
- Returns a meaningful value
- Raises exceptions for errors

**Important Pattern**: The `call` method should contain only the primary creates/updates or calls to bang methods. All other logic should be packaged into memoized methods (objects masquerading as methods).

```ruby
# GOOD: Clean call method with logic extracted
def call
  ExerciseSubmission.create!(
    user_lesson:,
    uuid:
  ).tap do |submission|
    files.each do |file_params|
      ExerciseSubmission::File::Create.(
        submission,
        file_params[:filename],
        file_params[:code]
      )
    end
  end
end

private
memoize
def uuid = SecureRandom.uuid

# BAD: Logic inline in call method
def call
  uuid = SecureRandom.uuid  # Should be a memoized method

  submission = ExerciseSubmission.create!(
    user_lesson:,
    uuid:
  )

  files.each do |file_params|
    ExerciseSubmission::File::Create.(...)
  end

  submission  # Should use .tap instead
end
```

### 3. Memoization

Use `memoize` to cache expensive computations and to extract logic from the `call` method:

```ruby
memoize
def user_track
  UserTrack.for(user, exercise.track)
end

memoize
def validation_errors
  # Expensive validation logic
end

# Extract data transformations into memoized methods
memoize
def sanitized_content
  content.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
end

memoize
def digest = XXhash.xxh64(sanitized_content).to_s

# Then use in call method:
def call
  exercise_submission.files.create!(
    filename:,
    digest:  # Uses memoized method
  ).tap do |file|
    file.content.attach(
      io: StringIO.new(sanitized_content),  # Uses memoized method
      filename:,
      content_type: 'text/plain'
    )
  end
end
```

**Pattern**: Treat memoized methods as "objects masquerading as methods" - they encapsulate data transformations and computations, keeping the `call` method clean and focused on the primary operation.

### 4. Method Naming Conventions

- **Bang methods (`!`)**: For methods that perform actions or can raise exceptions
- **Regular methods**: For computed values or queries

```ruby
private

def validate!  # Performs validation, raises on failure
  raise ValidationError unless valid?
end

def valid?     # Returns a boolean
  errors.empty?
end

def save!      # Performs save, might raise
  record.save!
end

memoize
def record     # Returns a value
  @record ||= User.find(id)
end
```

### 5. Error Handling

Commands raise exceptions rather than returning error states.

#### Global Exception Definitions

Application-wide exceptions are defined in `config/initializers/exceptions.rb`. This allows exceptions to be shared across multiple commands and accessed throughout the application:

```ruby
# config/initializers/exceptions.rb
class InvalidJsonError < RuntimeError; end
class ExerciseLockedError < RuntimeError; end
class ValidationError < RuntimeError; end
```

**Important**: Define exceptions in the initializer only when they need to be used across multiple commands or parts of the application. Command-specific exceptions can remain within the command class.

#### Using Exceptions in Commands

```ruby
# Example using global exception
class Level::CreateAllFromJson
  include Mandate

  def call
    raise InvalidJsonError, "File not found" unless File.exist?(file_path)
    # ...
  end
end

# Example with custom exception class
class ValidationError < RuntimeError
  attr_reader :errors

  def initialize(errors)
    @errors = errors
    super("Validation failed")
  end
end

# In the command:
def call
  raise ExerciseLockedError unless exercise_unlocked?
  raise ValidationError, validation_errors if validation_errors.any?

  # Proceed with operation
end
```

## Calling Commands

Commands use the `.()` or `.call()` syntax:

```ruby
# In a controller
def create
  user = User::Create.(params)
  render json: { user: SerializeUser.(user) }
rescue ValidationError => e
  render_400(:failed_validations, errors: e.errors)
rescue ExerciseLockedError
  render_403(:exercise_locked)
end

# In tests
test "creates a user" do
  user = User::Create.(email: "test@example.com", name: "Test", password: "password123")
  assert_equal "test@example.com", user.email
end

test "raises on invalid params" do
  assert_raises ValidationError do
    User::Create.(email: "", name: "", password: "")
  end
end
```

## Command Organization

Commands are organized by domain in `app/commands/`:

For example, we might choose to organise like this:

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

## Common Command Patterns

### Creation Commands

```ruby
class Lesson::Create
  include Mandate

  initialize_with :track, :params

  def call
    validate!

    Lesson.create!(
      track:,
      title: params[:title],
      content: params[:content],
      position: next_position
    )
  end

  private

  memoize
  def next_position
    track.lessons.maximum(:position).to_i + 1
  end
end
```

**Using `.tap` for Creation with Side Effects**

When you need to perform additional operations after creating a record, use `.tap`:

```ruby
class ExerciseSubmission::Create
  include Mandate

  initialize_with :user_lesson, :files

  def call
    ExerciseSubmission.create!(
      user_lesson:,
      uuid:
    ).tap do |submission|
      files.each do |file_params|
        ExerciseSubmission::File::Create.(
          submission,
          file_params[:filename],
          file_params[:code]
        )
      end
    end
  end

  private
  memoize
  def uuid = SecureRandom.uuid
end
```

This pattern:
- Returns the created object
- Keeps side effects explicit
- Avoids intermediate variables in the `call` method

### Update Commands

```ruby
class User::Update
  include Mandate

  initialize_with :user, :params

  def call
    validate!
    user.update!(filtered_params)
    user
  end

  private

  def filtered_params
    params.slice(:name, :email, :bio)
  end
end
```

### Query Commands

```ruby
class Exercise::Search
  include Mandate

  initialize_with :user, criteria: nil, page: 1, per: 20

  def call
    base_scope
      .then { |scope| filter_by_criteria(scope) }
      .page(page)
      .per(per)
  end

  private

  def base_scope
    Exercise.accessible_by(user)
  end

  def filter_by_criteria(scope)
    return scope if criteria.blank?

    # IMPORTANT: Always sanitize user input before adding wildcards
    scope.where("title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(criteria)}%")
  end
end
```

#### Security: SQL Wildcard Injection in Search Commands

**CRITICAL:** When building LIKE/ILIKE queries with user input, **ALWAYS** sanitize the input before adding `%` wildcards.

**Vulnerable Code:**
```ruby
# ❌ WRONG - Wildcard injection vulnerability
scope.where("title LIKE ?", "%#{search_term}%")
```

**Problem:** User input like `"%"` or `"test_"` will be treated as SQL wildcards:
- `%` matches any sequence of characters
- `_` matches any single character
- Input `"%"` would match ALL records

**Secure Code:**
```ruby
# ✅ CORRECT - Sanitize before adding wildcards
scope.where("title LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(search_term)}%")

# Or use model method
scope.where("title LIKE ?", "%#{YourModel.sanitize_sql_like(search_term)}%")
```

**What `sanitize_sql_like` does:**
- Escapes `%` → `\%`
- Escapes `_` → `\_`
- Input `"%test_"` becomes `"\%test\_"` (literal match, not wildcard)

**Examples in codebase:**
- ✅ `app/commands/user/search.rb` - Properly sanitized
- ✅ `app/commands/level/search.rb` - Properly sanitized
- ✅ `app/commands/concept/search.rb` - Properly sanitized

**Always sanitize when:**
- Building LIKE or ILIKE queries with user input
- User input is used in wildcard patterns (`%...%`, `%...`, `..._...`)

**Safe to skip sanitization when:**
- The value is system-generated (e.g., UUID from database)
- The value is from a controlled enum/constant
- The value doesn't include wildcard characters

### Processing Commands

```ruby
class Exercise::Submit
  include Mandate

  initialize_with :user, :exercise, :code

  def call
    validate_access!

    submission = create_submission!
    queue_evaluation!(submission)

    submission
  end

  private

  def validate_access!
    raise ExerciseLockedError unless user_can_submit?
  end

  def create_submission!
    Submission.create!(
      user: user,
      exercise: exercise,
      code: code,
      submitted_at: Time.current
    )
  end

  def queue_evaluation!(submission)
    EvaluateSubmissionJob.perform_later(submission)
  end
end
```

## Testing Commands

Commands are tested independently of controllers:

```ruby
require "test_helper"

class User::CreateTest < ActiveSupport::TestCase
  test "creates user with valid params" do
    user = User::Create.(
      email: "test@example.com",
      name: "Test User",
      password: "secure123"
    )

    assert user.persisted?
    assert_equal "test@example.com", user.email
  end

  test "raises ValidationError with invalid email" do
    error = assert_raises ValidationError do
      User::Create.(
        email: "invalid",
        name: "Test",
        password: "secure123"
      )
    end

    assert_includes error.errors[:email], "is invalid"
  end

  test "is idempotent for duplicate emails" do
    params = { email: "test@example.com", name: "Test", password: "secure123" }

    user1 = User::Create.(params)

    assert_raises ActiveRecord::RecordNotUnique do
      User::Create.(params)
    end
  end
end
```

## Best Practices

1. **Keep commands focused**: Each command should do one thing well
2. **Use meaningful exceptions**: Create custom exception classes for domain errors
3. **Validate early**: Run validations at the beginning of `call`
4. **Only return values when necessary**: Don't return objects just because they exist. Only return a value if the caller needs it for subsequent operations. If a command performs an action (delete, send email, etc.) with no meaningful return value needed by callers, don't return anything.
5. **Use memoization**: Cache expensive queries and computations
6. **Test thoroughly**: Test both success and failure paths
7. **Document complex logic**: Add comments for non-obvious business rules

## Integration with Controllers

Controllers should be thin wrappers that:
1. Call the appropriate command
2. Handle exceptions
3. Render appropriate responses

```ruby
class API::UsersController < ApplicationController
  def create
    user = User::Create.(user_params)
    render json: { user: SerializeUser.(user) }, status: :created
  rescue ValidationError => e
    render_400(:failed_validations, errors: e.errors)
  end

  def update
    user = User::Update.(current_user, user_params)
    render json: { user: SerializeUser.(user) }
  rescue ValidationError => e
    render_400(:failed_validations, errors: e.errors)
  end

  private

  def user_params
    params.require(:user).permit(:email, :name, :password)
  end
end
```

## When to Use Commands

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