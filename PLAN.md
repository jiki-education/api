# Avatar Upload Implementation Plan

## Overview

Implement user avatar uploads using ActiveStorage with Cloudflare R2 storage and a dedicated `uploads.jiki.io` subdomain for direct CDN delivery.

### Architecture

```
Upload Flow:
  Browser → API (api.jiki.io) → ActiveStorage → R2 (uploads bucket)

Serve Flow:
  Browser → uploads.jiki.io → Cloudflare CDN → R2 (direct, no proxy)
```

### Key Design Decisions

- **Cloudflare R2**: S3-compatible storage with no egress fees, built-in CDN via custom domain
- **Public URLs**: Direct R2 URLs via `uploads.jiki.io` (no proxy, no signed URLs)
- **Custom key format**: `xx/yy/zzz/rest-of-uuid.ext` for file distribution
- **Normalized filenames**: Extension preserved, UUID-based path
- **Cache busting**: New upload = new UUID = new URL
- **Rate limiting**: 200 req/min for API, 5k req/hr globally

---

## Implementation Checklist

### Phase 1: Terraform Infrastructure (../terraform)

- [ ] Create new R2 bucket (`uploads`)
- [ ] Add custom domain `uploads.jiki.io` → R2 bucket
- [ ] Add rate limiting rules

#### Terraform Details

**r2.tf** - Add uploads bucket:
```hcl
resource "cloudflare_r2_bucket" "uploads" {
  account_id = local.account_id
  name       = "uploads"
  location   = "WEUR"  # Western Europe (Ireland) - consistent with other infra
}
```

**cdn.tf** - Add custom domain for uploads bucket:
```hcl
resource "cloudflare_r2_custom_domain" "uploads" {
  account_id  = local.account_id
  bucket_name = cloudflare_r2_bucket.uploads.name
  domain      = "uploads.jiki.io"
  zone_id     = local.zone_id
  enabled     = true
  min_tls     = "1.2"
}

# Disable public r2.dev domain - only accessible via custom domain
resource "cloudflare_r2_managed_domain" "uploads" {
  account_id  = local.account_id
  bucket_name = cloudflare_r2_bucket.uploads.name
  enabled     = false
}
```

**rate_limiting.tf** (new file):
```hcl
resource "cloudflare_ruleset" "rate_limiting" {
  zone_id     = local.zone_id
  name        = "Rate Limiting"
  description = "Rate limiting rules for API and general traffic"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [
    # Rule 1: API - 200 requests/min per IP
    {
      action      = "block"
      expression  = "http.host eq \"api.jiki.io\""
      description = "API rate limit: 200 req/min per IP"
      enabled     = true

      ratelimit = {
        characteristics     = ["ip.src"]
        period              = 60
        requests_per_period = 200
        mitigation_timeout  = 60
      }
    },
    # Rule 2: Everything - 5000 requests/hr per IP
    {
      action      = "block"
      expression  = "true"
      description = "Global rate limit: 5000 req/hr per IP"
      enabled     = true

      ratelimit = {
        characteristics     = ["ip.src"]
        period              = 3600
        requests_per_period = 5000
        mitigation_timeout  = 3600
      }
    }
  ]
}
```

---

### Phase 2: Rails Configuration

- [ ] Add R2 storage service configuration
- [ ] Configure R2 credentials (DynamoDB config or environment)

#### Configuration Details

**config/storage.yml** - Add R2 service:
```yaml
r2:
  service: S3
  endpoint: https://<account_id>.r2.cloudflarestorage.com
  access_key_id: <%= Jiki.config.r2_access_key_id %>
  secret_access_key: <%= Jiki.config.r2_secret_access_key %>
  region: auto
  bucket: uploads
  public: true
```

**config/environments/production.rb**:
```ruby
# Use R2 for avatar storage
config.active_storage.service = :r2
```

**Note**: May need separate services if other attachments (like exercise submissions) should stay on S3. In that case, specify service per-attachment:
```ruby
has_one_attached :avatar, service: :r2
```

---

### Phase 3: User Model

- [ ] Add `has_one_attached :avatar` to User model

#### Model Changes

**app/models/user.rb**:
```ruby
has_one_attached :avatar, service: :r2
```

No migration needed — ActiveStorage tables already exist.

---

### Phase 4: Upload Endpoint

- [ ] Add error classes
- [ ] Create upload endpoint for avatar
- [ ] Add command to handle avatar upload with validation
- [ ] Add command to delete avatar

#### Error Classes

**config/initializers/exceptions.rb** - Add:
```ruby
class InvalidAvatarError < RuntimeError; end
class AvatarTooLargeError < RuntimeError; end
```

#### Endpoint Design

**Routes** (config/routes.rb):
```ruby
namespace :internal do
  resource :profile, only: [:show] do
    resource :avatar, only: [:update, :destroy], controller: 'profile/avatars'
  end
end
```

**app/controllers/internal/profile/avatars_controller.rb**:
```ruby
module Internal
  module Profile
    class AvatarsController < Internal::BaseController
      def update
        User::Avatar::Upload.(current_user, params[:avatar])
        render json: { profile: SerializeProfile.(current_user) }
      rescue InvalidAvatarError, AvatarTooLargeError => e
        render json: { error: { type: :validation_error, message: e.message } },
               status: :unprocessable_entity
      end

      def destroy
        User::Avatar::Delete.(current_user)
        render json: { profile: SerializeProfile.(current_user) }
      end
    end
  end
end
```

#### Commands

**app/commands/user/avatar/upload.rb**:
```ruby
class User::Avatar::Upload
  include Mandate

  initialize_with :user, :file

  MAX_FILE_SIZE = 5.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  def call
    validate_file!
    user.avatar.purge if user.avatar.attached?
    user.avatar.attach(
      io: file_io,
      filename: "avatar.#{extension}",
      content_type: file.content_type,
      key: storage_key
    )
    user
  end

  private

  def validate_file!
    raise InvalidAvatarError, "No file provided" unless file.present?
    raise InvalidAvatarError, "Invalid file type" unless valid_content_type?
    raise AvatarTooLargeError, "File exceeds 5MB limit" if file.size > MAX_FILE_SIZE
  end

  def valid_content_type?
    file.content_type.in?(ALLOWED_CONTENT_TYPES)
  end

  def file_io
    file.respond_to?(:tempfile) ? file.tempfile : file
  end

  def extension
    File.extname(file.original_filename).delete_prefix(".").presence || "jpg"
  end

  # Key format: xx/yy/zzz/rest-of-uuid.ext
  # e.g., a1/b2/c3d/4-e5f6-7890-abcd-ef1234567890.jpg
  def storage_key
    uuid = SecureRandom.uuid
    "#{uuid[0, 2]}/#{uuid[2, 2]}/#{uuid[4, 3]}/#{uuid[7..]}.#{extension}"
  end
end
```

**app/commands/user/avatar/delete.rb**:
```ruby
class User::Avatar::Delete
  include Mandate

  initialize_with :user

  def call
    user.avatar.purge if user.avatar.attached?
    user
  end
end
```

---

### Phase 5: Serializer Updates

- [ ] Update SerializeProfile to return real avatar URL
- [ ] Handle case when no avatar is attached (return null)

#### Serializer Changes

**app/serializers/serialize_profile.rb**:
```ruby
def call
  {
    icon: "flag",
    avatar_url: avatar_url,
    has_avatar: user.avatar.attached?,
    streaks_enabled: user.data.streaks_enabled,
    **streak_data
  }
end

private

def avatar_url
  return nil unless user.avatar.attached?

  # Public R2 URL via custom domain
  "https://uploads.jiki.io/#{user.avatar.key}"
end
```

For development (using local disk storage):
```ruby
def avatar_url
  return nil unless user.avatar.attached?

  if Rails.env.production?
    "https://uploads.jiki.io/#{user.avatar.key}"
  else
    Rails.application.routes.url_helpers.rails_blob_url(user.avatar, host: "localhost:3000")
  end
end
```

---

### Phase 6: Testing

- [ ] Unit tests for upload/delete commands
- [ ] Controller tests for endpoints
- [ ] Integration test for full upload flow

---

## Frontend Integration

### Endpoints

| Action | Method | Endpoint | Content-Type | Body |
|--------|--------|----------|--------------|------|
| Upload avatar | `PUT` | `/internal/profile/avatar` | `multipart/form-data` | `avatar: File` |
| Delete avatar | `DELETE` | `/internal/profile/avatar` | - | - |
| Get profile (includes avatar_url) | `GET` | `/internal/profile` | - | - |

### Response Format

All endpoints return the updated profile:

```json
{
  "profile": {
    "icon": "flag",
    "avatar_url": "https://uploads.jiki.io/a1/b2/c3d/4-e5f6-7890-abcd-ef1234567890.jpg",
    "has_avatar": true,
    "streaks_enabled": true,
    "current_streak": 5,
    "longest_streak": 12,
    "activity_graph": { ... }
  }
}
```

When no avatar is set:
```json
{
  "profile": {
    "icon": "flag",
    "avatar_url": null,
    "has_avatar": false,
    ...
  }
}
```

### Upload Example (Frontend)

```typescript
async function uploadAvatar(file: File): Promise<Profile> {
  const formData = new FormData();
  formData.append('avatar', file);

  const response = await fetch('/internal/profile/avatar', {
    method: 'PUT',
    headers: {
      'Authorization': `Bearer ${token}`,
      // Don't set Content-Type; browser sets it with boundary for multipart
    },
    body: formData,
  });

  return response.json();
}

async function deleteAvatar(): Promise<Profile> {
  const response = await fetch('/internal/profile/avatar', {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${token}`,
    },
  });

  return response.json();
}
```

### Avatar Display

- If `has_avatar` is `true`, use `avatar_url` directly as `<img src>`
- If `has_avatar` is `false`, display a placeholder/default avatar (frontend decides)
- Avatar URLs are permanent (public R2) and CDN-cached
- When user uploads new avatar, the returned `avatar_url` will be different (new UUID = new URL)

### File Constraints (validate client-side too)

- Max size: 5MB
- Accepted types: `image/jpeg`, `image/png`, `image/gif`, `image/webp`

---

## URL Flow Example

1. User uploads `vacation-selfie.png`
2. Rails generates UUID `a1b2c3d4-e5f6-7890-abcd-ef1234567890`
3. Rails stores in R2 with key: `a1/b2/c3d/4-e5f6-7890-abcd-ef1234567890.png`
4. Serializer returns URL: `https://uploads.jiki.io/a1/b2/c3d/4-e5f6-7890-abcd-ef1234567890.png`
5. Browser requests that URL → Cloudflare CDN → R2
6. Cloudflare caches at edge, subsequent requests served from CDN

When user uploads a new avatar:
- New UUID generated, new key, new URL
- Old file remains in R2 (orphaned) until cleanup
- Old blob purged from ActiveStorage tables

---

## Rollout Steps

1. **Deploy Terraform** - Create R2 bucket, custom domain, rate limiting rules
2. **Configure R2 credentials** - Add to DynamoDB config or environment
3. **Deploy Rails** - Storage config, model changes, endpoints
4. **Update Frontend** - Add upload UI, use real avatar URLs
5. **Monitor** - Check R2 metrics, Cloudflare cache hit rates

---

## Future Considerations

- **Image variants**: Add thumbnail variant if needed for different sizes
- **Crop/resize on upload**: Process images server-side to consistent dimensions
- **Cleanup job**: Periodic job to remove orphaned R2 objects not in ActiveStorage
- **Other uploads**: This infrastructure supports future user uploads (cover images, etc.)
