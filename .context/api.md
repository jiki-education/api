# API Architecture

The Jiki API provides RESTful endpoints for the learning platform. This document describes the architecture, patterns, and conventions used throughout the API.

## Overview

The API is a Rails 8 API-only application that:
- Serves the Jiki frontend application
- Provides endpoints for mobile applications
- Supports the command-line interface (future)
- Integrates with external services (Stripe, email, etc.)

## Architecture Principles

### 1. Thin Controllers

Controllers are thin wrappers that:
- Accept HTTP requests
- Delegate business logic to commands
- Handle exceptions
- Return appropriate HTTP responses

```ruby
class UsersController < ApplicationController
  def create
    user = User::Create.(user_params)
    render json: { user: SerializeUser.(user) }, status: :created
  rescue ValidationError => e
    render_400(:failed_validations, errors: e.errors)
  end
end
```

### 2. Command Pattern for Business Logic

All business logic lives in command objects (see [`commands.md`](./commands.md)):
- Controllers never contain business logic
- Commands handle validation, authorization, and operations
- Commands return values or raise exceptions

### 3. Consistent Error Handling

Standardized error responses across all endpoints:
- Use exception handling rather than conditional responses
- Consistent error format with type and message
- Appropriate HTTP status codes

## Authentication

### Bearer Token Authentication

All API endpoints require Bearer token authentication:

```http
Authorization: Bearer <auth_token>
```

### Implementation

```ruby
class ApplicationController < ActionController::API
  before_action :authenticate_user!

  private

  def authenticate_user!
    authenticate_with_http_token do |token|
      @current_user = User::AuthToken.find_by!(token: token).user
    end
  rescue ActiveRecord::RecordNotFound
    render_401
  end

  def current_user
    @current_user
  end
end
```

### Generating Tokens

```ruby
class User::GenerateAuthToken
  include Mandate

  initialize_with :user

  def call
    User::AuthToken.create!(
      user: user,
      token: SecureRandom.hex(32),
      expires_at: 30.days.from_now
    )
  end
end
```

## Error Handling

### Standard Error Responses

All errors follow a consistent JSON structure:

```json
{
  "error": {
    "type": "validation_error",
    "message": "Validation failed",
    "errors": {
      "email": ["is invalid", "is already taken"],
      "password": ["is too short"]
    }
  }
}
```

### Error Response Helpers

ApplicationController provides standardized error helpers:

```ruby
class ApplicationController < ActionController::API
  private

  def render_400(type, errors: nil, message: nil)
    render_error(400, type, errors: errors, message: message)
  end

  def render_401(type = :invalid_auth_token)
    render_error(401, type)
  end

  def render_403(type = :forbidden)
    render_error(403, type)
  end

  def render_404(type = :not_found)
    render_error(404, type)
  end

  def render_422(type, message: nil)
    render_error(422, type, message: message)
  end

  def render_error(status, type, errors: nil, message: nil)
    message ||= I18n.t("api.errors.#{type}", default: type.to_s.humanize)

    response = {
      error: {
        type: type,
        message: message
      }
    }

    response[:error][:errors] = errors if errors.present?

    render json: response, status: status
  end
end
```

### Common Error Types

```ruby
# 400 Bad Request
render_400(:validation_error, errors: { email: ["is invalid"] })
render_400(:invalid_params)

# 401 Unauthorized
render_401  # Default: invalid_auth_token
render_401(:token_expired)

# 403 Forbidden
render_403(:insufficient_permissions)
render_403(:exercise_locked)

# 404 Not Found
render_404(:user_not_found)
render_404(:lesson_not_found)

# 422 Unprocessable Entity
render_422(:already_completed)
render_422(:prerequisite_not_met)
```

## Request/Response Patterns

### Request Parameters

Use strong parameters for security:

```ruby
private

def user_params
  params.require(:user).permit(:email, :name, :password)
end

def lesson_params
  params.permit(:title, :content, :position)
end
```

### Response Serialization

Use serializer commands for consistent JSON output:

```ruby
class SerializeUser
  include Mandate

  initialize_with :user

  def call
    {
      id: user.id,
      email: user.email,
      name: user.name,
      created_at: user.created_at.iso8601,
      progress: {
        lessons_completed: user.lessons_completed_count,
        exercises_solved: user.exercises_solved_count
      }
    }
  end
end
```

### Pagination

For endpoints returning collections:

```ruby
def index
  lessons = Lesson::Search.(
    current_user,
    page: params[:page] || 1,
    per: params[:per] || 20
  )

  render json: {
    lessons: lessons.map { |l| SerializeLesson.(l) },
    meta: {
      current_page: lessons.current_page,
      total_pages: lessons.total_pages,
      total_count: lessons.total_count,
      per_page: lessons.limit_value
    }
  }
end
```

## RESTful Endpoints

### Standard CRUD Operations

```ruby
class LessonsController < ApplicationController
  # GET /lessons
  def index
    lessons = Lesson::List.(current_user, params)
    render json: { lessons: lessons.map { |l| SerializeLesson.(l) } }
  end

  # GET /lessons/:id
  def show
    lesson = Lesson::Find.(current_user, params[:id])
    render json: { lesson: SerializeLesson.(lesson) }
  rescue LessonNotFoundError
    render_404(:lesson_not_found)
  end

  # POST /lessons
  def create
    lesson = Lesson::Create.(current_user, lesson_params)
    render json: { lesson: SerializeLesson.(lesson) }, status: :created
  rescue ValidationError => e
    render_400(:validation_error, errors: e.errors)
  end

  # PATCH /lessons/:id
  def update
    lesson = Lesson::Update.(current_user, params[:id], lesson_params)
    render json: { lesson: SerializeLesson.(lesson) }
  rescue LessonNotFoundError
    render_404(:lesson_not_found)
  rescue ValidationError => e
    render_400(:validation_error, errors: e.errors)
  end

  # DELETE /lessons/:id
  def destroy
    Lesson::Destroy.(current_user, params[:id])
    head :no_content
  rescue LessonNotFoundError
    render_404(:lesson_not_found)
  end
end
```

### Custom Actions

For non-CRUD operations, use descriptive action names:

```ruby
class LessonsController < ApplicationController
  # POST /lessons/:id/complete
  def complete
    lesson = Lesson::Complete.(current_user, params[:id])
    render json: {
      lesson: SerializeLesson.(lesson),
      unlocked: lesson.unlocked_lessons.map { |l| SerializeLesson.(l) }
    }
  rescue AlreadyCompletedError
    render_422(:already_completed)
  end

  # POST /lessons/:id/reset
  def reset
    lesson = Lesson::Reset.(current_user, params[:id])
    render json: { lesson: SerializeLesson.(lesson) }
  end
end
```

## Route Organization

Routes are organized logically in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # Health check
  get "/health", to: "health#show"

  # Authentication
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # User management
  resources :users, only: [:show, :create, :update] do
    member do
      post :reset_password
      patch :update_password
    end
  end

  # Learning content
  resources :tracks do
    resources :lessons do
      member do
        post :complete
        post :reset
      end
    end

    resources :exercises do
      member do
        post :submit
        get :hint
      end
    end
  end

  # Progress tracking
  namespace :progress do
    get :overview
    get :detailed
  end
end
```

## Testing API Controllers

### Controller Test Structure

**IMPORTANT**: Always use `assert_json_response` for testing complete JSON responses. This makes tests more maintainable and catches unexpected response changes.

```ruby
require "test_helper"

class UsersControllerTest < ApplicationControllerTest
  setup do
    setup_user
  end

  # Test authentication requirements using guard macro
  guard_incorrect_token! :users_path, method: :post

  # Test successful operations
  test "creates user with valid params" do
    post users_path,
      params: { user: { email: "test@example.com", name: "Test", password: "secure123" } },
      headers: @headers,
      as: :json

    assert_response :created
    assert_json_response({
      user: {
        id: User.last.id,
        email: "test@example.com",
        name: "Test"
      }
    })
  end

  # Test error handling
  test "returns validation errors for invalid params" do
    post users_path,
      params: { user: { email: "invalid" } },
      headers: @headers,
      as: :json

    assert_response :bad_request
    assert_json_response({
      error: {
        type: "validation_error",
        message: "Validation failed",
        errors: { email: ["is invalid"] }
      }
    })
  end
end
```

**Key Principles:**
- Use `assert_json_response` instead of manual `response.parsed_body` assertions
- Use `guard_incorrect_token!` macro for authentication tests
- Inherit from `ApplicationControllerTest` for API controller tests
- Use `setup_user` helper to create authenticated user and headers

### Testing Commands and Serializers in Controllers

Mock commands and serializers to test controller behavior in isolation:

```ruby
test "delegates to User::Create command" do
  user = create(:user)
  User::Create.expects(:call).with(
    email: "test@example.com",
    name: "Test",
    password: "secure123"
  ).returns(user)

  post users_path,
    params: { user: { email: "test@example.com", name: "Test", password: "secure123" } },
    headers: @headers,
    as: :json

  assert_response :created
end

test "handles command exceptions" do
  error = ValidationError.new(email: ["is invalid"])
  User::Create.expects(:call).raises(error)

  post users_path,
    params: { user: { email: "invalid" } },
    headers: @headers,
    as: :json

  assert_response :bad_request
  assert_json_response({
    error: {
      type: "validation_error",
      errors: { email: ["is invalid"] }
    }
  })
end

test "uses SerializeUser for response" do
  user = create(:user)
  serialized_data = { id: user.id, email: user.email }

  SerializeUser.expects(:call).with(user).returns(serialized_data)

  get user_path(user), headers: @headers, as: :json

  assert_response :success
  assert_json_response({ user: serialized_data })
end
```

**Important**: Test that serializers are called, not their output. Serializer behavior belongs in serializer tests.

## API Versioning

When versioning becomes necessary:

```ruby
namespace :api do
  namespace :v1 do
    resources :users
    resources :lessons
  end

  namespace :v2 do
    resources :users  # New user structure
    resources :courses  # Renamed from lessons
  end
end
```

## Performance Considerations

### Caching

Use Rails caching for expensive operations:

```ruby
def show
  lesson = Rails.cache.fetch("lesson_#{params[:id]}_#{current_user.id}", expires_in: 1.hour) do
    Lesson::Find.(current_user, params[:id])
  end
  render json: { lesson: SerializeLesson.(lesson) }
end
```

### N+1 Query Prevention

Use includes in commands to prevent N+1 queries:

```ruby
class Lesson::List
  include Mandate

  initialize_with :user

  def call
    user.accessible_lessons
      .includes(:exercises, :prerequisites)
      .order(:position)
  end
end
```

### Rate Limiting

Consider implementing rate limiting for sensitive endpoints:

```ruby
class ApplicationController < ActionController::API
  # Using rack-attack or similar
  throttle("api/ip", limit: 100, period: 1.minute) do |req|
    req.ip
  end

  throttle("api/user", limit: 1000, period: 1.hour) do |req|
    req.env["current_user"]&.id
  end
end
```

## Security Best Practices

1. **Always use strong parameters** to filter input
2. **Authenticate all endpoints** except public ones
3. **Authorize in commands**, not controllers
4. **Sanitize user input** before database operations
5. **Use HTTPS** in production
6. **Implement CORS** properly for frontend access
7. **Rate limit** sensitive operations
8. **Log security events** for monitoring

## Integration with Frontend

The API is designed to work seamlessly with modern frontend frameworks:

### CORS Configuration

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Jiki.config.frontend_base_url
    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

**Note**: Uses `Jiki.config.frontend_base_url` from config gem settings. Never use `ENV` variables directly in application code.

### Response Headers

Include helpful headers for frontend integration:

```ruby
class ApplicationController < ActionController::API
  after_action :set_response_headers

  private

  def set_response_headers
    response.headers["X-Request-Id"] = request.uuid
    response.headers["X-Runtime"] = response.headers["X-Runtime"]
  end
end
```