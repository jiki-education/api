# Controllers

This document describes controller patterns and conventions used in the Jiki API.

## Structure

API controllers are organized into four main namespaces:

```
app/controllers/
├── application_controller.rb    # Base controller with shared functionality
├── auth/                        # Devise authentication controllers (no auth required)
│   ├── sessions_controller.rb
│   ├── registrations_controller.rb
│   └── passwords_controller.rb
├── external/                    # Public unauthenticated endpoints
│   ├── base_controller.rb
│   └── concepts_controller.rb
├── internal/                    # Authenticated user endpoints
│   ├── base_controller.rb      # Enforces authentication
│   ├── concepts_controller.rb
│   ├── lessons_controller.rb
│   ├── levels_controller.rb
│   ├── projects_controller.rb
│   ├── user_lessons_controller.rb
│   └── user_levels_controller.rb
└── admin/                       # Admin-only endpoints
    ├── base_controller.rb      # Enforces auth + admin check
    ├── concepts_controller.rb
    ├── email_templates_controller.rb
    ├── levels_controller.rb
    ├── projects_controller.rb
    └── users_controller.rb
```

## ApplicationController

The base controller (`ApplicationController`) provides shared functionality for all API controllers.

### Authentication

**Authentication is NOT enforced globally.** Instead, it's enforced at the namespace level:

- **No auth required:** `External::BaseController`, `Auth::*` controllers
- **Auth required:** `Internal::BaseController` (via `before_action :authenticate_user!`)
- **Auth + admin required:** `Admin::BaseController` (via `before_action :authenticate_user!` and `before_action :ensure_admin!`)

**Development Mode:** URL-based authentication is available via `?user_id=X` query parameter. See `.context/auth.md` for details.

### Helper Methods

#### Error Rendering Helpers

ApplicationController provides reusable helper methods for consistent error responses. **Always use these helpers instead of writing inline error rendering.**

##### `render_validation_error(exception)`

Renders a validation error response for `ActiveRecord::RecordInvalid` exceptions.

**Usage:**
```ruby
def create
  resource = Resource::Create.(params)
  render json: { resource: SerializeResource.(resource) }
rescue ActiveRecord::RecordInvalid => e
  render_validation_error(e)
end
```

**Response:**
```json
{
  "error": {
    "type": "validation_error",
    "message": "Validation failed: Field can't be blank"
  }
}
```
**Status:** 422 Unprocessable Entity

##### `render_not_found(message)`

Renders a not found error response with a custom message.

**Usage:**
```ruby
def use_resource
  @resource = Resource.find(params[:id])
rescue ActiveRecord::RecordNotFound
  render_not_found("Resource not found")
end
```

**Response:**
```json
{
  "error": {
    "type": "not_found",
    "message": "Resource not found"
  }
}
```
**Status:** 404 Not Found

**Important:** Always check ApplicationController for existing error rendering helpers before writing inline error responses. This ensures consistency and reduces duplication.

#### `use_lesson!`

Finds a lesson by slug from the `params[:slug]` and assigns it to `@lesson`. Returns 404 with error JSON if not found.

**Usage:**
```ruby
class LessonsController < ApplicationController
  before_action :use_lesson!

  def show
    render json: { lesson: SerializeLesson.(@lesson) }
  end
end
```

**When to use:**
- Any controller action that needs to load a lesson by slug
- Provides consistent error handling for missing lessons
- Sets `@lesson` instance variable for use in the action

**Error Response:**
```json
{
  "error": {
    "type": "not_found",
    "message": "Lesson not found"
  }
}
```

## Controller Conventions

### Response Format

All API responses should be JSON. Use serializers to format data consistently:

```ruby
def index
  levels = Level.all
  render json: { levels: SerializeLevels.(levels) }
end
```

### Error Handling

**Always use ApplicationController helper methods for error rendering** (see Helper Methods section above):

- `render_validation_error(exception)` - For ActiveRecord::RecordInvalid exceptions
- `render_not_found(message)` - For ActiveRecord::RecordNotFound exceptions

**Only write inline error responses for unique error cases** not covered by existing helpers:

```ruby
render json: {
  error: {
    type: "error_type",
    message: "Human-readable message"
  }
}, status: :status_code
```

### Before Actions

Use `before_action` for common setup:
- `before_action :use_lesson!` - Load lesson by slug (defined in ApplicationController)
- `before_action :use_concept!` - Load concept by slug (defined in ApplicationController)
- `before_action :use_project!` - Load project by slug (defined in ApplicationController)
- `before_action :authenticate_user!` - Applied in `Internal::BaseController` and `Admin::BaseController`

### Testing

All controller actions should have tests covering:
- Successful responses with correct data
- Authentication guards (use `guard_incorrect_token!` macro)
- Error cases (404, validation errors, etc.)
- Serializer usage (mock serializers to verify they're called)

See `.context/testing.md` for detailed testing patterns.

### Controller Namespacing Pattern

**IMPORTANT:** Always use `class Namespace::ControllerName` format instead of module wrapping:

```ruby
# CORRECT: Use class Internal:: pattern
class Internal::LessonsController < Internal::BaseController
  # ...
end

# INCORRECT: Don't use module wrapping
module Internal
  class LessonsController < Internal::BaseController
    # ...
  end
end
```

**Why this pattern:**
- More concise and readable
- Standard Ruby namespacing convention
- Consistent with Rails best practices
- Easier to refactor and maintain

## Paginated Collection Endpoints

For endpoints that return paginated collections, follow this pattern:

**Controller Pattern**:
```ruby
class V1::Admin::ResourcesController < V1::Admin::BaseController
  def index
    resources = Resource::Search.(
      filter1: params[:filter1],
      filter2: params[:filter2],
      page: params[:page],
      per: params[:per]
    )

    render json: SerializePaginatedCollection.(
      resources,
      serializer: SerializeResources
    )
  end
end
```

**Key Points**:
- Use a `Resource::Search` command for filtering and pagination
- Pass all filter and pagination params to the command
- Use `SerializePaginatedCollection` to wrap results with metadata
- Always specify the collection serializer explicitly

**Example**: `Admin::UsersController` (app/controllers/admin/users_controller.rb:1)

## Admin Controllers

Admin controllers provide administrative access to resources and require admin privileges.

### Admin::BaseController

All admin controllers inherit from `Admin::BaseController`, which adds admin authorization on top of authentication.

**Key Features:**
- Inherits from `ApplicationController`
- Adds `before_action :authenticate_user!` for authentication
- Adds `before_action :ensure_admin!` for authorization
- Returns 403 Forbidden if user is not an admin

**Implementation:**
```ruby
class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  private
  def ensure_admin!
    return if current_user.admin?

    render json: {
      error: {
        type: "forbidden",
        message: "Admin access required"
      }
    }, status: :forbidden
  end
end
```

### Authentication vs Authorization

**Authentication** (Namespace Base Controllers):
- Verifies the user is logged in
- Returns 401 Unauthorized if not authenticated
- Handled by Devise's `authenticate_user!`
- Applied in `Internal::BaseController` and `Admin::BaseController`

**Authorization** (Admin::BaseController only):
- Verifies the authenticated user has admin privileges
- Returns 403 Forbidden if not an admin
- Handled by custom `ensure_admin!` method

### Admin Controller Example

```ruby
class Admin::EmailTemplatesController < Admin::BaseController
  before_action :set_email_template, only: %i[show update destroy]

  def index
    email_templates = EmailTemplate.all
    render json: {
      email_templates: SerializeEmailTemplates.(email_templates)
    }
  end

  def update
    email_template = EmailTemplate::Update.(@email_template, email_template_params)
    render json: {
      email_template: SerializeEmailTemplate.(email_template)
    }
  end

  private
  def set_email_template
    @email_template = EmailTemplate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found("Email template not found")
  end

  def email_template_params
    params.require(:email_template).permit(:subject, :body_mjml, :body_text)
  end
end
```

### Testing Admin Controllers

Admin controller tests should verify both authentication and authorization:

```ruby
class Admin::EmailTemplatesControllerTest < ApplicationControllerTest
  setup do
    @admin = create(:user, :admin)
    @headers = auth_headers_for(@admin)
  end

  # Test authentication (401)
  guard_incorrect_token! :admin_email_templates_path, method: :get

  # Test authorization (403)
  test "GET index returns 403 for non-admin users" do
    user = create(:user, admin: false)
    headers = auth_headers_for(user)

    get admin_email_templates_path, headers:, as: :json

    assert_response :forbidden
    assert_json_response({
      error: {
        type: "forbidden",
        message: "Admin access required"
      }
    })
  end

  # Test successful admin access (200)
  test "GET index returns templates for admin users" do
    get admin_email_templates_path, headers: @headers, as: :json

    assert_response :success
  end
end
```