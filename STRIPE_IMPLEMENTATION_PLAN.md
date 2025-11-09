# Stripe Upgrade/Downgrade Implementation Plan

This document outlines all changes needed to implement subscription upgrade/downgrade functionality in the Jiki API.

## Overview

We're adding the ability for users to upgrade/downgrade between Premium and Max tiers, with proper state tracking and grace period handling. All changes are immediate with prorations (no scheduled tier changes).

## Reference Documentation

**Read this first:** `.context/stripe.md` - Contains complete specification of all subscription states, webhooks, and business rules.

## Implementation Order

Follow this order to avoid breaking changes:

1. Database migration
2. Update User::Data model
3. Update webhook handlers (ensures new fields are maintained)
4. Create new commands (UpdateSubscription, CancelSubscription)
5. Update/add controller endpoints
6. Update existing commands to use new fields
7. Write tests

---

## 1. Database Migration

**Create:** `db/migrate/YYYYMMDDHHMMSS_update_subscription_tracking.rb`

### Schema Changes

**Add columns:**
```ruby
add_column :user_data, :subscription_status, :integer, default: 0, null: false
add_column :user_data, :subscriptions, :jsonb, default: [], null: false
add_index :user_data, :subscription_status
add_index :user_data, :subscriptions, using: :gin
```

**Rename column:**
```ruby
rename_column :user_data, :subscription_current_period_end, :subscription_valid_until
```

**Remove columns:**
```ruby
remove_column :user_data, :payment_failed_at
remove_column :user_data, :cancel_at_period_end
```

### Backfill subscription_status

```ruby
# In migration, after adding column
UserData.reset_column_information

UserData.find_each do |data|
  status = if data.stripe_subscription_id.present?
    case data.stripe_subscription_status
    when 'active', 'trialing'
      :active
    when 'past_due', 'unpaid'
      :payment_failed
    when 'incomplete'
      :incomplete
    when 'canceled'
      :canceled
    else
      :never_subscribed
    end
  elsif data.stripe_subscription_status == 'canceled'
    :canceled
  else
    :never_subscribed
  end

  data.update_column(:subscription_status, UserData.subscription_statuses[status])
end
```

---

## 2. Update User::Data Model

**File:** `app/models/user/data.rb`

### Add Enum

```ruby
enum subscription_status: {
  never_subscribed: 0,
  incomplete: 1,
  active: 2,
  payment_failed: 3,
  cancelling: 4,
  canceled: 5
}
```

### Update/Add Helper Methods

Replace existing methods:

```ruby
# Replace subscription_paid?
def subscription_paid?
  return true if standard?
  subscription_valid_until.present? && subscription_valid_until > Time.current
end

# Replace in_grace_period?
def in_grace_period?
  payment_failed? && subscription_valid_until.present? && subscription_valid_until > Time.current
end

# Replace grace_period_ends_at
def grace_period_ends_at
  subscription_valid_until if in_grace_period?
end

# Add new helper methods
def can_checkout?
  subscription_status.in?(%w[never_subscribed canceled])
end

def can_change_tier?
  subscription_status.in?(%w[active payment_failed cancelling])
end

def current_subscription
  subscriptions.find { |s| s['ended_at'].nil? }
end
```

---

## 3. Update Webhook Handlers

### 3.1 Update: `app/commands/stripe/webhook/subscription_created.rb`

**Changes:**
- Set `subscription_status` based on Stripe status
- Use `subscription_valid_until` instead of `subscription_current_period_end`
- Initialize `subscriptions` array entry

```ruby
def call
  # Early return for expired incomplete subscriptions
  return if subscription.status == 'incomplete_expired'

  unless user
    Rails.logger.error("Subscription created but user not found for customer: #{subscription.customer}")
    return
  end

  # Determine our subscription_status from Stripe's status
  our_status = case subscription.status
  when 'incomplete'
    'incomplete'
  when 'active', 'trialing'
    'active'
  else
    'active' # Default to active for other statuses
  end

  # Update user's subscription data
  user.data.update!(
    membership_type: (our_status == 'incomplete' ? 'standard' : tier),
    stripe_subscription_id: subscription.id,
    stripe_subscription_status: subscription.status,
    subscription_status: our_status,
    subscription_valid_until: Time.zone.at(subscription.current_period_end)
  )

  # Append to subscriptions array
  subscriptions_array = user.data.subscriptions || []
  subscriptions_array << {
    stripe_subscription_id: subscription.id,
    tier: (our_status == 'incomplete' ? nil : tier),
    started_at: Time.current.iso8601,
    ended_at: nil,
    end_reason: nil,
    payment_failed_at: nil
  }
  user.data.update!(subscriptions: subscriptions_array)

  Rails.logger.info("Subscription created for user #{user.id}: #{tier} (#{subscription.id})")
end
```

### 3.2 Update: `app/commands/stripe/webhook/subscription_updated.rb`

**Major changes:**
- Handle tier changes with subscriptions array updates
- Detect `cancel_at_period_end: true` and set status to `cancelling`
- Extend `subscription_valid_until` by 7 days on payment failure
- Use `subscription_valid_until` instead of `subscription_current_period_end`

```ruby
def call
  unless user
    Rails.logger.error("Subscription updated but user not found for subscription: #{subscription.id}")
    return
  end

  # Check if price changed (upgrade/downgrade)
  handle_tier_change if previous_attributes.key?('items')

  # Check if cancellation was scheduled/unscheduled
  handle_cancellation_change

  # Update subscription status
  handle_status_change

  # Always update period end
  user.data.update!(
    subscription_valid_until: Time.zone.at(subscription.current_period_end)
  )

  Rails.logger.info("Subscription updated for user #{user.id}: status=#{subscription.status}")
end

private

def handle_tier_change
  new_price_id = subscription.items.data.first.price.id
  old_tier = user.data.membership_type
  new_tier = determine_tier(new_price_id)

  return unless old_tier != new_tier

  # Close old subscription entry in array
  subscriptions_array = user.data.subscriptions || []
  if current_sub = subscriptions_array.find { |s| s['ended_at'].nil? }
    current_sub['ended_at'] = Time.current.iso8601
    current_sub['end_reason'] = new_tier > old_tier ? 'upgraded' : 'downgraded'
  end

  # Open new subscription entry
  subscriptions_array << {
    stripe_subscription_id: subscription.id,
    tier: new_tier,
    started_at: Time.current.iso8601,
    ended_at: nil,
    end_reason: nil,
    payment_failed_at: nil
  }

  user.data.update!(
    membership_type: new_tier,
    subscriptions: subscriptions_array
  )

  Rails.logger.info("User #{user.id} tier changed: #{old_tier} -> #{new_tier}")
end

def handle_cancellation_change
  # Check if cancel_at_period_end changed
  if subscription.cancel_at_period_end && !user.data.cancelling?
    user.data.update!(subscription_status: 'cancelling')
    Rails.logger.info("User #{user.id} subscription set to cancelling")
  elsif !subscription.cancel_at_period_end && user.data.cancelling?
    # Cancellation was undone (e.g., via tier change)
    user.data.update!(subscription_status: 'active')
    Rails.logger.info("User #{user.id} subscription cancellation undone")
  end
end

def handle_status_change
  case subscription.status
  when 'active', 'trialing'
    user.data.update!(
      stripe_subscription_status: subscription.status,
      subscription_status: 'active'
    )
  when 'past_due'
    # Extend subscription_valid_until by 7 days for grace period
    grace_period_end = Time.current + 7.days

    # Record payment failure in subscriptions array
    subscriptions_array = user.data.subscriptions || []
    if current_sub = subscriptions_array.find { |s| s['ended_at'].nil? }
      current_sub['payment_failed_at'] ||= Time.current.iso8601
    end

    user.data.update!(
      stripe_subscription_status: 'past_due',
      subscription_status: 'payment_failed',
      subscription_valid_until: grace_period_end,
      subscriptions: subscriptions_array
    )
  when 'unpaid'
    # Grace period expired, downgrade to standard
    user.data.update!(
      membership_type: 'standard',
      stripe_subscription_status: 'unpaid',
      subscription_status: 'payment_failed'
    )
    Rails.logger.info("User #{user.id} downgraded to standard due to unpaid subscription")
  when 'canceled'
    user.data.update!(stripe_subscription_status: 'canceled')
  else
    user.data.update!(stripe_subscription_status: subscription.status)
  end
end
```

### 3.3 Update: `app/commands/stripe/webhook/subscription_deleted.rb`

**Changes:**
- Set `subscription_status: 'canceled'`
- Clear `subscription_valid_until`
- Update subscriptions array with ended_at and end_reason

```ruby
def call
  unless user
    Rails.logger.error("Subscription deleted but user not found for subscription: #{subscription.id}")
    return
  end

  old_tier = user.data.membership_type

  # Determine end reason from status
  end_reason = case user.data.stripe_subscription_status
  when 'past_due', 'unpaid'
    'payment_failed'
  else
    'canceled'
  end

  # Update last subscription entry in array
  subscriptions_array = user.data.subscriptions || []
  if current_sub = subscriptions_array.find { |s| s['ended_at'].nil? }
    current_sub['ended_at'] = Time.current.iso8601
    current_sub['end_reason'] = end_reason
  end

  # Downgrade to standard tier
  user.data.update!(
    membership_type: 'standard',
    stripe_subscription_status: 'canceled',
    subscription_status: 'canceled',
    stripe_subscription_id: nil,
    subscription_valid_until: nil,
    subscriptions: subscriptions_array
  )

  Rails.logger.info("Subscription deleted for user #{user.id}, downgraded from #{old_tier} to standard")
end
```

### 3.4 Update: `app/commands/stripe/webhook/invoice_payment_succeeded.rb`

**Changes:**
- Set `subscription_status: 'active'` if was incomplete or payment_failed
- Reset `subscription_valid_until` to normal period end (remove grace period extension)
- Clear `payment_failed_at` in subscriptions array

```ruby
def call
  unless user
    Rails.logger.error("Invoice payment succeeded but user not found for customer: #{invoice.customer}")
    return
  end

  # If transitioning from incomplete, initialize subscriptions array
  if user.data.incomplete?
    subscriptions_array = user.data.subscriptions || []
    if subscriptions_array.empty?
      # Get subscription from invoice
      if invoice.subscription.present?
        sub = Stripe::Subscription.retrieve(invoice.subscription)
        subscriptions_array << {
          stripe_subscription_id: sub.id,
          tier: user.data.membership_type,
          started_at: Time.current.iso8601,
          ended_at: nil,
          end_reason: nil,
          payment_failed_at: nil
        }
      end
    end
    user.data.update!(subscriptions: subscriptions_array)
  end

  # Clear payment failure in subscriptions array
  if user.data.payment_failed?
    subscriptions_array = user.data.subscriptions || []
    if current_sub = subscriptions_array.find { |s| s['ended_at'].nil? }
      current_sub['payment_failed_at'] = nil
    end
    user.data.update!(subscriptions: subscriptions_array)
  end

  # Reset to active status and normal period end
  # Get current period end from subscription
  if invoice.subscription.present?
    sub = Stripe::Subscription.retrieve(invoice.subscription)
    user.data.update!(
      stripe_subscription_status: 'active',
      subscription_status: 'active',
      subscription_valid_until: Time.zone.at(sub.current_period_end)
    )
  else
    user.data.update!(
      stripe_subscription_status: 'active',
      subscription_status: 'active'
    )
  end

  Rails.logger.info("Invoice payment succeeded for user #{user.id}")
end
```

### 3.5 Update: `app/commands/stripe/webhook/invoice_payment_failed.rb`

**Changes:**
- Set `subscription_status: 'payment_failed'`
- Extend `subscription_valid_until` by 7 days
- Record `payment_failed_at` in subscriptions array

```ruby
def call
  unless user
    Rails.logger.error("Invoice payment failed but user not found for customer: #{invoice.customer}")
    return
  end

  # Extend grace period
  grace_period_end = Time.current + 7.days

  # Record payment failure in subscriptions array
  subscriptions_array = user.data.subscriptions || []
  if current_sub = subscriptions_array.find { |s| s['ended_at'].nil? }
    current_sub['payment_failed_at'] ||= Time.current.iso8601
  end

  # Set payment failure state (start grace period)
  user.data.update!(
    stripe_subscription_status: 'past_due',
    subscription_status: 'payment_failed',
    subscription_valid_until: grace_period_end,
    subscriptions: subscriptions_array
  )

  Rails.logger.info("Invoice payment failed for user #{user.id}, grace period granted until #{grace_period_end}")
end
```

---

## 4. Create New Commands

### 4.1 Create: `app/commands/stripe/update_subscription.rb`

```ruby
class Stripe::UpdateSubscription
  include Mandate

  initialize_with :user, :product

  def call
    # Validate user has subscription
    raise ArgumentError, "No active subscription" unless user.data.stripe_subscription_id.present?

    # Validate not same tier
    raise ArgumentError, "Already on #{product} tier" if user.data.membership_type == product

    # Get new price ID
    new_price_id = product == 'premium' ?
      Jiki.config.stripe_premium_price_id :
      Jiki.config.stripe_max_price_id

    # Retrieve subscription from Stripe
    subscription = ::Stripe::Subscription.retrieve(user.data.stripe_subscription_id)

    # Get subscription item ID
    subscription_item = subscription.items.data.first
    raise ArgumentError, "Subscription has no items" unless subscription_item

    # Determine if upgrade or downgrade
    current_tier_value = tier_value(user.data.membership_type)
    new_tier_value = tier_value(product)
    is_upgrade = new_tier_value > current_tier_value

    # Update subscription in Stripe (both immediate)
    updated_subscription = ::Stripe::Subscription.update(
      subscription.id,
      items: [{
        id: subscription_item.id,
        price: new_price_id
      }],
      proration_behavior: is_upgrade ? 'always_invoice' : 'create_prorations'
    )

    # Update user data immediately (for both upgrades and downgrades)
    user.data.update!(
      membership_type: product,
      subscription_valid_until: Time.zone.at(updated_subscription.current_period_end)
    )

    Rails.logger.info("User #{user.id} #{is_upgrade ? 'upgraded' : 'downgraded'} to #{product}")

    {
      success: true,
      tier: product,
      effective_at: 'immediate',
      subscription_valid_until: Time.zone.at(updated_subscription.current_period_end)
    }
  end

  private

  def tier_value(tier)
    { 'standard' => 0, 'premium' => 1, 'max' => 2 }[tier]
  end
end
```

### 4.2 Create: `app/commands/stripe/cancel_subscription.rb`

```ruby
class Stripe::CancelSubscription
  include Mandate

  initialize_with :user

  def call
    # Validate user has subscription
    raise ArgumentError, "No active subscription" unless user.data.stripe_subscription_id.present?

    # Cancel subscription at period end
    subscription = ::Stripe::Subscription.update(
      user.data.stripe_subscription_id,
      cancel_at_period_end: true
    )

    # Update status to cancelling
    user.data.update!(subscription_status: 'cancelling')

    Rails.logger.info("User #{user.id} subscription set to cancel at #{user.data.subscription_valid_until}")

    {
      success: true,
      cancels_at: user.data.subscription_valid_until
    }
  end
end
```

---

## 5. Update Controller Endpoints

### 5.1 Update: `app/controllers/internal/subscriptions_controller.rb`

#### Add validation to `checkout_session` action

```ruby
def checkout_session
  product = params[:product]
  return_url = params[:return_url]

  # Validate product
  unless %w[premium max].include?(product)
    return render json: {
      error: {
        type: "invalid_product",
        message: "Invalid product. Must be 'premium' or 'max'"
      }
    }, status: :bad_request
  end

  # NEW: Block if user already has subscription
  unless current_user.data.can_checkout?
    return render json: {
      error: {
        type: "existing_subscription",
        message: "You already have a subscription. Use the update endpoint to change tiers or cancel first."
      }
    }, status: :bad_request
  end

  # ... rest of existing code
end
```

#### Add `update` action

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

  # Check user can change tier
  unless current_user.data.can_change_tier?
    return render json: {
      error: {
        type: "no_subscription",
        message: "You don't have an active subscription. Use checkout to create one."
      }
    }, status: :bad_request
  end

  # Check not same tier
  if current_user.data.membership_type == product
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
    success: result[:success],
    tier: result[:tier],
    effective_at: result[:effective_at],
    subscription_valid_until: result[:subscription_valid_until]
  }
rescue ArgumentError => e
  Rails.logger.error("Invalid subscription update: #{e.message}")
  render json: {
    error: {
      type: "invalid_request",
      message: e.message
    }
  }, status: :unprocessable_entity
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

#### Add `cancel` action

```ruby
def cancel
  # Check user has subscription
  unless current_user.data.stripe_subscription_id.present?
    return render json: {
      error: {
        type: "no_subscription",
        message: "You don't have an active subscription"
      }
    }, status: :bad_request
  end

  # Cancel subscription
  result = Stripe::CancelSubscription.(current_user)

  render json: {
    success: result[:success],
    cancels_at: result[:cancels_at]
  }
rescue StandardError => e
  Rails.logger.error("Failed to cancel subscription: #{e.message}")
  render json: {
    error: {
      type: "cancel_failed",
      message: "Failed to cancel subscription"
    }
  }, status: :internal_server_error
end
```

#### Update `status` action

```ruby
def status
  render json: {
    subscription: {
      tier: current_user.data.membership_type,
      subscription_status: current_user.data.subscription_status,
      subscription_valid_until: current_user.data.subscription_valid_until,
      in_grace_period: current_user.data.in_grace_period?,
      grace_period_ends_at: current_user.data.grace_period_ends_at
    }
  }
end
```

### 5.2 Update: `config/routes.rb`

Add new routes in subscriptions namespace:

```ruby
namespace :subscriptions do
  post :checkout_session
  post :verify_checkout
  post :portal_session
  post :update        # NEW
  delete :cancel      # NEW
  get :status
end
```

---

## 6. Update Existing Commands

### 6.1 Update: `app/commands/stripe/verify_checkout_session.rb`

Change `subscription_current_period_end` → `subscription_valid_until`:

```ruby
# Update user's subscription data
user.data.update!(
  membership_type: tier,
  stripe_subscription_id: subscription.id,
  stripe_subscription_status: subscription.status,
  subscription_status: 'active',  # NEW
  subscription_valid_until: Time.zone.at(subscription_item.current_period_end),  # RENAMED
)
```

Also initialize subscriptions array if needed.

### 6.2 Update: `app/controllers/dev/users_controller.rb`

Update `clear_stripe_history` action:

```ruby
def clear_stripe_history
  user = User.find(params[:id])

  user.data.update!(
    stripe_customer_id: nil,
    stripe_subscription_id: nil,
    stripe_subscription_status: nil,
    subscription_status: 'never_subscribed',  # NEW
    subscription_valid_until: nil,             # RENAMED
    subscriptions: [],                         # NEW
    membership_type: 'standard'
  )

  render json: {
    message: "Stripe history cleared successfully",
    user: {
      id: user.id,
      handle: user.handle,
      membership_type: user.data.membership_type,
      subscription_status: user.data.subscription_status  # NEW
    }
  }
end
```

---

## 7. Write Tests

### 7.1 Command Tests

**Create:** `test/commands/stripe/update_subscription_test.rb`

Test scenarios:
- Upgrade premium → max (immediate with invoice)
- Downgrade max → premium (immediate with credit)
- Error: no subscription
- Error: same tier
- Error: invalid product

**Create:** `test/commands/stripe/cancel_subscription_test.rb`

Test scenarios:
- Cancel active subscription
- Error: no subscription

### 7.2 Controller Tests

**Update:** `test/controllers/internal/subscriptions_controller_test.rb`

Add test cases:
- `test "update subscription - upgrade premium to max"`
- `test "update subscription - downgrade max to premium"`
- `test "update subscription - blocks if same tier"`
- `test "update subscription - blocks if no subscription"`
- `test "cancel subscription - success"`
- `test "cancel subscription - blocks if no subscription"`
- `test "checkout_session - blocks if has active subscription"`
- `test "checkout_session - blocks if has incomplete subscription"`
- `test "checkout_session - blocks if has cancelling subscription"`
- `test "checkout_session - allows if canceled"`

### 7.3 Webhook Tests

**Update:** `test/commands/stripe/webhook/subscription_updated_test.rb`

Add test cases:
- Tier change updates subscriptions array
- Detects cancel_at_period_end and sets status to cancelling
- Payment failure extends subscription_valid_until
- Undo cancellation sets status back to active

**Update:** `test/commands/stripe/webhook/invoice_payment_failed_test.rb`

Test:
- Extends subscription_valid_until by 7 days
- Records payment_failed_at in subscriptions array
- Sets subscription_status to payment_failed

**Update other webhook tests** to use `subscription_valid_until` and `subscription_status`

### 7.4 Model Tests

**Update:** `test/models/user/data_test.rb`

Test new helper methods:
- `can_checkout?`
- `can_change_tier?`
- Updated `subscription_paid?`
- Updated `in_grace_period?`

---

## 8. Post-Implementation Verification

After implementing all changes:

1. **Run migrations:**
   ```bash
   bin/rails db:migrate
   ```

2. **Run tests:**
   ```bash
   bin/rails test
   ```

3. **Run linting:**
   ```bash
   bin/rubocop
   ```

4. **Test manually in development:**
   - Create new subscription
   - Upgrade premium → max
   - Downgrade max → premium
   - Cancel subscription
   - Test payment failure flow (use Stripe test cards)
   - Test incomplete payment flow

5. **Verify webhook handling:**
   - Use Stripe CLI to test webhooks locally
   - Check all webhook handlers update new fields correctly

---

## Common Pitfalls

1. **Don't forget to update ALL webhook handlers** - they all need to use new field names
2. **subscription_valid_until vs subscription_current_period_end** - use find/replace carefully
3. **subscriptions array must be valid JSONB** - use proper Ruby hashes that serialize to JSON
4. **Enum values** - use strings ('active') not integers when querying
5. **Grace period calculation** - extend from Time.current, not from period_end
6. **Backfill migration** - test on production-like data before deploying

---

## Rollback Plan

If issues arise:

1. Can revert migration (removes columns, restores old names)
2. Previous webhook handlers will still work with old schema
3. No Stripe API changes - all changes are internal to our DB

---

## Questions?

Refer to `.context/stripe.md` for:
- Complete state machine documentation
- Business rules and decisions
- Webhook behavior details
- All API endpoint specifications
