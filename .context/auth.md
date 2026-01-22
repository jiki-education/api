# Authentication Architecture

This document describes the authentication system for the Jiki API and its integration with the frontend.

## Architecture Overview

### Technology Stack
- **Backend**: Devise for Rails API with session-based authentication
- **Session Storage**: Encrypted cookies (`jiki_session`)
- **OAuth Ready**: Database schema includes provider ID fields

### How Session-Based Authentication Works

The API uses traditional Rails session cookies for authentication:

```
# Request with session cookie (automatic with credentials: 'include')
Request: Cookie: jiki_session=encrypted_session_data
```

Rails encrypts the session data (including `user_id`) into an httpOnly, secure cookie. The cookie is automatically sent with every request when `credentials: 'include'` is set on fetch calls.

### Authentication Flow

#### Registration
1. User fills registration form on frontend
2. Frontend POSTs to `/auth/signup`
3. API creates user, establishes session
4. API returns user data (session cookie set automatically)
5. Frontend updates auth state

#### Login
1. User enters credentials on frontend
2. Frontend POSTs to `/auth/login`
3. API validates credentials, establishes session
4. API returns user data (session cookie set automatically)
5. Frontend updates auth state

#### Logout
1. Frontend DELETEs to `/auth/logout`
2. API clears the session
3. Frontend clears auth state

#### Password Reset
1. User requests reset on frontend
2. Frontend POSTs email to `/auth/password`
3. API sends email with frontend reset URL + token
4. User clicks link, lands on frontend reset form
5. Frontend PATCHes new password + token to `/auth/password`
6. API validates token, updates password

## API Endpoints

### Authentication Endpoints

#### POST /auth/signup
Register a new user account.

**Request:**
```json
{
  "user": {
    "email": "user@example.com",
    "password": "secure_password123",
    "password_confirmation": "secure_password123",
    "name": "John Doe"
  }
}
```

**Success Response (201):**
```json
{
  "user": {
    "id": 123,
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

**Error Response (422):**
```json
{
  "error": {
    "type": "validation_error",
    "message": "Validation failed",
    "errors": {
      "email": ["has already been taken"],
      "password": ["is too short (minimum is 6 characters)"]
    }
  }
}
```

#### POST /auth/login
Authenticate and establish session.

**Request:**
```json
{
  "user": {
    "email": "user@example.com",
    "password": "secure_password123"
  }
}
```

**Success Response (200):**
```json
{
  "user": {
    "id": 123,
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

**Error Response (401):**
```json
{
  "error": {
    "type": "invalid_credentials",
    "message": "Invalid email or password"
  }
}
```

#### DELETE /auth/logout
Logout and clear session.

**Success Response (204):**
No content

#### POST /auth/password
Request password reset email.

**Request:**
```json
{
  "user": {
    "email": "user@example.com"
  }
}
```

**Success Response (200):**
```json
{
  "message": "Reset instructions sent to user@example.com"
}
```

#### PATCH /auth/password
Reset password with token.

**Request:**
```json
{
  "user": {
    "reset_password_token": "abc123...",
    "password": "new_secure_password",
    "password_confirmation": "new_secure_password"
  }
}
```

**Success Response (200):**
```json
{
  "message": "Password has been reset successfully"
}
```

### Conversation Tokens (AI Assistant)

Separate from the main session auth, conversation tokens are stateless JWTs used by an external LLM proxy to validate AI assistant chat requests.

#### POST /internal/assistant_conversations
Create or validate an assistant conversation and get a conversation token.

**Request:**
```json
{
  "lesson_slug": "basic-movement"
}
```

**Success Response (200):**
```json
{
  "token": "<conversation_jwt>"
}
```

**Conversation Token Payload:**
```json
{
  "sub": 123,
  "lesson_slug": "basic-movement",
  "exercise_slug": "jiki/intro/basic-movement",
  "exp": 1705778723,
  "iat": 1705775123
}
```

**Key Points:**
- 1-hour expiry
- Stateless - NOT stored in database
- Contains lesson/exercise context
- Used only for LLM proxy authentication
- Generated using raw JWT gem (independent of Devise)

### Future OAuth Endpoints

#### POST /auth/google
Authenticate with Google OAuth.

**Request:**
```json
{
  "code": "google_auth_code_here"
}
```

**Success Response (200):**
```json
{
  "user": {
    "id": 123,
    "email": "user@gmail.com",
    "name": "John Doe",
    "provider": "google"
  }
}
```

## Frontend Integration

### Required Configuration

```javascript
// All API calls should include credentials
fetch('/api/endpoint', {
  credentials: 'include',  // Sends cookies automatically
  headers: {
    'Content-Type': 'application/json'
  }
})
```

### Auth Store Example (Zustand)
```jsx
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

const useAuthStore = create(
  persist(
    (set, get) => ({
      user: null,

      setUser: (user) => set({ user }),
      clearAuth: () => set({ user: null }),
      isAuthenticated: () => !!get().user,
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({ user: state.user }),
    }
  )
);
```

### API Client Setup
```jsx
import axios from 'axios';

const apiClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000',
  withCredentials: true,  // Send cookies with every request
  headers: {
    'Content-Type': 'application/json',
  },
});

// Response interceptor to handle auth state
apiClient.interceptors.response.use(
  (response) => {
    // Update user from login/signup responses
    if (response.data.user) {
      useAuthStore.getState().setUser(response.data.user);
    }
    return response;
  },
  (error) => {
    // Handle 401 - redirect to login
    if (error.response?.status === 401) {
      useAuthStore.getState().clearAuth();
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);
```

## Database Schema

### User Model
```ruby
create_table :users do |t|
  # Devise fields
  t.string :email,              null: false, default: ""
  t.string :encrypted_password, null: false, default: ""

  # User profile
  t.string :name
  t.string :handle

  # Devise recoverable
  t.string   :reset_password_token
  t.datetime :reset_password_sent_at

  # Devise confirmable
  t.string   :confirmation_token
  t.datetime :confirmed_at
  t.datetime :confirmation_sent_at
  t.string   :unconfirmed_email

  # User settings
  t.string :locale, null: false, default: "en"

  # OAuth ready fields
  t.string :google_id
  t.string :github_id
  t.string :provider

  t.timestamps
end

add_index :users, :email, unique: true
add_index :users, :reset_password_token, unique: true
add_index :users, :handle, unique: true
add_index :users, :google_id, unique: true
add_index :users, :github_id, unique: true
```

## Security Considerations

### Session Security
- **Cookie Settings**: httpOnly, Secure (in production), SameSite: lax
- **Session Expiry**: 30 days

### CSRF Protection

The API uses `SameSite: Lax` cookies as the primary CSRF protection mechanism:

**How it works:**
- `SameSite: Lax` prevents the session cookie from being sent on cross-site POST/PUT/DELETE requests
- Only top-level GET navigations from external sites include the cookie
- Combined with CORS (which restricts allowed origins), this provides robust protection

**Why we don't use explicit CSRF tokens:**
- Traditional CSRF tokens require a server-rendered HTML page to embed the token
- In API-only apps with SPA frontends, there's no HTML page
- `SameSite: Lax` + CORS is the modern standard for API CSRF protection
- Supported by all modern browsers (Chrome 51+, Firefox 60+, Safari 12+)

**When explicit CSRF tokens would be needed:**
- Supporting pre-2020 browsers without SameSite support
- If the API had state-changing GET endpoints (bad practice)
- Extra defense-in-depth for high-security applications

**Note:** If explicit CSRF protection is ever needed, it would require:
1. An endpoint to fetch the CSRF token
2. Frontend storing and sending `X-CSRF-Token` header with mutations
3. Adding `ActionController::RequestForgeryProtection` to ApplicationController

### Password Security
- Minimum 6 characters required
- Encrypted using bcrypt
- Reset tokens expire after 6 hours
- Reset tokens are single-use

### API Security
- **HTTPS Required**: Always use HTTPS in production
- **CORS**: Restrict to known frontend domains with credentials support
- **Cookie Security**: httpOnly prevents XSS access to session

## Configuration Files

### Session Configuration (`config/application.rb`)
```ruby
# Session-based authentication via cookies
config.middleware.use ActionDispatch::Flash
config.middleware.use ActionDispatch::Cookies
config.middleware.use ActionDispatch::Session::CookieStore,
  key: 'jiki_session',
  expire_after: 30.days,
  same_site: :lax,
  secure: Rails.env.production?
```

### CORS Configuration
```ruby
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Jiki.config.frontend_base_url
    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
```

## Testing Strategy

### Unit Tests (User Model)
- Validation tests (email format, password length)
- Authentication tests (password verification)
- Password reset flow tests

### Controller Tests (API Endpoints)
- Registration with valid/invalid params
- Login with correct/incorrect credentials
- Password reset request
- Password reset with valid/invalid token
- Logout
- Authentication required for protected endpoints

### Integration Tests
- Full registration → login → logout flow
- Complete password reset flow
- OAuth flow (when implemented)

## Common Issues & Solutions

1. **CORS errors**: Check origins in cors.rb, ensure credentials: true
2. **Session not persisting**: Ensure credentials: 'include' on fetch calls
3. **401 on every request**: Check cookie domain and SameSite settings
4. **Password reset not working**: Check mailer configuration

## Future Enhancements

### Short Term
- [ ] Email verification on registration
- [ ] Account lockout after failed attempts
- [ ] Two-factor authentication
- [ ] Session management UI (view active sessions)

### Long Term
- [ ] OAuth providers (Google, GitHub, Apple)
- [ ] Magic link authentication
- [ ] Biometric authentication (mobile)
- [ ] Single Sign-On (SSO)
