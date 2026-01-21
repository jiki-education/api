# User::Data Pattern

## Overview

The `User::Data` model stores extended user metadata separate from core authentication data. Follows the Exercism pattern for separation of concerns.

## Key Implementation Details

### Automatic Creation
- Created automatically via `after_initialize { build_data if new_record? && !data }` in User model
- Uses `autosave: true` so data saves when user saves
- Always accessible via `user.data` (no need to guard against it missing)

### References are directly through `user`

In nearly all situations, it is idiomatic to call `user.some_method` and let the `method_missing` flow in `user` handle the delegation to `user.data`, rather than calling `user.data.some_method`. 

Only call `user.data.some_method` if there is a specific reason that `method_missing` won't work (e.g. you want to get `user.data.id` and `user.id` would clash).

### Database Schema
```ruby
# user_data table
user_id (bigint, FK, unique, NOT NULL)
unlocked_concept_ids (bigint[], default: [], NOT NULL, GIN index)
created_at
updated_at
```

### Files
- **Model**: `app/models/user/data.rb`
- **Migration**: `db/migrate/*_create_user_data.rb`
- **Pattern source**: Exercism website (`../../exercism/website/app/models/user/data.rb`)

### Association
```ruby
# In User model
has_one :data, dependent: :destroy, class_name: "User::Data", autosave: true
```

## Current Fields

- **unlocked_concept_ids**: Array of concept IDs user has unlocked (see `.context/concept_unlocking.md`)
- **receive_product_updates**: Boolean, default true - Emails about new features or content
- **receive_event_emails**: Boolean, default true - Emails about livestreams
- **receive_milestone_emails**: Boolean, default true - Emails when reaching new milestones
- **receive_activity_emails**: Boolean, default true - Other emails in response to user actions

## Notification Preferences

The model includes a `NOTIFICATION_SLUGS` constant mapping URL slugs to column names:

```ruby
NOTIFICATION_SLUGS = {
  "product_updates" => :receive_product_updates,
  "event_emails" => :receive_event_emails,
  "milestone_emails" => :receive_milestone_emails,
  "activity_emails" => :receive_activity_emails
}
```

Helper methods:
- `User::Data.valid_notification_slug?(slug)` - Check if a slug is valid
- `User::Data.notification_column_for(slug)` - Get the column name for a slug

## Extensibility

This model is designed to be extended with additional user metadata:
- User preferences
- Cached computed values
- Feature flags
- Settings that change frequently

Add new columns directly to user_data table as needed.
