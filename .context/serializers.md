# Serializers

Serializers in this application transform model objects into JSON-ready hash structures. All serializers use the Mandate gem for a consistent, callable interface.

## Pagination Serializers

### SerializePaginatedCollection

For endpoints that return paginated results, use `SerializePaginatedCollection` to wrap the data with pagination metadata.

**Purpose**: Provides consistent pagination response format across all paginated endpoints.

**Usage Pattern**:
```ruby
# In controller
users = User::Search.(name: params[:name], page: params[:page])

render json: SerializePaginatedCollection.(
  users,
  serializer: SerializeUsers
)
```

**Response Format**:
```json
{
  "results": [...serialized data...],
  "meta": {
    "current_page": 1,
    "total_pages": 3,
    "total_count": 42
  }
}
```

**Parameters**:
- `collection` (required) - Kaminari-paginated collection
- `serializer` (optional) - Serializer class to use for the collection
- `data` (optional) - Pre-serialized data (overrides serializer)
- `serializer_args` (optional) - Additional positional arguments for serializer
- `serializer_kwargs` (optional) - Additional keyword arguments for serializer
- `meta` (optional) - Additional metadata to merge with pagination info

**Example with pre-serialized data**:
```ruby
serialized_users = SerializeUsers.(users)
SerializePaginatedCollection.(users, data: serialized_users)
```

**Example with additional metadata**:
```ruby
SerializePaginatedCollection.(
  users,
  serializer: SerializeUsers,
  meta: { filter_applied: true }
)
```

## Pattern

### Using Mandate

All serializers **must** use Mandate with the `initialize_with` pattern:

```ruby
class SerializeLesson
  include Mandate

  initialize_with :lesson

  def call
    {
      slug: lesson.slug,
      type: lesson.type,
      data: lesson.data
    }
  end
end
```

### Usage

Serializers are called with the `.()` shorthand:

```ruby
# In controllers
def show
  lesson = Lesson.find_by!(slug: params[:lesson_slug])
  render json: SerializeLesson.(lesson)
end

# Composing serializers
def call
  levels_with_includes.map do |level|
    SerializeLevel.(level)
  end
end
```

## Key Principles

### 1. Simple Data Transformation

Serializers transform models to hashes. Keep them focused on this single responsibility:

**IMPORTANT**: Do not include `created_at` or `updated_at` timestamp fields in serialized output unless there is a specific business requirement for the client to display or use them. Timestamps add unnecessary data to API responses and increase payload size.

```ruby
class SerializeExerciseSubmission
  include Mandate

  initialize_with :submission

  def call
    {
      uuid: submission.uuid,
      lesson_slug: submission.lesson.slug,
      files: submission.files.map { |file| serialize_file(file) }
    }
  end

  private
  def serialize_file(file)
    {
      filename: file.filename,
      digest: file.digest
    }
  end
end
```

### 2. Performance Optimization

Include related data in the serializer when needed to avoid N+1 queries:

```ruby
class SerializeLevels
  include Mandate

  initialize_with :levels

  def call
    levels_with_includes.map do |level|
      SerializeLevel.(level)
    end
  end

  def levels_with_includes
    levels.to_active_relation.includes(:lessons)
  end
end
```

### 3. Nested Serialization

Use private methods or inline blocks for nested data:

```ruby
# Option 1: Private method (preferred for reusability)
def call
  {
    files: submission.files.map { |file| serialize_file(file) }
  }
end

private
def serialize_file(file)
  { filename: file.filename, digest: file.digest }
end

# Option 2: Inline (acceptable for simple cases)
def call
  {
    lessons: level.lessons.map { |lesson| { slug: lesson.slug, type: lesson.type } }
  }
end
```

### 4. Delegating to Other Serializers

Compose serializers by calling them within each other:

```ruby
class SerializeLevels
  include Mandate

  initialize_with :levels

  def call
    levels_with_includes.map do |level|
      SerializeLevel.(level)  # Delegating to another serializer
    end
  end

  def levels_with_includes
    levels.to_active_relation.includes(:lessons)
  end
end
```

## Anti-Patterns

### ❌ Don't Use Custom Call Methods

Never implement custom `self.call` methods:

```ruby
# ❌ WRONG
class SerializeLesson
  def self.call(lesson)
    new(lesson).()
  end

  def initialize(lesson)
    @lesson = lesson
  end

  def call
    { slug: @lesson.slug }
  end
end
```

Instead, use Mandate:

```ruby
# ✅ CORRECT
class SerializeLesson
  include Mandate

  initialize_with :lesson

  def call
    { slug: lesson.slug }
  end
end
```

### ❌ Don't Add Business Logic

Serializers transform data, they don't contain business logic:

```ruby
# ❌ WRONG - business logic in serializer
def call
  {
    slug: lesson.slug,
    status: lesson.completed? ? 'done' : 'pending'  # Logic should be in model/command
  }
end

# ✅ CORRECT - delegate to model
def call
  {
    slug: lesson.slug,
    status: lesson.status  # Model method handles logic
  }
end
```

### ❌ Don't Format in Controllers

Keep formatting in serializers, not controllers:

```ruby
# ❌ WRONG
def show
  lesson = Lesson.find_by!(slug: params[:lesson_slug])
  render json: {
    slug: lesson.slug,
    type: lesson.type
  }
end

# ✅ CORRECT
def show
  lesson = Lesson.find_by!(slug: params[:lesson_slug])
  render json: SerializeLesson.(lesson)
end
```

## File Location

All serializers live in `app/serializers/` with the naming convention `serialize_<model>.rb`:

```
app/serializers/
├── serialize_lesson.rb
├── serialize_level.rb
├── serialize_levels.rb
├── serialize_user_lesson.rb
├── serialize_user_levels.rb
└── serialize_exercise_submission.rb
```

## Examples

### Simple Object Serialization

```ruby
class SerializeLesson
  include Mandate

  initialize_with :lesson

  def call
    {
      slug: lesson.slug,
      type: lesson.type,
      data: lesson.data
    }
  end
end
```

### Collection Serialization

```ruby
class SerializeLevels
  include Mandate

  initialize_with :levels

  def call
    levels_with_includes.map do |level|
      SerializeLevel.(level)
    end
  end

  def levels_with_includes
    levels.to_active_relation.includes(:lessons)
  end
end
```

### Nested Data Serialization

```ruby
class SerializeLevel
  include Mandate

  initialize_with :level

  def call
    {
      slug: level.slug,
      lessons: level.lessons.map { |lesson| { slug: lesson.slug, type: lesson.type } }
    }
  end
end
```

### Complex Nested Serialization

```ruby
class SerializeExerciseSubmission
  include Mandate

  initialize_with :submission

  def call
    {
      uuid: submission.uuid,
      lesson_slug: submission.lesson.slug,
      files: submission.files.map { |file| serialize_file(file) }
    }
  end

  private
  def serialize_file(file)
    {
      filename: file.filename,
      digest: file.digest
    }
  end
end
```

## Testing Serializers

Test serializers in controller tests by asserting on the JSON response structure:

```ruby
test "GET show returns serialized lesson" do
  lesson = create(:lesson, slug: "hello-world", type: "coding")

  get v1_lesson_path(lesson_slug: lesson.slug),
    headers: @headers,
    as: :json

  assert_response :success
  assert_json_response({
    slug: "hello-world",
    type: "coding",
    data: lesson.data
  })
end
```

Direct serializer unit tests are rarely needed as controller integration tests provide sufficient coverage.
