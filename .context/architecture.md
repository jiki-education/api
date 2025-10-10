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

### LLM Integration
- **LLM Proxy Service**: Node.js service (port 3064) for AI-powered translations
- **Gemini API**: Google's Gemini for translation tasks
- **Async Callback Pattern**: Fire-and-forget with callbacks to SPI endpoints
- **Redis Streaming**: Future support for real-time translation updates

### External Services
- Stripe for payments
- VPN detection API for PPP
- AWS services (S3, SES)
- Google Gemini API for translations
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