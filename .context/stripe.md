# Stripe Integration

This document explains how Stripe subscription billing is integrated into the Jiki API.

## Overview

Jiki uses Stripe for subscription management with two paid tiers (Premium and Max) plus a free Standard tier. The integration uses:
- **Stripe Checkout** (custom UI mode with PaymentElement) for new subscriptions
- **Stripe Customer Portal** for subscription management (cancel, update payment methods)
- **Stripe Webhooks** for real-time subscription status updates
- **Adaptive Pricing** for PPP (Purchasing Power Parity) pricing

## Architecture

### User Data Model

Subscription state is stored in `User::Data` model (`app/models/user/data.rb`):

**Fields:**
- `stripe_customer_id` - Stripe Customer ID (persistent, never cleared)
- `stripe_subscription_id` - Current subscription ID (cleared on cancellation/deletion, not set for incomplete subscriptions)
- `stripe_subscription_status` - Mirrors Stripe's status (active, trialing, past_due, canceled, unpaid, incomplete, etc.)
- `subscription_status` - Our enum tracking subscription lifecycle (never_subscribed, incomplete, active, payment_failed, cancelling, canceled)
- `subscription_valid_until` - Timestamp when current subscription access expires
- `subscriptions` - JSONB array tracking subscription history (see below)
- `membership_type` - User's tier: `standard` (free), `premium`, or `max`

**Subscription Status Enum:**
```ruby
enum :subscription_status, {
  never_subscribed: 0,  # Initial state, user never had a subscription
  incomplete: 1,        # Checkout started, waiting for payment confirmation
  active: 2,            # Has active subscription (includes Stripe trialing status)
  payment_failed: 3,    # Stripe past_due or unpaid - payment issues
  cancelling: 4,        # User canceled, keeps access until period end
  canceled: 5           # Previously had subscription, now canceled/expired
}, prefix: true
```

**Note:** The `prefix: true` option generates method names like `subscription_status_active?` instead of `active?` to avoid conflicts with other methods.

**Subscriptions Array (JSONB):**
Tracks full subscription history for analytics, customer support, and grace period calculations:
```ruby
subscriptions: [
  {
    stripe_subscription_id: "sub_123",
    tier: "premium",
    started_at: "2024-01-15T10:00:00Z",
    ended_at: "2024-06-15T10:00:00Z",
    end_reason: "canceled",  # canceled, upgraded, downgraded, payment_failed
    payment_failed_at: nil   # or timestamp if payment failure occurred during this subscription
  },
  {
    stripe_subscription_id: "sub_456",
    tier: "max",
    started_at: "2024-07-01T10:00:00Z",
    ended_at: nil,  # Current active subscription
    end_reason: nil,
    payment_failed_at: nil
  }
]
```

**Notes:**
- Webhook handlers match subscriptions by `stripe_subscription_id` for accuracy
- When a user upgrades/downgrades, the old subscription entry is closed (ended_at set, end_reason set) and a new entry is opened
- `payment_failed_at` is recorded when payment fails, cleared when payment succeeds

**Grace Period Logic:**
- Grace period is 7 days after the original `subscription_valid_until` (current_period_end)
- When payment fails, `subscription_valid_until` is NOT modified - it stays at the original period end
- Grace period is calculated as: `subscription_valid_until + 7.days`
- User has access while in grace period: `payment_failed? && (subscription_valid_until + 7.days) > Time.current`
- `grace_period_ends_at` always returns `subscription_valid_until + 7.days` (regardless of payment status)
- Payment failure is recorded in current subscription entry in `subscriptions` array for historical tracking

**Methods:**
- `subscription_paid?` - Returns true if `subscription_valid_until > Time.current` or user is on standard tier
- `in_grace_period?` - Returns true if `subscription_status_payment_failed? && (subscription_valid_until + 7.days) > Time.current`
- `grace_period_ends_at` - Returns `subscription_valid_until + 7.days` if subscription_valid_until is present
- `can_checkout?` - Returns true if `subscription_status.in?(['never_subscribed', 'canceled'])`
- `can_change_tier?` - Returns true if `subscription_status.in?(['active', 'payment_failed', 'cancelling'])`

### Membership Tiers

Three tiers with different access levels:
1. **Standard** (free) - Default tier for all users
2. **Premium** - Paid tier with enhanced features
3. **Max** - Top paid tier with maximum features

Tier is determined by Stripe Price ID:
- `Jiki.config.stripe_premium_price_id` → `premium`
- `Jiki.config.stripe_max_price_id` → `max`

## API Endpoints

All subscription endpoints are in `app/controllers/internal/subscriptions_controller.rb`.

### POST /internal/subscriptions/checkout_session

Creates a Stripe Checkout Session for new subscriptions.

**Parameters:**
- `product`: `"premium"` or `"max"`
- `return_url`: Frontend URL to return to after checkout

**Validation:**
- Blocks if `!user.data.can_checkout?` (i.e., user has `subscription_status` of `active`, `payment_failed`, `cancelling`, or `incomplete`)
- Allows if `user.data.can_checkout?` (i.e., `subscription_status` is `never_subscribed` or `canceled`)

**Behavior:**
- Calls `Stripe::CreateCheckoutSession` command
- Creates/retrieves Stripe Customer via `Stripe::GetOrCreateCustomer`
- Returns `client_secret` for frontend to initialize PaymentElement

**Command:** `app/commands/stripe/create_checkout_session.rb`

### POST /internal/subscriptions/update

Updates an existing subscription tier (upgrade/downgrade).

**Parameters:**
- `product`: `"premium"` or `"max"`

**Validation:**
- User must have `user.data.can_change_tier?` (i.e., `subscription_status` of `active`, `payment_failed`, or `cancelling`)
- User must not already be on the requested tier
- If user has `subscription_status: cancelling`, changing tier will automatically resume subscription (Stripe clears `cancel_at_period_end`)

**Behavior:**
- **Both upgrades and downgrades happen immediately**
- **Upgrades** (premium→max): Immediate charge with `proration_behavior: 'always_invoice'`
- **Downgrades** (max→premium): Immediate with account credit via `proration_behavior: 'create_prorations'`
  - User loses Max features immediately
  - Stripe creates account credit for unused Max time
  - Credit automatically applies to next Premium invoice
- Calls `Stripe::UpdateSubscription` command
- Returns new tier and updated `subscription_valid_until`

**Command:** `app/commands/stripe/update_subscription.rb`

### POST /internal/subscriptions/verify_checkout

Verifies a completed checkout session and immediately syncs subscription data (faster than waiting for webhook).

**Parameters:**
- `session_id`: Stripe Checkout Session ID

**Behavior:**
- Retrieves session from Stripe
- Verifies session belongs to current user (security check)
- Retrieves full subscription details
- Updates user data with subscription info
- Returns tier information

**Command:** `app/commands/stripe/verify_checkout_session.rb`

### POST /internal/subscriptions/portal_session

Creates a Stripe Customer Portal session for managing subscriptions.

**Returns:**
- `url`: URL to redirect user to Stripe's hosted portal

**Portal allows users to:**
- Cancel subscription (immediate or at period end)
- Resume scheduled cancellation
- Update payment method
- View billing history
- Update billing details

**Command:** `app/commands/stripe/create_portal_session.rb`

### DELETE /internal/subscriptions/cancel

Cancels a subscription.

**Behavior:**
- Calls Stripe API with `cancel_at_period_end: true`
- User keeps access until `subscription_valid_until`
- Sets `subscription_status: 'cancelling'`
- At period end: `subscription.deleted` webhook fires and sets status to `canceled`

**Also works for incomplete subscriptions** - immediately cancels pending subscription

**Command:** `app/commands/stripe/cancel_subscription.rb`

### Subscription Status (via GET /internal/me)

**IMPORTANT:** Subscription status is now returned as part of the `/internal/me` endpoint, not a dedicated endpoint.

The `SerializeUser` serializer includes:
- `subscription_status`: Our enum status (never_subscribed, incomplete, active, payment_failed, cancelling, canceled) - **always present**
- `subscription`: Object with subscription details - **only present when subscription_status is not never_subscribed or canceled**
  - `in_grace_period`: Boolean indicating if in grace period
  - `grace_period_ends_at`: When grace period expires (same as subscription_valid_until if in grace period)
  - `subscription_valid_until`: When access expires

**Example Response:**
```json
{
  "user": {
    "handle": "alice",
    "membership_type": "premium",
    "email": "alice@example.com",
    "name": "Alice",
    "subscription_status": "active",
    "subscription": {
      "in_grace_period": false,
      "grace_period_ends_at": "2025-12-08T09:47:13Z",
      "subscription_valid_until": "2025-12-08T09:47:13Z"
    }
  }
}
```

## Commands

All Stripe commands are in `app/commands/stripe/`.

### Stripe::GetOrCreateCustomer

**File:** `app/commands/stripe/get_or_create_customer.rb`

Creates or retrieves a Stripe Customer for a user.

**Behavior:**
- If user has `stripe_customer_id`, attempts to retrieve existing customer
- If customer not found in Stripe (deleted), creates new one
- Creates new customer with user's email and handle
- Stores customer ID in `user.data.stripe_customer_id`

### Stripe::CreateCheckoutSession

**File:** `app/commands/stripe/create_checkout_session.rb`

Creates a Stripe Checkout Session for subscription purchase.

**Parameters:**
- `user` - User purchasing subscription
- `price_id` - Stripe Price ID (premium or max)
- `return_url` - URL to return to after checkout

**Creates session with:**
- `ui_mode: 'custom'` - For embedded checkout with PaymentElement
- `mode: 'subscription'` - Subscription billing
- ~~`billing_address_collection: 'required'`~~ - Removed for now
- `adaptive_pricing: { enabled: true }` - PPP pricing
- `subscription_data.metadata.user_id` - Track user in Stripe

### Stripe::VerifyCheckoutSession

**File:** `app/commands/stripe/verify_checkout_session.rb`

Verifies completed checkout and syncs subscription data immediately.

**Security:**
- Verifies `session.customer == user.data.stripe_customer_id`
- Raises `SecurityError` if session doesn't belong to user

**Updates user.data with:**
- `membership_type` (determined from price ID)
- `stripe_subscription_id`
- `stripe_subscription_status`
- `subscription_status` (set to `active`)
- `subscription_valid_until` (from subscription's current_period_end)
- Appends to `subscriptions` array

### Stripe::CreatePortalSession

**File:** `app/commands/stripe/create_portal_session.rb`

Creates Customer Portal session for subscription management.

**Returns:** Portal session with URL to redirect user

## Webhooks

Webhook endpoint: `POST /webhooks/stripe` (`app/controllers/webhooks/stripe_controller.rb`)

**Security:** Uses Stripe signature verification via `Stripe::Webhook.construct_event`

**Event Router:** `app/commands/stripe/webhook/handle_event.rb` routes events to specific handlers

### Handled Events

#### checkout.session.completed

**Handler:** `app/commands/stripe/webhook/checkout_completed.rb`

**Fires when:** User completes checkout session

**Updates:**
- `stripe_subscription_id`
- `stripe_subscription_status: 'active'`

**Note:** This is a backup to `verify_checkout` endpoint. The subscription details are set by `subscription.created` event.

#### customer.subscription.created

**Handler:** `app/commands/stripe/webhook/subscription_created.rb`

**Fires when:** New subscription is created

**Behavior:**
- Sets `subscription_status: 'incomplete'` if subscription status is `incomplete`
- Sets `subscription_status: 'active'` for active/trialing subscriptions
- Ignores `incomplete_expired` subscriptions (already expired, no action needed)
- Updates:
  - `membership_type` (based on price ID) - only for active subscriptions, not incomplete
  - `stripe_subscription_id`
  - `stripe_subscription_status`
  - `subscription_status`
  - `subscription_valid_until` (from subscription's current_period_end)
  - Appends to `subscriptions` array with `started_at` timestamp

#### customer.subscription.updated

**Handler:** `app/commands/stripe/webhook/subscription_updated.rb`

**Fires when:** Subscription is modified (tier change, status change, period renewal, cancellation scheduled)

**Handles:**
1. **Tier changes** - Detects price changes via `previous_attributes.key?('items')`
   - Matches current subscription in array by `stripe_subscription_id`
   - Closes old subscription entry: sets `ended_at`, determines `end_reason` (upgraded/downgraded based on tier hierarchy)
   - Opens new subscription entry with new tier
   - Updates `membership_type`
   - TODO: Queue email notifications

2. **Status changes** - Updates based on `subscription.status`:
   - `active` / `trialing` → Set `subscription_status: 'active'` (unless subscription has `cancel_at_period_end: true`, then preserve 'cancelling' status)
   - `past_due` → Set `subscription_status: 'payment_failed'`, record `payment_failed_at` in subscriptions array (matched by subscription ID)
   - `unpaid` → Keep `subscription_status: 'payment_failed'`, downgrade `membership_type: 'standard'` (grace period expired)
   - `canceled` → Update `stripe_subscription_status` only (cleanup happens in `subscription.deleted`)
   - Other statuses → Update `stripe_subscription_status` only

3. **Cancellation scheduling** - Detects changes in `cancel_at_period_end`:
   - If `true` and status not already 'cancelling' → Set `subscription_status: 'cancelling'`
   - If `false` and status is 'cancelling' → Set `subscription_status: 'active'` (cancellation was undone, e.g., via tier change)

4. **Period updates** - Always updates `subscription_valid_until` from subscription's `current_period_end`

#### customer.subscription.deleted

**Handler:** `app/commands/stripe/webhook/subscription_deleted.rb`

**Fires when:**
- User cancels subscription immediately
- Subscription with `cancel_at_period_end: true` reaches end of period
- Payment fails repeatedly and Stripe auto-cancels (per Dashboard settings)
- Subscription is disputed and auto-canceled

**Updates:**
- `membership_type: 'standard'` (downgrade to free)
- `stripe_subscription_status: 'canceled'`
- `subscription_status: 'canceled'`
- `stripe_subscription_id: nil` ← **Clears subscription ID**
- `subscription_valid_until: nil`
- `subscriptions` array: Matches subscription by ID, sets `ended_at` and `end_reason` ('canceled' or 'payment_failed' based on previous status)

**Important:** Clearing `stripe_subscription_id` allows user to create new subscription via checkout.

#### invoice.payment_succeeded

**Handler:** `app/commands/stripe/webhook/invoice_payment_succeeded.rb`

**Fires when:** Recurring payment succeeds (or incomplete payment completes)

**Updates:**
- `stripe_subscription_status: 'active'`
- `subscription_status: 'active'` (if was `incomplete` or `payment_failed`)
- Update `subscription_valid_until` to subscription's `current_period_end`
- Update `subscriptions` array:
  - Matches subscription by ID, clears `payment_failed_at` if present
  - If no matching subscription found, creates new entry (for incomplete subscriptions that just succeeded)

#### invoice.payment_failed

**Handler:** `app/commands/stripe/webhook/invoice_payment_failed.rb`

**Fires when:** Recurring payment fails

**Updates:**
- `stripe_subscription_status: 'past_due'`
- `subscription_status: 'payment_failed'`
- `subscription_valid_until` is NOT modified (stays at original period end)
- Record `payment_failed_at` in subscriptions array (matches subscription by ID, sets if not already set)

**Grace Period:** Users have 7 days after `subscription_valid_until` to resolve payment (calculated as `subscription_valid_until + 7.days`). The `subscription_valid_until` field is not extended; grace period is calculated on-the-fly.

## User Subscription States

Users can be in one of several distinct states based on their subscription status.

### 1. Never Subscribed
**`subscription_status`: `never_subscribed`**

Expected data:
- `stripe_customer_id`: null or present (if they browsed checkout but never completed)
- `stripe_subscription_id`: null
- `stripe_subscription_status`: null
- `subscription_valid_until`: null
- `membership_type`: `standard`
- `subscriptions`: `[]`

User may:
- ✅ Subscribe to Premium or Max (via checkout)
- ❌ Upgrade/downgrade tier (no active subscription)
- ❌ Cancel subscription (nothing to cancel)
- ❌ Update payment method (no subscription)

### 2. Incomplete Payment
**`subscription_status`: `incomplete`**

Expected data:
- `stripe_customer_id`: present
- `stripe_subscription_id`: present
- `stripe_subscription_status`: `incomplete`
- `subscription_valid_until`: future date (23 hours from creation)
- `membership_type`: `standard`
- `subscriptions`: Array with incomplete subscription entry
- Checkout started but payment not completed (waiting for bank transfer, ACH, etc.)
- No access to paid features
- Will expire after 23 hours if not completed

User may:
- ✅ Cancel incomplete subscription (via API DELETE endpoint or Customer Portal)
- ✅ Update payment method (to complete payment)
- ❌ Create new checkout (already has pending subscription)
- ❌ Upgrade/downgrade tier (subscription not active yet)

UI should show: "Payment pending - waiting for confirmation..."

### 3. Active Premium
**`subscription_status`: `active`**

Expected data:
- `stripe_customer_id`: present
- `stripe_subscription_id`: present
- `stripe_subscription_status`: `active` or `trialing`
- `subscription_valid_until`: end of current billing period
- `membership_type`: `premium`
- `subscriptions`: Array with current subscription (ended_at: null)
- Full access to premium features

User may:
- ✅ Upgrade to Max (immediate with proration charge, loses Premium credit)
- ✅ Cancel subscription (becomes `cancelling`, keeps access until subscription_valid_until)
- ✅ Update payment method (via Customer Portal)
- ❌ Subscribe to new (already has subscription)
- ❌ Downgrade to Premium (already on Premium)

### 4. Active Max
**`subscription_status`: `active`**

Expected data:
- `stripe_customer_id`: present
- `stripe_subscription_id`: present
- `stripe_subscription_status`: `active` or `trialing`
- `subscription_valid_until`: end of current billing period
- `membership_type`: `max`
- `subscriptions`: Array with current subscription (ended_at: null)
- Full access to max features

User may:
- ✅ Downgrade to Premium (immediate with account credit for unused Max time)
- ✅ Cancel subscription (becomes `cancelling`, keeps access until subscription_valid_until)
- ✅ Update payment method (via Customer Portal)
- ❌ Subscribe to new (already has subscription)
- ❌ Upgrade to Max (already on Max)

### 5. Cancelling (Scheduled for Cancellation)
**`subscription_status`: `cancelling`**

Expected data:
- `stripe_customer_id`: present
- `stripe_subscription_id`: present
- `stripe_subscription_status`: `active` (Stripe still shows as active)
- `subscription_valid_until`: When cancellation takes effect
- `membership_type`: `premium` or `max` (unchanged until period ends)
- `subscriptions`: Array with current subscription (ended_at: null)
- User retains full access until `subscription_valid_until`
- Stripe subscription has `cancel_at_period_end: true`

User may:
- ✅ Resume subscription (undo cancellation via Customer Portal, sets status back to `active`)
- ✅ Upgrade/downgrade tier (automatically resumes subscription, sets status to `active`)
- ✅ Update payment method (via Customer Portal)
- ❌ Cancel again (already scheduled)
- ❌ Create new subscription (already has one)

UI should show: "Your subscription will end on [subscription_valid_until]. You'll keep access until then."

**Important:** Changing tiers via update endpoint while `cancelling` will call Stripe API which automatically clears `cancel_at_period_end` and continues the subscription with the new tier.

### 6. Payment Failed - In Grace Period
**`subscription_status`: `payment_failed`**

Expected data:
- `stripe_customer_id`: present
- `stripe_subscription_id`: present
- `stripe_subscription_status`: `past_due`
- `subscription_valid_until`: original period end (NOT extended)
- `membership_type`: `premium` or `max` (unchanged during grace period)
- `subscriptions`: Array with current subscription (ended_at: null, payment_failed_at: timestamp)
- Still has access to paid features while `(subscription_valid_until + 7.days) > Time.current` (grace period calculated, not stored)

User may:
- ✅ Upgrade/downgrade tier (may help resolve payment issues, immediate with proration)
- ✅ Update payment method (to resolve failure, Stripe will retry)
- ✅ Cancel subscription (becomes `cancelling`)
- ❌ Create new checkout (already has subscription with issues)

UI should show: "Payment failed. Please update your payment method. Access ends on [grace_period_ends_at]." (where grace_period_ends_at = subscription_valid_until + 7 days)

### 7. Payment Failed - Grace Period Expired
**`subscription_status`: `payment_failed`**

Expected data:
- `stripe_customer_id`: present
- `stripe_subscription_id`: present (not deleted yet)
- `stripe_subscription_status`: `unpaid`
- `subscription_valid_until`: in the past (grace period expired)
- `membership_type`: `standard` (downgraded by webhook)
- `subscriptions`: Array with current subscription (ended_at: null, payment_failed_at: >7 days ago)
- Lost access to paid features (subscription_valid_until has passed)
- Subscription still exists in Stripe (will eventually be deleted per Dashboard retry settings)

User may:
- ✅ Upgrade/downgrade tier (to attempt recovery, but already lost access)
- ✅ Update payment method (may resolve issue and restore access)
- ✅ Cancel subscription (becomes `canceled` immediately since already expired)
- ❌ Create new checkout (still has existing subscription)

UI should show: "Subscription unpaid - access suspended. Please update payment method or contact support."

### 8. Previously Subscribed (Canceled/Expired)
**`subscription_status`: `canceled`**

Expected data:
- `stripe_customer_id`: present
- `stripe_subscription_id`: null (cleared by deletion webhook)
- `stripe_subscription_status`: `canceled`
- `subscription_valid_until`: null
- `membership_type`: `standard`
- `subscriptions`: Array with past subscriptions (all have ended_at values)
- User had subscription in the past but it's now fully canceled/expired

User may:
- ✅ Subscribe to Premium or Max (create new subscription via checkout)
- ❌ Upgrade/downgrade tier (no active subscription)
- ❌ Cancel subscription (nothing to cancel)
- ❌ Update payment method (no active subscription)

UI could show: "You previously had [tier]. Resubscribe to regain access."

### 9. Incomplete Expired
**`subscription_status`: `canceled`** (or back to `never_subscribed` if first attempt)

Expected data:
- `stripe_customer_id`: present
- `stripe_subscription_id`: null (cleared or never set)
- `stripe_subscription_status`: `incomplete_expired` or null
- `membership_type`: `standard`
- Checkout was started but never completed (23 hours passed)
- No access to paid features

User may:
- ✅ Subscribe to Premium or Max (retry checkout)
- ❌ Upgrade/downgrade tier (no active subscription)
- ❌ Cancel subscription (nothing to cancel)
- ❌ Update payment method (no subscription to update)

### State Transitions

```
Never Subscribed
  ↓ (starts checkout with bank transfer)
Incomplete Payment
  ↓ (payment succeeds)
Active Premium/Max
  ↓ OR payment times out after 23 hours
Incomplete Expired → back to Never Subscribed or Canceled

Never Subscribed
  ↓ (checkout completed with instant payment)
Active Premium/Max
  ↓ (payment fails)
Payment Failed - In Grace Period (past_due, still has access)
  ↓ (payment succeeds via updated method)
Active Premium/Max
  ↓ OR (7 days pass without payment)
Payment Failed - Grace Period Expired (unpaid, downgraded to standard)
  ↓ (retry attempts exhausted)
Previously Subscribed (subscription deleted)
  ↓ (creates new checkout)
Active Premium/Max

Active Premium/Max
  ↓ (user cancels)
Cancelling (still has access until subscription_valid_until)
  ↓ (user changes tier before period end)
Active Premium/Max (cancellation cleared, subscription_status back to active)
  ↓ OR (subscription_valid_until passes)
Previously Subscribed (subscription.deleted webhook fires, status → canceled)

Active Premium
  ↓ (upgrades to Max - immediate)
Active Max (new subscription_valid_until)
  ↓ (downgrades to Premium - immediate with credit)
Active Premium (new subscription_valid_until, account credit for next invoice)
```

## Business Rules & Decisions

These decisions govern how the subscription system behaves in ambiguous scenarios:

### 1. Tier Changes During Payment Failures
**Decision:** Allow all tier changes (upgrades and downgrades)

**Rationale:** Updating the subscription may help resolve payment issues. Stripe will handle collecting payment for the new tier.

**States affected:** `payment_failed` (both grace period and expired)

### 2. Creating New Checkout with Failed Subscription
**Decision:** Block checkout, require user to fix or cancel existing subscription

**Rationale:** Prevents duplicate subscriptions and accidental double-billing. Forces clean resolution of payment issues.

**Implementation:** Validate in `checkout_session` endpoint - return error if `subscription_status` is `payment_failed`

### 3. Tier Changes During Scheduled Cancellation
**Decision:** Allow tier changes, automatically resume subscription

**Rationale:** User changing tiers clearly wants to keep subscription. Stripe automatically clears `cancel_at_period_end` when subscription items are updated anyway.

**Implementation:** When user with `subscription_status: cancelling` calls update endpoint, Stripe API automatically resumes subscription. Webhook handler detects `cancel_at_period_end: false` and sets `subscription_status: active`.

### 4. Incomplete Subscriptions
**Decision:** Store incomplete subscriptions, show "payment pending" UI, allow cancellation

**Rationale:** Incomplete subscriptions represent real checkout attempts waiting for payment confirmation (bank transfers, ACH, etc.). Users need visibility and ability to cancel if they change their mind.

**Implementation:**
- Set `subscription_status: incomplete` when subscription status is `incomplete`
- Block new checkout while incomplete subscription exists
- Allow cancellation via API `DELETE /internal/subscriptions/cancel` or Customer Portal
- If payment succeeds: `invoice.payment_succeeded` webhook transitions to `active`
- If 23 hours pass: `subscription.deleted` webhook transitions to `canceled`

### 5. Upgrade/Downgrade Timing
**Decision:** Both upgrades and downgrades happen immediately with prorations

**Rationale:** Simplifies implementation - no pending state tracking needed. Standard SaaS pattern.

**Implementation:**
- **Upgrades**: `proration_behavior: 'always_invoice'` - immediate charge for prorated amount
- **Downgrades**: `proration_behavior: 'create_prorations'` - immediate with account credit
  - User loses higher tier features immediately
  - Credit automatically applies to next invoice
  - Simpler UX than waiting for period end

## Implementation Status

All features described in this document are fully implemented as of Nov 6, 2025:

### ✅ Database Schema
- `subscription_status` integer enum column with index
- `subscription_valid_until` timestamp (renamed from `subscription_current_period_end`)
- `subscriptions` JSONB array with GIN index
- Removed: `payment_failed_at`, `cancel_at_period_end`

### ✅ API Endpoints
- `GET /internal/me` - Returns user data including subscription_status and subscription details
- `POST /internal/subscriptions/checkout_session` - Create checkout session (validates with `can_checkout?`)
- `POST /internal/subscriptions/verify_checkout` - Verify completed checkout session
- `POST /internal/subscriptions/portal_session` - Create Stripe customer portal session
- `POST /internal/subscriptions/update` - Tier changes (immediate upgrades/downgrades)
- `DELETE /internal/subscriptions/cancel` - Cancel at period end
- `POST /internal/subscriptions/reactivate` - Reactivate a cancelling subscription

### ✅ Commands
- `Stripe::UpdateSubscription` - Handles tier changes with proration
- `Stripe::CancelSubscription` - Sets cancel_at_period_end
- All webhook handlers updated for new schema

### ✅ Webhook Handlers
All handlers updated to maintain `subscription_status` enum and `subscriptions` array:
- `subscription.created` - Sets incomplete status when appropriate
- `subscription.updated` - Handles tier changes, cancellation scheduling, status changes
- `subscription.deleted` - Clears subscription, updates array
- `invoice.payment_succeeded` - Clears payment_failed_at, handles incomplete→active
- `invoice.payment_failed` - Records payment_failed_at without extending subscription_valid_until

### ✅ User Data Model
- `can_checkout?` - Returns true for never_subscribed/canceled
- `can_change_tier?` - Returns true for active/payment_failed/cancelling
- `subscription_paid?` - Checks subscription_valid_until or standard tier
- `in_grace_period?` - Calculates grace period as subscription_valid_until + 7 days
- `grace_period_ends_at` - Returns subscription_valid_until + 7.days

## Configuration

Stripe configuration is in:
- **API Keys:** `Jiki.secrets.stripe_api_key` (set via Rails credentials)
- **Webhook Secret:** `Jiki.secrets.stripe_webhook_secret`
- **Price IDs:**
  - `Jiki.config.stripe_premium_price_id`
  - `Jiki.config.stripe_max_price_id`
- **Frontend URL:** `Jiki.config.frontend_base_url` (for portal return URL)

## Testing

Stripe webhook tests should be in `test/commands/stripe/webhook/*_test.rb`.

**Note:** Current test coverage for subscription webhooks needs review - see existing tests in `test/commands/stripe/verify_checkout_session_test.rb`.

**Test scenarios to cover:**
- Upgrade from premium to max (immediate with charge)
- Downgrade from max to premium (immediate with credit)
- Checkout blocked for user with active subscription
- Checkout blocked for user with payment_failed subscription
- Checkout blocked for user with cancelling subscription
- Checkout blocked for user with incomplete subscription
- Checkout allowed for user with canceled subscription
- Tier change during payment failure (immediate)
- Tier change during cancelling state (resumes subscription, sets status to active)
- Cancel subscription (sets status to cancelling)
- Incomplete subscription payment succeeds (status transitions to active)
- Incomplete subscription expires after 23 hours (status transitions to canceled)
- Payment failure extends subscription_valid_until by 7 days
- Grace period expiration (subscription_valid_until passes)

### Development Utilities

For development and testing, there are dev-only endpoints available at `/dev/...` that return 404 in non-development environments.

#### DELETE /dev/users/:handle/clear_stripe_history

Clears all Stripe-related data for a user, resetting them to a fresh state:

**No authentication required** (development only)

**Effect:**
- Clears `stripe_customer_id`
- Clears `stripe_subscription_id`
- Clears `stripe_subscription_status`
- Resets `subscription_status` to `never_subscribed`
- Clears `subscription_valid_until`
- Clears `subscriptions` array to `[]`
- Resets `membership_type` to `"standard"`

**Example:**
```bash
curl -X DELETE http://localhost:3000/dev/users/testuser/clear_stripe_history
```

**Response:**
```json
{
  "message": "Stripe history cleared successfully",
  "user": {
    "id": 1,
    "handle": "user123",
    "membership_type": "standard",
    "subscription_status": "never_subscribed"
  }
}
```

**Controller:** `app/controllers/dev/users_controller.rb`

## Related Documentation

- User data model: `.context/user_data.md`
- API patterns: `.context/api.md`
- Controllers: `.context/controllers.md`
- Configuration: `.context/configuration.md`

## Future Enhancements

1. **Email Notifications** - Implement TODOs in webhook handlers for subscription events (upgrades, downgrades, cancellations, payment failures)
2. **Subscription Analytics** - Query `subscriptions` array for churn analysis, LTV calculations
3. **Proration Preview** - Show users how much they'll be charged/credited before tier changes
4. **Cancel Pending Tier Change** - Allow users to cancel scheduled downgrades
5. **Annual Billing** - Support yearly subscriptions with discounts
6. **Promotional Pricing** - Coupons and promotional offers
