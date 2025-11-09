# User::Data Pattern

## Overview

The `User::Data` model stores extended user metadata separate from core authentication data. Follows the Exercism pattern for separation of concerns.

## Key Implementation Details

### Automatic Creation
- Created automatically via `after_initialize { build_data if new_record? && !data }` in User model
- Uses `autosave: true` so data saves when user saves
- Always accessible via `user.data`

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

## Extensibility

This model is designed to be extended with additional user metadata:
- User preferences
- Cached computed values
- Feature flags
- Settings that change frequently

Add new columns directly to user_data table as needed.
