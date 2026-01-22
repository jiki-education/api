# Membership Tiers & Premium Access

## Overview

Jiki has three membership tiers that control access to features. Membership data is stored in `User::Data` and accessed via the User model.

## Membership Tiers

| Tier | `membership_type` | Description |
|------|-------------------|-------------|
| Standard | `"standard"` | Free tier, limited features |
| Premium | `"premium"` | Paid tier, full access |
| Max | `"max"` | Top tier, all features |

## Key Files

- **Model**: `app/models/user/data.rb` - Contains membership_type and helper methods
- **Schema**: `user_data.membership_type` column (string, default: "standard")

## Helper Methods

```ruby
# On User::Data (accessible via user.data or user delegation)
user.data.standard?           # true if membership_type == "standard"
user.data.premium?            # true if membership_type == "premium"
user.data.max?                # true if membership_type == "max"

user.data.has_premium_access? # true if premium? || max?
user.data.has_max_access?     # true if max?

# Via User method_missing delegation
user.has_premium_access?      # delegates to user.data.has_premium_access?
```

## Feature Gating Pattern

Use `has_premium_access?` for feature checks:

```ruby
# In commands/controllers
if user.has_premium_access?
  # Allow premium feature
else
  # Restrict or show upgrade prompt
end
```

## AI Assistant Access Control

The AI assistant has tiered access based on membership:

- **Premium/Max users**: Unlimited access to AI assistant on any lesson
- **Standard users**: One free lesson for AI assistant usage

### How Standard User Access Works

1. Standard users can use the AI assistant on ONE lesson at a time
2. The "free lesson" is tracked by the most recent `AssistantConversation` record
3. When a standard user requests a conversation token for a different lesson, access is denied

### Relevant Commands

- `AssistantConversation::CheckUserAccess` - Validates if user can access AI for a lesson
- `AssistantConversation::CreateConversationToken` - Creates JWT for LLM proxy authentication

### Access Check Logic

```ruby
# Premium/Max users: always allowed
return true if user.has_premium_access?

# Standard users: check most recent lesson conversation
most_recent = user.assistant_conversations.where(context_type: 'Lesson').order(updated_at: :desc).first

# No previous conversation = allowed (this becomes their free lesson)
return true if most_recent.nil?

# Previous conversation exists = must be same lesson
most_recent.context_id == lesson.id
```

## Subscription Integration

Membership is managed via Stripe subscriptions. See `.context/stripe.md` for:
- Checkout flow
- Subscription webhooks
- Tier changes

Key `User::Data` subscription fields:
- `stripe_customer_id`
- `stripe_subscription_id`
- `subscription_status` (enum: never_subscribed, incomplete, active, payment_failed, cancelling, canceled)
- `subscription_valid_until`
