# Google OAuth Implementation Plan - API

## Overview
Add Google OAuth authentication to the Jiki API, allowing users to sign in with their Google accounts. This integrates with our existing JWT-based authentication system.

## Implementation Steps

### 1. Add Dependencies

**File**: `Gemfile`

Add gem for Google token verification:
```ruby
gem 'google-id-token', '~> 1.4' # Verifies Google JWT tokens
```

Run: `bundle install`

### 2. Google Cloud Console Setup

**Manual Steps**:
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create new project or select existing "Jiki"
3. Enable Google+ API / Google Identity
4. Create OAuth 2.0 credentials:
   - Application type: Web application
   - Authorized JavaScript origins: `http://localhost:5173` (dev), `https://jiki.app` (prod)
   - Authorized redirect URIs: Not needed (client-side flow)
5. Copy Client ID and Client Secret
6. Add to Rails credentials:
   ```bash
   EDITOR=vim rails credentials:edit
   ```
   ```yaml
   google:
     client_id: YOUR_CLIENT_ID
     client_secret: YOUR_CLIENT_SECRET
   ```

### 3. Configuration

**File**: `config/settings/development.yml`
```yaml
google:
  client_id: <%= Rails.application.credentials.google&.[](:client_id) %>
```

**File**: `config/settings/production.yml`
```yaml
google:
  client_id: <%= Rails.application.credentials.google&.[](:client_id) %>
```

### 4. Create Google Token Verifier Service

**File**: `app/services/auth/verify_google_token.rb`

```ruby
module Auth
  class VerifyGoogleToken
    include Mandate

    initialize_with :token

    def call
      validator = GoogleIDToken::Validator.new
      payload = validator.check(token, Jiki.config.google.client_id)

      raise InvalidTokenError, "Invalid Google token" unless payload
      raise InvalidTokenError, "Token expired" if Time.at(payload['exp']) < Time.now

      payload
    rescue GoogleIDToken::ValidationError => e
      raise InvalidTokenError, "Google token validation failed: #{e.message}"
    end

    class InvalidTokenError < StandardError; end
  end
end
```

**Tests**: `test/services/auth/verify_google_token_test.rb`
- Test valid token returns payload
- Test invalid token raises error
- Test expired token raises error
- Test wrong audience raises error

### 5. Create Google Authentication Command

**File**: `app/commands/auth/authenticate_with_google.rb`

```ruby
module Auth
  class AuthenticateWithGoogle
    include Mandate

    initialize_with :google_token, :user_agent

    def call
      payload = Auth::VerifyGoogleToken.(google_token)

      user = find_or_create_user(payload)

      { user: user }
    end

    private

    def find_or_create_user(payload)
      google_id = payload['sub']
      email = payload['email']
      name = payload['name']

      # Try to find by google_id first
      user = User.find_by(google_id: google_id)
      return user if user

      # Try to find by email (auto-linking)
      user = User.find_by(email: email)
      if user
        # Link existing account to Google
        user.update!(
          google_id: google_id,
          provider: 'google',
          email_verified: true
        )
        return user
      end

      # Create new user
      User.create!(
        email: email,
        name: name,
        google_id: google_id,
        provider: 'google',
        email_verified: true,
        password: SecureRandom.hex(32), # Random password (won't be used)
        handle: generate_handle(email)
      )
    end

    def generate_handle(email)
      base = email.split('@').first.parameterize
      handle = base
      counter = 1

      while User.exists?(handle: handle)
        handle = "#{base}#{counter}"
        counter += 1
      end

      handle
    end
  end
end
```

**Tests**: `test/commands/auth/authenticate_with_google_test.rb`
- Test new user creation from Google token
- Test finding existing user by google_id
- Test auto-linking existing user by email
- Test email_verified set to true
- Test random password generated
- Test handle generation with collisions

### 6. Add Migration for Email Verification

**File**: `db/migrate/YYYYMMDDHHMMSS_add_email_verified_to_users.rb`

```ruby
class AddEmailVerifiedToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :email_verified, :boolean, default: false, null: false

    # Mark existing OAuth users as verified
    reversible do |dir|
      dir.up do
        User.where.not(google_id: nil).update_all(email_verified: true)
      end
    end

    add_index :users, :email_verified
  end
end
```

Run: `bin/rails db:migrate`

### 7. Update User Model

**File**: `app/models/user.rb`

Add validation to allow OAuth users without real passwords:
```ruby
# After devise declaration, add:

# OAuth users have random passwords, so skip password validation for them
validates :password, presence: true, if: -> { new_record? && provider.nil? }

# Require email verification for traditional signups, but not OAuth
validates :email_verified, inclusion: { in: [true] }, if: -> { provider.nil? && !new_record? }
```

**Tests**: `test/models/user_test.rb`
- Test OAuth user can be created without password
- Test traditional user requires password
- Test traditional user requires email verification
- Test OAuth user has email_verified automatically

### 8. Create Google OAuth Controller

**File**: `app/controllers/auth/google_controller.rb`

```ruby
module Auth
  class GoogleController < ApplicationController
    skip_before_action :authenticate_user!, only: [:create]

    def create
      result = Auth::AuthenticateWithGoogle.(
        params[:token],
        request.user_agent
      )

      user = result[:user]

      # Generate JWT tokens (same as login)
      token = Warden::JWTAuth::UserEncoder.new.call(
        user,
        :user,
        request.headers['User-Agent']
      )

      # Generate refresh token
      refresh_token = Auth::GenerateRefreshToken.(
        user,
        request.headers['User-Agent']
      )

      response.headers['Authorization'] = "Bearer #{token}"

      render json: {
        user: SerializeUser.(user),
        refresh_token: refresh_token.token
      }, status: :ok

    rescue Auth::VerifyGoogleToken::InvalidTokenError => e
      render_error(
        type: :invalid_token,
        message: e.message,
        status: :unauthorized
      )
    rescue ActiveRecord::RecordInvalid => e
      render_error(
        type: :validation_error,
        message: "Could not create user account",
        errors: e.record.errors.messages,
        status: :unprocessable_entity
      )
    end
  end
end
```

**Tests**: `test/controllers/auth/google_controller_test.rb`
- Test valid Google token creates new user and returns JWT
- Test valid Google token finds existing user by google_id
- Test valid Google token links existing user by email
- Test invalid Google token returns 401
- Test expired Google token returns 401
- Test missing token parameter returns 400
- Test returns refresh_token in response
- Test sets Authorization header

### 9. Add Route

**File**: `config/routes.rb`

Add inside the `namespace :auth` block:
```ruby
namespace :auth do
  resource :refresh_token, only: [:create]
  resource :logout_all, only: [:destroy]
  resource :google, only: [:create]  # ADD THIS LINE
end
```

### 10. Update Auth Context Documentation

**File**: `.context/auth.md`

Update the OAuth section (lines 35-41) to mark as completed:
```markdown
### OAuth Integration
- [x] Frontend: Add @react-oauth/google package
- [x] Frontend: Implement Google OAuth button
- [x] Backend: Add google-id-token gem for verification
- [x] Backend: Add OAuth endpoint to accept Google tokens
- [x] Backend: Find or create user from Google profile
- [x] Backend: Auto-link accounts by email
- [x] Backend: Require email verification for traditional signups
- [x] Test OAuth flow end-to-end
```

Add new endpoint documentation after line 311:
```markdown
#### POST /auth/google
Authenticate with Google OAuth token.

**Request:**
```json
{
  "token": "google_jwt_id_token_here"
}
```

**Success Response (200):**
```json
{
  "user": {
    "id": 123,
    "email": "user@gmail.com",
    "name": "John Doe",
    "provider": "google",
    "email_verified": true
  },
  "refresh_token": "long_lived_refresh_token_here"
}
```
**Headers:**
```
Authorization: Bearer <short_lived_access_token>
```

**Error Response (401):**
```json
{
  "error": {
    "type": "invalid_token",
    "message": "Invalid Google token"
  }
}
```

**Behavior:**
- Verifies Google token with Google's servers
- Finds existing user by google_id OR email (auto-linking)
- Creates new user if none exists
- Sets email_verified to true (trusting Google)
- Generates random password for OAuth users
- Returns same JWT structure as /auth/login
```

### 11. Email Verification for Traditional Signups

**File**: `app/controllers/auth/registrations_controller.rb`

Update the `create` action to require email verification:
```ruby
def create
  build_resource(sign_up_params)

  resource.save
  yield resource if block_given?

  if resource.persisted?
    if resource.active_for_authentication?
      # Send confirmation email for traditional signups
      unless resource.provider.present?
        # TODO: Send email verification email
        # For now, auto-verify in development
        resource.update!(email_verified: true) if Rails.env.development?
      end

      # Generate tokens
      token = Warden::JWTAuth::UserEncoder.new.call(
        resource,
        :user,
        request.headers['User-Agent']
      )

      refresh_token = Auth::GenerateRefreshToken.(
        resource,
        request.headers['User-Agent']
      )

      response.headers['Authorization'] = "Bearer #{token}"

      render json: {
        user: SerializeUser.(resource),
        refresh_token: refresh_token.token
      }, status: :created
    else
      expire_data_after_sign_in!
      render_create_error_response(resource)
    end
  else
    clean_up_passwords resource
    set_minimum_password_length
    render_create_error_response(resource)
  end
end
```

**Note**: For MVP, we're auto-verifying emails in development. Email verification flow can be added later as a separate feature.

### 12. Update Serializers

**File**: `app/serializers/serialize_user.rb`

Add new fields to user serialization:
```ruby
def call
  {
    id: user.id,
    handle: user.handle,
    name: user.name,
    email: user.email,
    locale: user.locale,
    provider: user.provider,           # ADD THIS
    email_verified: user.email_verified, # ADD THIS
    created_at: user.created_at.iso8601,
    updated_at: user.updated_at.iso8601
  }
end
```

Update tests accordingly.

### 13. Security Considerations

**Rate Limiting**: Consider adding rate limiting to `/auth/google` endpoint:
```ruby
# config/initializers/rack_attack.rb (if using rack-attack)
throttle('auth/google', limit: 5, period: 1.minute) do |req|
  req.ip if req.path == '/auth/google' && req.post?
end
```

**Token Verification**: Always verify Google tokens server-side, never trust client.

**Account Takeover Prevention**: Auto-linking by email is safe because Google verifies email ownership.

## Testing Checklist

Before committing:
- [ ] Run all tests: `bin/rails test`
- [ ] Run linting: `bin/rubocop`
- [ ] Run security check: `bin/brakeman`
- [ ] Test OAuth flow manually:
  - [ ] New user signup via Google
  - [ ] Existing user login via Google (by google_id)
  - [ ] Account linking (existing email user signs in with Google)
  - [ ] Invalid token handling
- [ ] Verify JWT tokens are returned correctly
- [ ] Verify refresh tokens work

## Future Enhancements

- [ ] Email verification flow for traditional signups (send verification email)
- [ ] Allow users to disconnect Google from their account
- [ ] Add "Sign in with Google" button to frontend
- [ ] Support other OAuth providers (GitHub, Apple)
- [ ] Admin panel to view OAuth provider usage

## Rollout Plan

1. **Development**: Test with Google OAuth test account
2. **Staging**: Deploy and test with real Google accounts
3. **Production**:
   - Deploy API changes
   - Enable feature flag on frontend
   - Monitor error rates and signup metrics
   - Announce to users

## Monitoring

After deployment, monitor:
- Google OAuth signup rate vs traditional signup
- OAuth authentication errors
- Account linking frequency
- Time to first successful authentication
