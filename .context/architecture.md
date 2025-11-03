# Architecture

## Rails API Structure

### API-Only Configuration
- Rails 8.0.3 configured in API-only mode (`config.api_only = true`)
- Middleware stack optimized for API usage
- No view layer or asset pipeline
- JSON responses only

### Core Components

#### Action Cable
- WebSocket support enabled for real-time features
- Potential uses:
  - Live exercise feedback
  - Real-time test results
  - Progress notifications
  - Live collaboration features

#### Active Storage
- File upload handling for:
  - Exercise submissions
  - User avatars
  - Course materials
- Storage backends:
  - Local disk in development
  - AWS S3 in production

#### Active Job
- Background job processing for:
  - Email notifications
  - Analytics processing
  - I18n file generation
  - Heavy computations

## Database Design

### PostgreSQL Setup
- Database names: `jiki_development`, `jiki_test`, `jiki_production`
- Connection pooling: 5 connections (RAILS_MAX_THREADS)
- Production: AWS Aurora (following Exercism patterns)

### Expected Data Models

Based on business requirements:

#### User System
- User authentication and profiles
- Progress tracking
- Subscription management

#### Learning Content
- Lessons (compulsory/optional)
- Exercises with state management
- Submissions storage
- Linear progression tracking

#### Payment System
- PPP (Purchasing Power Parity) pricing
- Stripe integration
- Geographic detection

#### Internationalization
- Database-stored translations
- Generated i18n files for frontend

## API Design Patterns

### RESTful Endpoints
- Resource-based routing
- Standard HTTP methods
- JSON request/response format

### Versioning Strategy
- URL-based versioning planned (`/api/v1/`)
- Controllers in `app/controllers/api/v1/`
- Backward compatibility considerations

### Authentication Plan
- JWT tokens for stateless auth
- Suitable for:
  - React frontend
  - Mobile apps
  - Horizontal scaling on ECS

### Error Handling
- Consistent error response format
- HTTP status codes
- Detailed error messages in development
- Sanitized errors in production

## Integration Points

### Frontend Communication
- CORS configuration required
- JSON API specification
- WebSocket connections via Action Cable

### External Services
- Stripe for payments
- VPN detection API for PPP
- AWS services (S3, SES)
- Potential CDN integration

### Infrastructure
- ECS Fargate deployment
- Docker containerization
- Load balancer configuration
- Auto-scaling policies

## Testing Architecture

### Test Framework
- Minitest (Rails default)
- Parallel test execution
- Fixtures for test data

### Test Types
- Unit tests for models
- Integration tests for API endpoints
- System tests for critical flows
- Performance tests for bottlenecks

## Security Considerations

### API Security
- Rate limiting
- Request validation
- SQL injection prevention
- XSS protection (even in API)

### Authentication & Authorization
- Secure token generation
- Token expiration
- Role-based access control
- API key management

## Performance Optimization

### Caching Strategy
- Redis for session data
- Database query caching
- HTTP caching headers
- CDN for static assets

### Database Optimization
- Indexed foreign keys
- Query optimization
- N+1 query prevention
- Connection pooling

## Commands

Commands encapsulate business logic following the Command pattern using the Mandate gem.

### General Command Patterns

**Prefer Association Methods Over Manual Attribute Merging**:

When creating records that belong to a parent, use ActiveRecord association methods instead of manually merging foreign keys:

```ruby
# CORRECT: Use association method
class Lesson::Create
  include Mandate
  initialize_with :level, :attributes

  def call
    level.lessons.create!(attributes)  # ✅ Association handles level_id automatically
  end
end

# INCORRECT: Manual foreign key merging
class Lesson::Create
  include Mandate
  initialize_with :level, :attributes

  def call
    lesson_attributes = attributes.merge(level_id: level.id)  # ❌ Manual, error-prone
    Lesson.create!(lesson_attributes)
  end
end
```

**Why association methods are better:**
- ActiveRecord automatically sets the foreign key through the association
- More idiomatic Rails code
- Cleaner and less error-prone
- Leverages ActiveRecord's built-in association handling
- Reduces boilerplate code

**Examples**: `Lesson::Create` (app/commands/lesson/create.rb:1)

### Search Commands

Search commands handle filtering and pagination for collection endpoints. They follow a consistent pattern:

**Structure**:
```ruby
class Model::Search
  include Mandate

  DEFAULT_PAGE = 1
  DEFAULT_PER = 24

  def self.default_per
    DEFAULT_PER
  end

  def initialize(filter1: nil, filter2: nil, page: nil, per: nil)
    @filter1 = filter1
    @filter2 = filter2
    @page = page.present? && page.to_i.positive? ? page.to_i : DEFAULT_PAGE
    @per = per.present? && per.to_i.positive? ? per.to_i : self.class.default_per
  end

  def call
    @collection = Model.all

    apply_filter1!
    apply_filter2!

    @collection.page(page).per(per)
  end

  private
  attr_reader :filter1, filter2, :page, :per

  def apply_filter1!
    return if filter1.blank?

    @collection = @collection.where("column LIKE ?", "%#{filter1}%")
  end
end
```

**Key Patterns**:
- Use constants for default pagination values
- Class method `default_per` for override in tests
- Validate and coerce page/per parameters to positive integers
- Return Kaminari-paginated collection
- Use private filter methods with mutation (`!`)
- Early return in filters if parameter is blank
- Use LIKE queries for partial text matching

**Example**: `User::Search` (app/commands/user/search.rb:1)

## Monitoring & Observability

### Logging
- Request/response logging
- Error tracking
- Performance metrics
- Audit trails

### Metrics
- Response times
- Error rates
- Database performance
- Background job metrics