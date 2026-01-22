# Concepts

This document describes the Concept model and its role in the Jiki learning platform.

## Purpose

Concepts represent fundamental programming topics that students learn throughout the curriculum. Each concept has educational content (markdown-based), optional video resources, and is used to organize and explain core programming ideas.

## Model Structure

### Database Schema

**Table**: `concepts`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | integer | Primary key | Auto-incrementing ID |
| `title` | string | NOT NULL | Concept name (e.g., "Strings", "Arrays") |
| `slug` | string | NOT NULL, UNIQUE | URL-friendly identifier |
| `description` | text | NOT NULL | Brief 1-2 sentence overview |
| `content_markdown` | text | NOT NULL | Full educational content in Markdown |
| `content_html` | text | NOT NULL | Auto-generated HTML from markdown |
| `standard_video_provider` | string | NULL | Video platform for free users ("youtube" or "mux") |
| `standard_video_id` | string | NULL | Video ID for standard tier |
| `premium_video_provider` | string | NULL | Video platform for premium users ("youtube" or "mux") |
| `premium_video_id` | string | NULL | Video ID for premium tier |
| `parent_concept_id` | bigint | NULL, FK | Reference to parent concept for hierarchy |
| `children_count` | integer | NOT NULL, DEFAULT 0 | Counter cache for number of child concepts |
| `created_at` | datetime | NOT NULL | Timestamp |
| `updated_at` | datetime | NOT NULL | Timestamp |

**Indexes**:
- Unique index on `slug`
- Index on `parent_concept_id`

**Foreign Keys**:
- `parent_concept_id` references `concepts(id)` with `ON DELETE SET NULL`

### Model: `app/models/concept.rb`

**Associations**:
- `belongs_to :parent` - Optional reference to parent concept (self-referential)
- `has_many :children` - Child concepts (dependent: :nullify)

**Validations**:
- `title`: Required
- `slug`: Required, unique
- `description`: Required
- `content_markdown`: Required
- `standard_video_provider`: Must be "youtube" or "mux" (if present)
- `premium_video_provider`: Must be "youtube" or "mux" (if present)
- `parent_concept_id`: Cannot create circular references

**Callbacks**:
- `before_validation :generate_slug, on: :create` - Auto-generates kebab-case slug from title if not provided
- `before_save :parse_markdown, if: :content_markdown_changed?` - Converts markdown to HTML when content changes
- Counter cache automatically maintained for `children_count`

**Methods**:
- `to_param` - Returns slug for URL generation
- `ancestors` - Returns array of ancestor concepts from root to immediate parent (single SQL query using recursive CTE)
- `ancestor_ids` - Returns array of ancestor concept IDs
- `root?` - Returns true if concept has no parent
- `has_children?` - Returns true if concept has child concepts

## Markdown Processing

### Utils::Markdown::Parse Command

**Location**: `app/commands/utils/markdown/parse.rb`

**Purpose**: Converts Markdown to sanitized HTML

**Dependencies**:
- `commonmarker` (~> 1.0) - GitHub Flavored Markdown parser
- `loofah` (~> 2.22) - HTML sanitization

**Features**:
- Converts GitHub Flavored Markdown to HTML
- Removes HTML comments for security
- Sanitizes output to prevent XSS attacks
- Supports smart punctuation
- Syntax highlighting for code blocks
- Memoized for performance

**Usage**:
```ruby
html = Utils::Markdown::Parse.("# Hello\n\nWorld")
# => "<h1>Hello</h1>\n<p>World</p>"
```

**Extensibility**: Built on CommonMarker's extensible rendering system. Future enhancements can be added by customizing the rendering pipeline.

## Video Provider Integration

Concepts support two tiers of video content:

### Standard Videos (Free Users)
- `standard_video_provider`: Platform hosting the video
- `standard_video_id`: Video identifier on that platform

### Premium Videos (Paid Users)
- `premium_video_provider`: Platform hosting the video
- `premium_video_id`: Video identifier on that platform

### Supported Providers
- **youtube**: YouTube videos
- **mux**: Mux video platform

## API Endpoints

Concepts are accessible via both admin and user-facing endpoints.

### Admin Routes

**Namespace**: `v1/admin/concepts`

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| GET | `/v1/admin/concepts` | index | List all concepts (paginated, searchable) |
| POST | `/v1/admin/concepts` | create | Create new concept |
| GET | `/v1/admin/concepts/:id` | show | Show concept by slug (includes markdown) |
| PATCH | `/v1/admin/concepts/:id` | update | Update concept by slug |
| DELETE | `/v1/admin/concepts/:id` | destroy | Delete concept by slug |

**Note**: The `:id` parameter accepts slugs (e.g., `/v1/admin/concepts/strings`)

#### Admin Controller: `app/controllers/v1/admin/concepts_controller.rb`

**Authorization**: Requires admin privileges (inherits from `V1::Admin::BaseController`)

**Search/Filtering** (`index` action):
- `title`: Partial, case-insensitive title search
- `page`: Page number for pagination (default: 1)
- `per`: Results per page (default: 24)

**Response Format**:
- Uses `SerializePaginatedCollection` for index
- Returns `content_markdown` (NOT `content_html`) in admin responses
- Collection serializer excludes `content_markdown` to reduce payload size

### User-Facing Routes

**Namespace**: `v1/concepts`

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| GET | `/v1/concepts` | index | List unlocked concepts (paginated, searchable) |
| GET | `/v1/concepts/:slug` | show | Show unlocked concept by slug (includes HTML) |

**Note**: Uses `:slug` parameter (e.g., `/v1/concepts/strings`)

#### User Controller: `app/controllers/v1/concepts_controller.rb`

**Authentication**: Requires authenticated user (inherits from `ApplicationController`)

**Access Control**:
- By default, only unlocked concepts are returned
- Pass `unscoped=true` query parameter to bypass unlock filtering (for admin/preview purposes)

**Search/Filtering** (`index` action):
- `title`: Partial, case-insensitive title search
- `page`: Page number for pagination (default: 1)
- `per`: Results per page (default: 24)
- `unscoped`: Set to "true" to return all concepts regardless of unlock status

**Show Action Behavior**:
- Returns 403 Forbidden if concept is locked for the user
- Use `unscoped=true` to bypass lock checking
- Supports slug history (old slugs redirect to current concept)

**Response Format**:
- Uses `SerializePaginatedCollection` for index
- Returns `content_html` (NOT `content_markdown`) in user responses
- Collection serializer excludes `content_html` to reduce payload size
- All responses exclude the `id` field (uses slugs for identification)

## Commands

### Concept::Search

**Purpose**: Search and paginate concepts with optional user-based filtering

**Parameters**:
- `title` (optional): Filter by title (partial match, case-insensitive)
- `page` (optional): Page number (default: 1)
- `per` (optional): Results per page (default: 24)
- `user` (optional): User instance for filtering to unlocked concepts only

**Returns**: Kaminari-paginated collection

**Usage**:
```ruby
# Admin: Get all concepts
Concept::Search.(title: "String", page: 1)

# User: Get only unlocked concepts
Concept::Search.(title: "String", user: current_user)

# User: Get all concepts (unscoped)
Concept::Search.(title: "String", user: nil)
```

### Concept::Create

**Purpose**: Create a new concept with validation

**Parameters**:
- `attributes`: Hash of concept attributes

**Returns**: Created concept

**Raises**: `ActiveRecord::RecordInvalid` on validation failure

### Concept::Update

**Purpose**: Update an existing concept with validation

**Parameters**:
- `concept`: Concept instance to update
- `attributes`: Hash of attributes to update

**Returns**: Updated concept

**Raises**: `ActiveRecord::RecordInvalid` on validation failure

## Serializers

### Admin Serializers

#### SerializeAdminConcept

**Purpose**: Serialize a single concept for admin view/edit

**Includes**:
- All concept fields including `id`
- `content_markdown` (for editing)
- `children_count` - Number of child concepts
- `ancestors` - Array of ancestor concepts with `id`, `title`, `slug` (ordered root to parent)
- Does NOT include `content_html` (generated on save)

#### SerializeAdminConcepts

**Purpose**: Serialize concepts for admin list view

**Includes**:
- Basic fields (id, title, slug, description)
- Video provider information
- `children_count` - Number of child concepts
- Does NOT include `content_markdown` (too large for lists)
- Does NOT include `ancestors` (not needed in list view)

### User-Facing Serializers

#### SerializeConcept

**Purpose**: Serialize a single concept for user viewing

**Includes**:
- Basic fields (title, slug, description)
- `content_html` (for display)
- Video provider information
- `children_count` - Number of child concepts
- `ancestors` - Array of ancestor concepts with `title`, `slug` only (ordered root to parent)
- Does NOT include `id` (uses slug for identification)
- Does NOT include `content_markdown` (internal only)

#### SerializeConcepts

**Purpose**: Serialize concepts for user list view

**Includes**:
- Basic fields (title, slug, description)
- Video provider information
- `children_count` - Number of child concepts
- Does NOT include `id` (uses slug for identification)
- Does NOT include `content_html` (too large for lists)
- Does NOT include `content_markdown` (internal only)
- Does NOT include `ancestors` (not needed in list view)

## Usage Examples

### Creating a Concept

```ruby
Concept::Create.({
  title: "Strings",
  description: "Learn about text manipulation in programming",
  content_markdown: "# Strings\n\nStrings are sequences of characters...",
  standard_video_provider: "youtube",
  standard_video_id: "abc123"
})
```

### Searching Concepts

```ruby
# Search by title
concepts = Concept::Search.(title: "String", page: 1, per: 10)

# Get all concepts
concepts = Concept::Search.()
```

### Updating Content

```ruby
concept = Concept.find_by!(slug: "strings")
Concept::Update.(concept, {
  content_markdown: "# Updated Content\n\nNew information..."
})
# content_html is automatically regenerated
```

### Creating Hierarchical Concepts

```ruby
# Create a parent concept
loops = Concept::Create.({
  title: "Loops",
  description: "Learn about iteration",
  content_markdown: "# Loops\n\nLoops allow repetition..."
})

# Create a child concept
for_loops = Concept::Create.({
  title: "For Loops",
  description: "Iterate with for loops",
  content_markdown: "# For Loops\n\nFor loops...",
  parent_concept_id: loops.id
})

# Query hierarchy
for_loops.parent          # => loops concept
for_loops.ancestors       # => [loops]
for_loops.root?           # => false
loops.children            # => [for_loops]
loops.children_count      # => 1
loops.has_children?       # => true
```

## Testing

**Test Coverage**: Complete 1-1 mapping for all components

- Model: `test/models/concept_test.rb` - Includes hierarchy tests
- Commands: `test/commands/concept/*_test.rb`
  - `test/commands/concept/search_test.rb` - Includes user filtering tests
  - `test/commands/concept/create_test.rb` - Includes parent assignment
  - `test/commands/concept/update_test.rb` - Includes parent changes, circular reference
- Markdown Parser: `test/commands/utils/markdown/parse_test.rb`
- Controllers:
  - Admin: `test/controllers/admin/concepts_controller_test.rb`
  - User: `test/controllers/internal/concepts_controller_test.rb`
  - External: `test/controllers/external/concepts_controller_test.rb`
- Serializers:
  - `test/serializers/serialize_admin_concept_test.rb`
  - `test/serializers/serialize_admin_concepts_test.rb`
  - `test/serializers/serialize_concept_test.rb`
  - `test/serializers/serialize_concepts_test.rb`
- Factory: `test/factories/concepts.rb` - Includes `:with_parent`, `:with_children` traits

## Design Decisions

### Why Separate Markdown and HTML Fields?

- **Performance**: Pre-rendered HTML avoids parsing on every request
- **Consistency**: HTML is generated once and guaranteed to match markdown
- **Audit Trail**: Markdown is the source of truth, easily diffable in version control

### Why Slug-Based URLs for Admin?

- **Consistency**: Matches public-facing API patterns
- **Readability**: URLs like `/admin/concepts/strings` are more meaningful than `/admin/concepts/42`
- **Stability**: Slugs don't change when content is reorganized

### Why Two Video Tiers?

- **Business Model**: Supports freemium model with premium content
- **Flexibility**: Different videos can be used for different user tiers
- **Quality Options**: Premium users might get higher quality or longer videos

## Concept Hierarchy

Concepts support parent-child relationships for hierarchical organization:

```
Loops (parent)
├── For Loops
├── While Loops
├── Nested Loops
└── Loop Control
```

### Key Features

- **Unlimited nesting depth** - Concepts can have children at any level
- **Circular reference prevention** - Validation prevents cycles (A → B → A)
- **Counter cache** - `children_count` automatically maintained
- **Efficient ancestor queries** - Single SQL query using recursive CTE
- **Nullify on delete** - Deleting a parent makes children become root concepts

### Seed Data

Hierarchical concepts are loaded from `db/seeds/concepts.json` using `parent_slug`:

```json
{
  "slug": "for-loops",
  "title": "For Loops",
  "parent_slug": "loops"
}
```

The seed loader uses a multi-pass approach to resolve parent references regardless of ordering.

## Future Enhancements

Potential additions to the Concept system:

- **Exercises**: Associate practice exercises with concepts
- **User Progress**: Track which concepts users have completed
- **Related Concepts**: Cross-reference related topics (siblings, prerequisites)
- **Difficulty Levels**: Categorize concepts by complexity
- **Tags**: Flexible categorization beyond single title
