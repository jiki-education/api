# Testing Guide

This document describes the testing approach, framework configuration, and patterns used in the Jiki API.

## Testing Framework

### Minitest
- **Framework**: Ruby's built-in Minitest framework
- **Configuration**: Rails 8 default test setup with API optimizations
- **Parallel Testing**: Enabled by default using `parallelize(workers: :number_of_processors)`
- **Test Environment**: Isolated database with automatic cleanup between tests

### Test Data Management

#### FactoryBot
- **Gem**: `factory_bot_rails` - Object generation library for tests
- **Location**: Factories defined in `test/factories/` directory
- **Syntax**: Full FactoryBot syntax methods available via `include FactoryBot::Syntax::Methods`
- **No Fixtures**: Project uses FactoryBot instead of Rails fixtures for better maintainability

### Mocking and Stubbing

#### Mocha
- **Gem**: `mocha` - Powerful mocking and stubbing framework
- **Usage**: Mock external dependencies and command objects
- **Syntax**: `expects`, `returns`, `raises` for behavior specification

#### WebMock
- **Gem**: `webmock` - HTTP request stubbing library
- **Purpose**: Mock external API calls (Stripe, email services, etc.)
- **Configuration**: Disable network connections except to allowed hosts

#### Factory Organization
```
test/factories/
├── .gitkeep           # Placeholder until first factory is created
├── users.rb           # User factory (when User model exists)
├── lessons.rb         # Lesson factory (when Lesson model exists)
└── exercises.rb       # Exercise factory (when Exercise model exists)
```

#### Factory Patterns
When creating factories, follow these conventions:
- **One factory per model** in appropriately named files
- **Traits** for variations (e.g., `:admin`, `:with_profile`)
- **Sequences** for unique values (emails, handles)
- **Associations** properly defined between related models
- **Realistic test data** that matches business domain

Example factory structure:
```ruby
FactoryBot.define do
  factory :user do
    email { "user-#{SecureRandom.hex(4)}@jiki.dev" }
    name { "Test User" }
    # ... other attributes

    trait :admin do
      role { :admin }
    end

    factory :user_with_progress do
      after(:create) do |user|
        create_list(:lesson_progress, 3, user: user)
      end
    end
  end
end
```

## Test Types

### Unit Tests
- **Location**: `test/models/`, `test/services/`, `test/lib/`
- **Purpose**: Test individual classes and methods in isolation
- **Naming**: `*_test.rb` files with descriptive test method names
- **Assertions**: Use Minitest assertions (`assert_equal`, `assert_raises`, etc.)

### Command Tests
- **Location**: `test/commands/`
- **Purpose**: Test command objects that encapsulate business logic
- **Coverage Rule**: **Every command MUST have a corresponding test file** with 1-1 mapping
  - `app/commands/concept/create.rb` → `test/commands/concept/create_test.rb`
  - `app/commands/utils/markdown/parse.rb` → `test/commands/utils/markdown/parse_test.rb`
- **Testing**: Validate inputs, outputs, error handling, and side effects

### Integration Tests
- **Location**: `test/integration/`
- **Purpose**: Test feature workflows and cross-system interactions
- **Database**: Full database interactions with factory-created test data

### Controller/API Tests
- **Location**: `test/controllers/`
- **Purpose**: Test API endpoints, JSON responses, authentication
- **Helpers**: Use Rails controller test helpers for requests and assertions
- **Response Testing**: Validate JSON structure, status codes, headers

## Database Setup

### Test Database
- **Isolation**: Each test runs in a database transaction (rolled back after)
- **Cleanup**: Automatic cleanup between tests via Rails transactional fixtures
- **Performance**: Fast test execution through transaction-based isolation
- **Schema Management**: Rails automatically manages test database schema

### Important: Never Manually Reset Test Database

**IMPORTANT**: Do NOT manually reset the test database using `RAILS_ENV=test bin/rails db:reset`. This is bad practice.

**Why:**
- Rails automatically handles test database schema and cleanup
- Each test runs in a transaction that is rolled back automatically
- Manual resets can cause race conditions in parallel tests
- It bypasses Rails' built-in test database management

**What Rails Does Automatically:**
- Loads the schema before running tests (if needed)
- Wraps each test in a transaction that is rolled back
- Maintains a clean database state between test runs
- Handles parallel test database preparation

**If you need to update the test database schema:**
```bash
# Simply run your tests - Rails will handle schema updates
bin/rails test

# Or explicitly load the schema (rarely needed)
bin/rails db:test:prepare
```

### Data Creation
```ruby
# Preferred: Use FactoryBot
user = create(:user, name: "Test User")
users = create_list(:user, 3, :admin)

# For attributes only (no database persistence)
user_attributes = attributes_for(:user)
```

## Running Tests

### Basic Commands
```bash
# Run all tests
bin/rails test

# Run specific test file
bin/rails test test/models/user_test.rb

# Run specific test method
bin/rails test test/models/user_test.rb -n test_should_validate_email

# Run with verbose output
bin/rails test -v

# Run in parallel (default)
bin/rails test -j 4
```

### Test Categories
```bash
# Run only model tests
bin/rails test test/models/

# Run only controller tests
bin/rails test test/controllers/

# Run only integration tests
bin/rails test test/integration/
```

## Best Practices

### Test Organization
- **One assertion per test** when possible
- **Descriptive test names** that explain the scenario
- **Setup/teardown** using `setup` and `teardown` methods when needed
- **Test isolation** - tests should not depend on each other

### Factory Usage
- **Use `create` for database persistence** when testing database interactions
- **Use `build` for in-memory objects** when database isn't needed
- **Use `attributes_for` for hash attributes** when creating objects manually
- **Create minimal data** - only what's needed for the specific test

### API Testing Patterns

#### JSON Response Testing

**IMPORTANT**: Always use `assert_json_response` helper for testing complete JSON responses, and always use serializers instead of manually constructing expected data structures.

##### Using Serializers in Tests

**CRITICAL**: Always use the actual serializer to generate expected data instead of manually building JSON structures. This ensures tests remain valid when serializers change.

```ruby
# CORRECT: Use serializers to generate expected data
test "GET index returns user levels" do
  user_level1 = create(:user_level, user: @current_user, level: level1)
  user_level2 = create(:user_level, user: @current_user, level: level2)

  get v1_user_levels_path, headers: @headers, as: :json

  assert_response :success
  assert_json_response({
    user_levels: SerializeUserLevels.([user_level1, user_level2])
  })
end

# INCORRECT: Don't manually construct expected JSON structures
test "GET index returns user levels" do
  user_level1 = create(:user_level, user: @current_user, level: level1)

  get v1_user_levels_path, headers: @headers, as: :json

  assert_response :success
  assert_json_response({
    user_levels: [
      {
        level_slug: "basics",
        user_lessons: [
          { lesson_slug: "lesson-1", status: "completed" }
        ]
      }
    ]
  })
end
```

**Benefits of using serializers:**
- Tests remain valid when serializer output changes
- Single source of truth for JSON structure
- Automatically includes all fields from serializer
- Catches mismatches between actual API response and test expectations
- Reduces test maintenance burden

##### Using assert_equal_json for Nested Data

When testing nested serialized data (like event payloads), use the `assert_equal_json` helper to compare serializer output with actual values:

```ruby
# CORRECT: Use assert_equal_json with serializers for nested data
test "PATCH complete emits events for unlocked concept" do
  concept = create(:concept, slug: "variables", title: "Variables")
  lesson = create(:lesson, unlocked_concept: concept)

  patch complete_v1_user_lesson_path(lesson_slug: lesson.slug),
    headers: @headers,
    as: :json

  response_json = JSON.parse(response.body, symbolize_names: true)
  concept_event = response_json[:meta][:events].find { |e| e[:type] == "concept_unlocked" }

  assert_equal_json SerializeConcept.(concept), concept_event[:data][:concept]
end

# INCORRECT: Don't assert individual fields
test "PATCH complete emits events for unlocked concept" do
  concept = create(:concept, slug: "variables", title: "Variables")
  lesson = create(:lesson, unlocked_concept: concept)

  patch complete_v1_user_lesson_path(lesson_slug: lesson.slug),
    headers: @headers,
    as: :json

  response_json = JSON.parse(response.body, symbolize_names: true)
  concept_event = response_json[:meta][:events].find { |e| e[:type] == "concept_unlocked" }

  assert_equal "variables", concept_event[:data][:concept][:slug]
  assert_equal "Variables", concept_event[:data][:concept][:title]
  # ... many more field assertions
end
```

**`assert_equal_json` helper:**
- Normalizes both sides to deep string keys
- Useful for comparing serializer output with response data
- Ensures consistent key format (string vs symbol) doesn't cause false failures

##### Complete Response Testing

**IMPORTANT**: Always use `assert_json_response` helper for testing complete JSON responses. This provides clearer, more maintainable tests compared to manual assertions.

```ruby
# CORRECT: Use assert_json_response with serializers
test "GET show returns user data" do
  user = create(:user, name: "Test User", email: "test@example.com")

  get user_path(user), headers: @headers, as: :json

  assert_response :success
  assert_json_response({
    user: SerializeUser.(user)
  })
end

# INCORRECT: Don't manually parse JSON and assert each field
test "GET show returns user data" do
  user = create(:user, name: "Test User")

  get user_path(user), headers: @headers, as: :json

  assert_response :success
  json = response.parsed_body
  assert_equal user.id, json["user"]["id"]
  assert_equal "Test User", json["user"]["name"]
  # ... many more assertions
end
```

**Benefits of `assert_json_response` with serializers:**
- Single source of truth (the serializer)
- Compares entire response structure at once
- Automatically handles string/symbol key conversions
- More readable - shows expected structure clearly
- Catches unexpected fields in response
- Tests automatically update when serializers change

#### Basic Controller Test
```ruby
class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_user
  end

  test "should get user profile" do
    get user_path(@current_user), headers: @headers, as: :json

    assert_response :success
    assert_json_response({
      user: {
        id: @current_user.id,
        name: @current_user.name,
        email: @current_user.email
      }
    })
  end

  test "requires authentication" do
    get user_path(@current_user), as: :json

    assert_response :unauthorized
    assert_json_response({
      error: {
        type: "unauthorized",
        message: "Unauthorized"
      }
    })
  end
end
```

#### Testing Serializers in Controllers

**IMPORTANT**: When testing that a controller uses a specific serializer, mock the serializer and verify it's called with the correct data. Don't test the serializer's output in controller tests - that belongs in serializer tests.

```ruby
# CORRECT: Test that serializer is called, not its output
test "GET index uses SerializeLevels" do
  levels = create_list(:level, 2)
  serialized_data = [{ slug: "test" }]

  SerializeLevels.expects(:call).with { |arg| arg.to_a == levels }.returns(serialized_data)

  get levels_path, headers: @headers, as: :json

  assert_response :success
  assert_json_response({ levels: serialized_data })
end

# INCORRECT: Don't test serializer output in controller test
test "GET index uses SerializeLevels" do
  level = create(:level, slug: "test-level")

  get levels_path, headers: @headers, as: :json

  assert_response :success
  json = response.parsed_body

  # Testing serializer behavior - belongs in serializer test
  assert json["levels"][0].key?("slug")
  assert json["levels"][0].key?("lessons")
  refute json["levels"][0].key?("title")
end
```

#### Testing Paginated Controllers

For controllers that return paginated collections:

```ruby
test "GET index calls Command with correct params" do
  records = create_list(:model, 2)
  paginated = Kaminari.paginate_array(records, total_count: 2).page(1).per(24)

  Model::Search.expects(:call).with(
    filter1: "value",
    filter2: nil,
    page: "2",
    per: nil
  ).returns(paginated)

  get v1_admin_models_path(filter1: "value", page: 2),
    headers: @headers,
    as: :json

  assert_response :success
end

test "GET index uses SerializePaginatedCollection" do
  Prosopite.finish
  records = create_list(:model, 2)
  paginated = Kaminari.paginate_array(records, total_count: 2).page(1).per(24)

  Model::Search.expects(:call).returns(paginated)
  SerializePaginatedCollection.expects(:call).with(
    paginated,
    serializer: SerializeModels
  ).returns({ results: [], meta: {} })

  Prosopite.scan
  get v1_admin_models_path, headers: @headers, as: :json

  assert_response :success
end

test "GET index filters by parameter" do
  create(:model, name: "Alice")
  bob = create(:model, name: "Bob")

  get v1_admin_models_path(name: "Bob"),
    headers: @headers,
    as: :json

  assert_response :success
  json = response.parsed_body
  assert_equal 1, json["results"].length
  assert_equal bob.id, json["results"][0]["id"]
end

test "GET index paginates results" do
  Prosopite.finish
  3.times { create(:model) }

  Prosopite.scan
  get v1_admin_models_path(page: 1, per: 2),
    headers: @headers,
    as: :json

  assert_response :success
  json = response.parsed_body
  assert_equal 2, json["results"].length
  assert_equal 1, json["meta"]["current_page"]
  assert_equal 2, json["meta"]["total_pages"]
end
```

**Key Patterns**:
- Pass query params via path helper: `path(param: value)`
- Mock command with Kaminari-paginated array
- Verify SerializePaginatedCollection is called
- Test actual filtering (don't just mock)
- Test pagination metadata is correct
- Use `Prosopite.finish/scan` around data creation for N+1 detection

#### Testing Commands in Controllers
```ruby
class LessonsControllerTest < ActionDispatch::IntegrationTest
  setup do
    setup_user
  end

  test "delegates to Lesson::Create command" do
    lesson = build(:lesson)
    Lesson::Create.expects(:call).with(
      @current_user,
      title: "New Lesson",
      content: "Content"
    ).returns(lesson)

    post lessons_path,
      params: { lesson: { title: "New Lesson", content: "Content" } },
      headers: @headers,
      as: :json

    assert_response :created
  end

  test "handles command validation errors" do
    error = ValidationError.new(title: ["can't be blank"])
    Lesson::Create.expects(:call).raises(error)

    post lessons_path,
      params: { lesson: { content: "Content" } },
      headers: @headers,
      as: :json

    assert_response :bad_request
    assert_json_response({
      error: {
        type: "validation_error",
        message: "Validation failed",
        errors: { title: ["can't be blank"] }
      }
    })
  end
end
```

#### Authentication Testing Helper
```ruby
# In test_helper.rb or a support file
module AuthenticationHelper
  def setup_user(user = nil)
    @current_user = user || create(:user)
    @auth_token = create(:auth_token, user: @current_user)
    @headers = { 'Authorization' => "Bearer #{@auth_token.token}" }
  end

  def auth_headers_for(user)
    token = create(:auth_token, user: user)
    { 'Authorization' => "Bearer #{token.token}" }
  end
end

class ActionDispatch::IntegrationTest
  include AuthenticationHelper
end
```

#### Testing Authentication Guards

**IMPORTANT**: Use the `guard_incorrect_token!` or `guard_admin!` macros instead of writing manual authentication tests.

##### guard_incorrect_token! - For Regular Authenticated Endpoints

The `guard_incorrect_token!` macro automatically generates two tests:
1. Test that the endpoint returns 401 with an invalid token
2. Test that the endpoint returns 401 without any token

This eliminates the need for repetitive manual authentication tests and ensures consistent coverage.

```ruby
# Base test class with guard macro (defined in test_helper.rb)
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  def self.guard_incorrect_token!(path_helper, args: [], method: :get)
    test "#{method} #{path_helper} returns 401 with invalid token" do
      path = send(path_helper, *args)
      send(method, path, headers: { 'Authorization' => 'Bearer invalid' }, as: :json)

      assert_response :unauthorized
      assert_equal 'unauthorized', response.parsed_body['error']['type']
    end

    test "#{method} #{path_helper} returns 401 without token" do
      path = send(path_helper, *args)
      send(method, path, as: :json)

      assert_response :unauthorized
      assert_equal 'unauthorized', response.parsed_body['error']['type']
    end
  end
end
```

**Usage Pattern:**

```ruby
# CORRECT: Use guard_incorrect_token! macro at the top of your test class
# IMPORTANT: Always use `class V1::ControllerTest` format, not module wrapping
class V1::LessonsControllerTest < ApplicationControllerTest
  setup do
    setup_user
    @lesson = create(:lesson)
  end

  # Place guards at the top, before your actual tests
  guard_incorrect_token! :start_v1_lesson_path, args: ["solve-a-maze"], method: :post
  guard_incorrect_token! :complete_v1_lesson_path, args: ["solve-a-maze"], method: :patch

  # Then write your functional tests (skip manual auth tests)
  test "POST start successfully starts a lesson" do
    post start_v1_lesson_path(@lesson.slug),
      headers: @headers,
      as: :json

    assert_response :created
  end

  test "PATCH complete successfully completes a lesson" do
    patch complete_v1_lesson_path(@lesson.slug),
      headers: @headers,
      as: :json

    assert_response :ok
  end
end
```

##### guard_admin! - For Admin-Only Endpoints

**IMPORTANT**: For admin-only endpoints, use `guard_admin!` instead of `guard_incorrect_token!`.

The `guard_admin!` macro automatically generates THREE tests:
1. Test that the endpoint returns 401 with an invalid token (via `guard_incorrect_token!`)
2. Test that the endpoint returns 401 without any token (via `guard_incorrect_token!`)
3. Test that the endpoint returns 403 for authenticated non-admin users

This macro internally calls `guard_incorrect_token!`, so you only need to use `guard_admin!` for admin endpoints.

```ruby
# Base test class with guard macro (defined in test_helper.rb)
class ApplicationControllerTest < ActionDispatch::IntegrationTest
  def self.guard_admin!(path_helper, args: [], method: :get)
    # First, guard against incorrect tokens (401 errors)
    guard_incorrect_token!(path_helper, args:, method:)

    # Then, guard against non-admin users (403 error)
    test "#{method} #{path_helper} returns 403 for non-admin users" do
      user = create(:user, admin: false)
      headers = auth_headers_for(user)
      path = send(path_helper, *args)

      send(method, path, headers:, as: :json)

      assert_response :forbidden
      assert_json_response({
        error: {
          type: "forbidden",
          message: "Admin access required"
        }
      })
    end
  end
end
```

**Usage Pattern:**

```ruby
# CORRECT: Use guard_admin! for admin endpoints
module V1
  module Admin
    class EmailTemplatesControllerTest < ApplicationControllerTest
      setup do
        @admin = create(:user, :admin)
        @headers = auth_headers_for(@admin)
      end

      # Place admin guards at the top - handles both auth and admin checks
      guard_admin! :v1_admin_email_templates_path, method: :get
      guard_admin! :v1_admin_email_templates_path, method: :post
      guard_admin! :v1_admin_email_template_path, args: [1], method: :patch

      # Then write your functional tests (skip manual auth/admin tests)
      test "GET index returns all templates" do
        template = create(:email_template)

        get v1_admin_email_templates_path, headers: @headers, as: :json

        assert_response :success
        assert_json_response({
          email_templates: [
            { id: template.id, slug: template.slug, locale: template.locale }
          ]
        })
      end
    end
  end
end
```

**INCORRECT: Don't write manual authentication or admin tests**

```ruby
# DON'T DO THIS - the guard_admin! macro handles these automatically
test "GET index requires authentication" do
  get v1_admin_email_templates_path, as: :json
  assert_response :unauthorized
end

test "GET index returns 401 with invalid token" do
  get v1_admin_email_templates_path,
    headers: { "Authorization" => "Bearer invalid" },
    as: :json
  assert_response :unauthorized
end

test "GET index returns 403 for non-admin users" do
  user = create(:user, admin: false)
  headers = auth_headers_for(user)
  get v1_admin_email_templates_path, headers:, as: :json
  assert_response :forbidden
end
```

**Why Use guard_incorrect_token! and guard_admin!:**
- **DRY**: Eliminates repetitive authentication/authorization tests across all controller tests
- **Consistency**: Ensures all endpoints have the same authentication/authorization behavior
- **Maintainability**: Changes to auth logic only require updating the macro once
- **Coverage**: Automatically tests invalid token, missing token, and (for admin) non-admin scenarios
- **Clarity**: Makes it immediately obvious which endpoints require admin access

### Serializer Testing Patterns

**IMPORTANT**: When testing serializers, extract expected values into separate variables for improved readability and maintainability.

```ruby
# CORRECT: Extract expected hash into a variable
test "serializes multiple levels with lessons" do
  level1 = create(:level, slug: "level-1")
  level2 = create(:level, slug: "level-2")
  create(:lesson, level: level1, slug: "l1", type: "exercise", data: { slug: "ex1" })
  create(:lesson, level: level2, slug: "l2", type: "tutorial", data: { slug: "ex2" })

  expected = [
    {
      slug: "level-1",
      lessons: [
        { slug: "l1", type: "exercise", data: { slug: "ex1" } }
      ]
    },
    {
      slug: "level-2",
      lessons: [
        { slug: "l2", type: "tutorial", data: { slug: "ex2" } }
      ]
    }
  ]

  assert_equal(expected, SerializeLevels.([level1, level2]))
end

# INCORRECT: Inline hash makes tests harder to read
test "serializes multiple levels with lessons" do
  level1 = create(:level, slug: "level-1")
  level2 = create(:level, slug: "level-2")
  create(:lesson, level: level1, slug: "l1", type: "exercise", data: { slug: "ex1" })

  assert_equal([
                 {
                   slug: "level-1",
                   lessons: [
                     { slug: "l1", type: "exercise", data: { slug: "ex1" } }
                   ]
                 }
               ], SerializeLevels.([level1]))
end
```

**Benefits:**
- Easier to read and understand expected output
- Simpler to modify expected values when requirements change
- Better diffs when tests fail
- Consistent formatting across test files

### Performance Considerations
- **Minimize database calls** in factory definitions
- **Use traits wisely** to avoid complex factory hierarchies
- **Prefer `build` over `create`** when database persistence isn't required
- **Use `create_list` efficiently** for bulk data creation

## Search Command Testing

Search commands should test filtering, pagination, and combinations:

```ruby
class Model::SearchTest < ActiveSupport::TestCase
  test "no options returns all records paginated" do
    record_1 = create :model
    record_2 = create :model

    result = Model::Search.()

    assert_equal [record_1, record_2], result.to_a
  end

  test "filter: search with partial match" do
    match = create :model, name: "Amy Smith"
    create :model, name: "Bob Jones"

    assert_equal [match], Model::Search.(name: "Amy").to_a
    assert_empty Model::Search.(name: "xyz").to_a
  end

  test "pagination" do
    record_1 = create :model
    record_2 = create :model

    assert_equal [record_1], Model::Search.(page: 1, per: 1).to_a
    assert_equal [record_2], Model::Search.(page: 2, per: 1).to_a
  end

  test "returns paginated collection with correct metadata" do
    5.times { create :model }

    result = Model::Search.(page: 2, per: 2)

    assert_equal 2, result.current_page
    assert_equal 5, result.total_count
    assert_equal 3, result.total_pages
    assert_equal 2, result.size
  end

  test "combines multiple filters" do
    match = create :model, name: "Amy", email: "amy@example.com"
    create :model, name: "Amy", email: "amy@test.org"

    result = Model::Search.(name: "Amy", email: "example")

    assert_equal [match], result.to_a
  end
end
```

**Test Coverage Checklist**:
- No options returns all (default pagination)
- Each filter works independently
- Each filter handles empty strings
- Each filter handles no matches (use `assert_empty`)
- Pagination works correctly (page/per)
- Metadata is correct (current_page, total_count, total_pages, size)
- Multiple filters combine correctly (AND logic)

## Command Testing

### Testing Mandate Commands

Commands are tested independently from controllers:

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
    assert_equal "Test User", user.name
  end

  test "raises ValidationError with blank email" do
    error = assert_raises ValidationError do
      User::Create.(email: "", name: "Test", password: "secure123")
    end

    assert_includes error.errors[:email], "can't be blank"
  end

  test "is idempotent for creating users" do
    assert_idempotent_command do
      User::Create.(email: "test@example.com", name: "Test", password: "secure123")
    end
  end
end
```

### Mocking with Mocha

```ruby
class Exercise::SubmitTest < ActiveSupport::TestCase
  test "queues evaluation job after submission" do
    user = create(:user)
    exercise = create(:exercise)

    # Mock the job enqueueing
    EvaluateSubmissionJob.expects(:perform_later).once

    submission = Exercise::Submit.(user, exercise, "code")

    assert submission.persisted?
  end

  test "sends notification email on completion" do
    user = create(:user)
    exercise = create(:exercise)

    # Mock the mailer
    ExerciseMailer.expects(:completed).with(user, exercise).returns(mock(deliver_later: true))

    Exercise::Complete.(user, exercise)
  end
end
```

### WebMock Configuration

```ruby
# test/test_helper.rb
require 'webmock/minitest'

# Disable all external connections except allowed hosts
WebMock.disable_net_connect!(
  allow_localhost: true,
  allow: [
    "chromedriver.storage.googleapis.com",  # For system tests if added later
    "127.0.0.1"  # Local services
  ]
)

# Example of stubbing external API calls
class Payment::ProcessTest < ActiveSupport::TestCase
  test "processes Stripe payment successfully" do
    # Stub Stripe API
    stub_request(:post, "https://api.stripe.com/v1/charges")
      .with(
        body: { amount: 1000, currency: "usd", source: "tok_test" },
        headers: { 'Authorization' => 'Bearer sk_test_key' }
      )
      .to_return(
        status: 200,
        body: { id: "ch_123", status: "succeeded" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    charge = Payment::Process.(amount: 1000, token: "tok_test")

    assert_equal "ch_123", charge.stripe_id
    assert_equal "succeeded", charge.status
  end

  test "handles Stripe API errors" do
    stub_request(:post, "https://api.stripe.com/v1/charges")
      .to_return(status: 402, body: { error: { message: "Card declined" } }.to_json)

    assert_raises Payment::CardDeclinedError do
      Payment::Process.(amount: 1000, token: "tok_test")
    end
  end
end
```

## JSON Response Testing

### Custom Assertions

```ruby
# test/support/json_assertions.rb
module JsonAssertions
  def assert_json_response(expected)
    actual = response.parsed_body
    assert_equal expected.deep_stringify_keys, actual
  end

  def assert_json_structure(structure, data = response.parsed_body)
    structure.each do |key, expected_type|
      assert data.key?(key.to_s), "Expected key '#{key}' in JSON response"

      if expected_type.is_a?(Hash)
        assert_json_structure(expected_type, data[key.to_s])
      elsif expected_type.is_a?(Array) && expected_type.first.is_a?(Hash)
        data[key.to_s].each do |item|
          assert_json_structure(expected_type.first, item)
        end
      elsif expected_type
        assert data[key.to_s].is_a?(expected_type),
          "Expected '#{key}' to be #{expected_type}, got #{data[key.to_s].class}"
      end
    end
  end
end

# Usage in tests
class UsersControllerTest < ActionDispatch::IntegrationTest
  include JsonAssertions

  test "returns correct JSON structure" do
    get user_path(@user), headers: @headers, as: :json

    assert_json_structure({
      user: {
        id: Integer,
        email: String,
        name: String,
        created_at: String,
        progress: {
          lessons_completed: Integer,
          exercises_solved: Integer
        }
      }
    })
  end
end
```

## Support Files

### Test Helpers
- **Location**: `test/support/` directory
- **Purpose**: Shared test utilities, custom assertions, helper methods
- **Loading**: Automatically loaded via `test_helper.rb` if needed
- **Examples**: Authentication helpers, custom matchers, API response helpers

### Configuration
- **Test Helper**: Core test configuration in `test/test_helper.rb`
- **Environment**: Test-specific settings in `config/environments/test.rb`
- **Database**: Test database configuration in `config/database.yml`

## Quality Standards

### Before Committing
Always run these commands to ensure test quality:
1. **All tests pass**: `bin/rails test`
2. **Linting passes**: `bin/rubocop`
3. **Security scan clean**: `bin/brakeman`

### Test Coverage Goals
- **High coverage** for models and business logic
- **API endpoints** should have comprehensive request/response tests
- **Critical user flows** covered by integration tests
- **Edge cases and error scenarios** included in test suite

## Future Enhancements

When the codebase grows, consider adding:
- **System/End-to-end tests** using Capybara for complex workflows
- **Performance tests** for API response times
- **Contract tests** for external API integrations
- **Test data builders** for complex domain object creation