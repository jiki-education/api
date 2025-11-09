# Stripe Upgrade/Downgrade Implementation Plan - API

## Overview

Implement API support for users to upgrade/downgrade their subscription tier without creating duplicate subscriptions.

## Business Rules

- **Same tier changes**: Return error if user tries to switch to their current tier
- **Standard tier users**: Must use checkout flow (can't update non-existent subscription)
- **Failed payments**: Allow all changes (Stripe will handle payment issues)
- **Change timing**:
  - **Upgrades**: Immediate with prorated billing
  - **Downgrades**: Scheduled for end of current billing period

## Implementation Tasks

### 1. Update `Internal::SubscriptionsController#checkout_session`

**Location**: `app/controllers/internal/subscriptions_controller.rb:4`

Add validation to prevent duplicate subscriptions:

```ruby
# After line 8 (product validation), add:
if current_user.data.stripe_subscription_id.present? &&
   current_user.data.stripe_subscription_status.in?(%w[active trialing])
  return render json: {
    error: {
      type: "existing_subscription",
      message: "You already have an active subscription. Use the update endpoint to change tiers."
    }
  }, status: :bad_request
end
```

### 2. Create `Stripe::UpdateSubscription` Command

**Location**: `app/commands/stripe/update_subscription.rb`

**Signature**: `Stripe::UpdateSubscription.(user, product)`

**Validations**:
- User must have `stripe_subscription_id` present
- User must not already be on requested tier
- Product must be 'premium' or 'max'

**Logic**:
```ruby
# Get current subscription from Stripe
subscription = ::Stripe::Subscription.retrieve(user.data.stripe_subscription_id)

# Get new price_id based on product
new_price_id = product == 'premium' ?
  Jiki.config.stripe_premium_price_id :
  Jiki.config.stripe_max_price_id

# Determine if upgrade or downgrade
current_tier = user.data.membership_type
new_tier = product
is_upgrade = tier_value(new_tier) > tier_value(current_tier)

# Get subscription item ID
subscription_item = subscription.items.data.first

if is_upgrade
  #
  # Create a Stripe::Upgrade.(...) command containing...
  #
  # Immediate upgrade with proration
  ::Stripe::Subscription.update(
    subscription.id,
    items: [{
      id: subscription_item.id,
      price: new_price_id
    }],
    proration_behavior: 'always_invoice'
  )

  # Update user data immediately
  user.data.update!(membership_type: new_tier)
else
  #
  # Create a Stripe::Downgrade.(...) command containing...
  #
  # Downgrade at period end
  ::Stripe::Subscription.update(
    subscription.id,
    items: [{
      id: subscription_item.id,
      price: new_price_id
    }],
    proration_behavior: 'create_prorations',
    billing_cycle_anchor: 'unchanged'
  )

  # Don't update user.data yet - webhook will handle at period end
end
```

**Helper method**:
```ruby
def tier_value(tier)
  { 'standard' => 0, 'premium' => 1, 'max' => 2 }[tier]
end
```

### 3. Add `update` Endpoint to `SubscriptionsController`

**Location**: `app/controllers/internal/subscriptions_controller.rb`

**Route**: `POST /internal/subscriptions/update`

**Parameters**:
```json
{
  "product": "premium" | "max"
}
```

**Validations**:
```ruby
def update
  product = params[:product]

  # Validate product
  unless %w[premium max].include?(product)
    return render json: {
      error: {
        type: "invalid_product",
        message: "Invalid product. Must be 'premium' or 'max'"
      }
    }, status: :bad_request
  end

  # Check user has subscription
  unless current_user.data.stripe_subscription_id.present?
    return render json: {
      error: {
        type: "no_subscription",
        message: "You don't have an active subscription. Use checkout to create one."
      }
    }, status: :bad_request
  end

  # Check not same tier
  current_tier = current_user.data.membership_type
  if current_tier == product
    return render json: {
      error: {
        type: "same_tier",
        message: "You are already subscribed to #{product}"
      }
    }, status: :bad_request
  end

  # Update subscription
  result = Stripe::UpdateSubscription.(current_user, product)

  render json: {
    success: true,
    tier: result[:tier],
    effective_at: result[:effective_at] # immediate or period_end
  }
rescue StandardError => e
  Rails.logger.error("Failed to update subscription: #{e.message}")
  render json: {
    error: {
      type: "update_failed",
      message: "Failed to update subscription"
    }
  }, status: :internal_server_error
end
```

### 4. Update Routes

**Location**: `config/routes.rb`

Add to internal subscriptions routes:
```ruby
namespace :internal do
  resources :subscriptions, only: [] do
    collection do
      post :checkout_session
      post :portal_session
      post :verify_checkout
      post :update        # NEW
      get :status
    end
  end
end
```

### 5. Tests

**Location**: `test/commands/stripe/update_subscription_test.rb`

Test cases:
- Upgrade from premium to max (immediate, prorated)
- Downgrade from max to premium (scheduled for period end)
- Error: user has no subscription
- Error: user already on requested tier
- Error: invalid product

**Location**: `test/controllers/internal/subscriptions_controller_test.rb`

Add tests for `update` action:
- Successful upgrade
- Successful downgrade
- Error: no subscription
- Error: same tier
- Error: invalid product
- Error: not authenticated

### 6. Webhook Handling

**Existing**: `Stripe::Webhook::SubscriptionUpdated` already handles tier changes (line 13-47)

**Verify**: Ensure it correctly handles scheduled downgrades when they take effect

## Data Flow

### Upgrade Flow (Premium → Max)
1. Frontend calls `POST /internal/subscriptions/update` with `{"product": "max"}`
2. Backend calls `Stripe::UpdateSubscription.(user, 'max')`
3. Stripe API updates subscription immediately with proration
4. Command updates `user.data.membership_type = 'max'`
5. Response returned to frontend with new tier
6. Webhook `subscription.updated` fires (idempotent - no change needed)

### Downgrade Flow (Max → Premium)
1. Frontend calls `POST /internal/subscriptions/update` with `{"product": "premium"}`
2. Backend calls `Stripe::UpdateSubscription.(user, 'premium')`
3. Stripe API schedules change for end of billing period
4. Command does NOT update `user.data.membership_type` yet
5. Response returned indicating change scheduled for period end
6. At period end: Webhook `subscription.updated` fires
7. Webhook updates `user.data.membership_type = 'premium'`

## Edge Cases

- **User cancels then re-subscribes**: Use checkout flow (no active subscription)
- **User in grace period**: Update allowed (might resolve payment issues)
- **Multiple rapid changes**: Stripe handles - last change wins
- **Webhook arrives before response**: Acceptable - data is consistent either way
