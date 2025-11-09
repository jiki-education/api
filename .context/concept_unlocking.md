# Concept Unlocking System

## Overview

Concepts are unlocked for users when they complete lessons. Unlocked concept IDs are stored in a PostgreSQL bigint array column on the user_data table.

## Key Implementation Details

### Storage
- **user_data.unlocked_concept_ids**: bigint array with GIN index
- **concepts.unlocked_by_lesson_id**: FK to lessons table (one lesson unlocks one concept)

### Unlocking Flow
1. User completes lesson via `UserLesson::Complete`
2. If lesson has `unlocked_concept`, calls `Concept::UnlockForUser.(concept, user)`
3. Command appends concept ID to `user.data.unlocked_concept_ids` array (with `.uniq`)
4. Entire flow wrapped in transaction

### Files
- **Command**: `app/commands/concept/unlock_for_user.rb`
- **Models**: `app/models/concept.rb`, `app/models/user/data.rb`, `app/models/lesson.rb`
- **Tests**: `test/commands/concept/unlock_for_user_test.rb`, `test/commands/user_lesson/complete_test.rb`
- **Migration**: `db/migrate/*_create_user_data.rb`

### Associations
```ruby
# Concept
belongs_to :unlocked_by_lesson, class_name: 'Lesson', optional: true

# Lesson
has_one :unlocked_concept, class_name: 'Concept', foreign_key: :unlocked_by_lesson_id
```

### Common Queries
```ruby
# Check if unlocked
user.data.unlocked_concept_ids.include?(concept.id)

# Get unlocked concepts
Concept.where(id: user.data.unlocked_concept_ids)

# Which lesson unlocks a concept
concept.unlocked_by_lesson
```

## Important Notes

- Array column used instead of join table for storage efficiency at scale (99.99% reduction for 20M users)
- No foreign key constraint on array elements (PostgreSQL limitation)
- Unlocking is idempotent and uses `.uniq` to prevent duplicates
- Once unlocked, concept IDs are never removed from array
