# Stripe Integration - API Backend Plan

This document outlines the implementation plan for Stripe subscription billing on the Jiki API (Rails backend).

## Overview

**Subscription Model:**
- Standard (Free) - Default tier
- Premium ($3/month) - Mid tier
- Max ($10/month) - Top tier

**Key Features:**
- Embedded Checkout (payment on our site)
- Upgrade/downgrade between tiers
- Stripe Customer Portal for subscription management
- 1-week grace period for failed payments
- Downgrades take effect at end of billing period
- Webhook-driven status updates (no periodic sync)

## Phase 1: Dependencies & Configuration ✅ COMPLETED

### 1.1 Add Stripe Gem ✅
- ✅ Added `gem 'stripe'` to Gemfile
- ✅ Ran `bundle install`
- ✅ Verified gem installation

### 1.2 Configuration Setup ✅
- ✅ Added to `../config/settings/local.yml` with real keys
- ✅ Added to `../config/settings/ci.yml` with stub keys
- ✅ Added to `~/.config/jiki/secrets.yml` (NOT in git)
- ✅ Added stubs to `../config/settings/secrets.yml` (safe to commit)

### 1.3 Stripe Initializer ✅
- ✅ Created `config/initializers/stripe.rb`

## Phase 2: Database Schema ✅ COMPLETED

### 2.1 Migration: Add Stripe Fields to user_data ✅
- ✅ Merged into original `CreateUserData` migration
- ✅ Fields added with indexes
- ✅ Migrations run

### 2.2 Update membership_type Enum ✅
- ✅ Valid values: `["standard", "premium", "max"]`
- ✅ Default is `"standard"`

## Phase 3: Models & Helpers ✅ COMPLETED

### 3.1 User::Data Model Updates ✅
- ✅ Added all helper methods with 21 tests passing
  ```ruby
  # Membership tier checks
  def standard?
    membership_type == "standard"
  end

  def premium?
    membership_type == "premium"
  end

  def max?
    membership_type == "max"
  end

  # Payment status
  def subscription_paid?
    return true if standard? # Free tier always "paid"
    return false unless stripe_subscription_status

    %w[active trialing].include?(stripe_subscription_status)
  end

  # Grace period (1 week after payment failure)
  def in_grace_period?
    return false if subscription_paid?
    return false unless payment_failed_at

    payment_failed_at > 1.week.ago
  end

  def grace_period_ends_at
    return nil unless in_grace_period?
    payment_failed_at + 1.week
  end

  # Effective access (includes grace period)
  def has_premium_access?
    premium? || max?
  end

  def has_max_access?
    max?
  end
  ```

## Phase 4: Mandate Commands ✅ COMPLETED

### 4.1 Customer Management Commands ✅

#### `app/commands/stripe/get_or_create_customer.rb` ✅
- ✅ Implemented with tests
- [ ] Create Stripe customer with:
  - email
  - name (if available)
  - metadata: `{ user_id: user.id, handle: user.handle }`
- [ ] Store `stripe_customer_id` in `user.data`
- [ ] Return customer object

#### `app/commands/stripe/get_or_create_customer.rb`
- [ ] Check if user already has `stripe_customer_id`
- [ ] If yes: retrieve and return from Stripe
- [ ] If no: call `Stripe::CreateCustomer`
- [ ] Handle errors (customer deleted in Stripe, etc.)

### 4.2 Checkout Commands ✅

#### `app/commands/stripe/create_checkout_session.rb` ✅
- ✅ Implemented with tests
- [ ] Get or create Stripe customer
- [ ] Create Checkout Session with:
  ```ruby
  ui_mode: 'embedded',
  customer: customer_id,
  line_items: [{ price: price_id, quantity: 1 }],
  mode: 'subscription',
  return_url: "#{Jiki.config.frontend_base_url}/subscription/complete?session_id={CHECKOUT_SESSION_ID}",
  subscription_data: {
    metadata: { user_id: user.id }
  }
  ```
- [ ] Return `client_secret`

#### `app/commands/stripe/create_portal_session.rb` ✅
- ✅ Implemented with tests
- [ ] Requires existing `stripe_customer_id`
- [ ] Create Customer Portal session:
  ```ruby
  customer: customer_id,
  return_url: "#{Jiki.config.frontend_base_url}/settings/subscription"
  ```
- [ ] Return portal URL

### 4.3 Webhook Event Commands ✅ COMPLETED

#### `app/commands/stripe/webhook/handle_event.rb` ✅
- ✅ Verifies webhook signature
- ✅ Routes events to handlers (using memoize):
  - `checkout.session.completed` → `Stripe::Webhook::CheckoutCompleted`
  - `customer.subscription.created` → `Stripe::Webhook::SubscriptionCreated`
  - `customer.subscription.updated` → `Stripe::Webhook::SubscriptionUpdated`
  - `customer.subscription.deleted` → `Stripe::Webhook::SubscriptionDeleted`
  - `invoice.payment_succeeded` → `Stripe::Webhook::InvoicePaymentSucceeded`
  - `invoice.payment_failed` → `Stripe::Webhook::InvoicePaymentFailed`
- [ ] Log unhandled event types (for debugging)
- [ ] Return success response

#### `app/commands/stripe/webhook/checkout_completed.rb` ✅
- ✅ Implemented with memoized methods
- [ ] Find user by `stripe_customer_id` or metadata
- [ ] Update `user.data`:
  - `stripe_subscription_id`
  - `stripe_subscription_status = "active"`
- [ ] Queue welcome email: `SubscriptionMailer.defer(:confirmed, user.id, tier)`

#### `app/commands/stripe/webhook/subscription_created.rb` ✅
- ✅ Implemented with memoized methods
- [ ] Determine tier from price_id (premium vs max)
- [ ] Update `user.data`:
  - `membership_type` to new tier
  - `stripe_subscription_id`
  - `stripe_subscription_status`
  - `subscription_current_period_end`
  - Clear `payment_failed_at`

#### `app/commands/stripe/webhook/subscription_updated.rb` ✅
- ✅ Implemented with memoized methods
- [ ] Handle status changes:
  - `active` → update tier if price changed (upgrade/downgrade)
  - `past_due` → keep tier, mark payment issue
  - `canceled` → check if immediate or end of period
  - `unpaid` → downgrade to standard after grace period
- [ ] Update `user.data` fields accordingly
- [ ] Queue appropriate email (upgraded, downgraded, etc.)

#### `app/commands/stripe/webhook/subscription_deleted.rb` ✅
- ✅ Implemented with memoized methods
- [ ] Downgrade to standard:
  - `membership_type = "standard"`
  - `stripe_subscription_status = "canceled"`
  - Clear `stripe_subscription_id`
  - Clear `subscription_current_period_end`
- [ ] Queue cancellation email: `SubscriptionMailer.defer(:cancelled, user.id)`

#### `app/commands/stripe/webhook/invoice_payment_succeeded.rb` ✅
- ✅ Implemented with memoized methods
- [ ] Clear payment failure state:
  - `payment_failed_at = nil`
  - Update `stripe_subscription_status = "active"`
- [ ] If recovering from grace period, send confirmation email

#### `app/commands/stripe/webhook/invoice_payment_failed.rb` ✅
- ✅ Implemented with memoized methods
- [ ] Update payment failure state:
  - `payment_failed_at = Time.current`
  - `stripe_subscription_status = "past_due"`
- [ ] Queue payment failed email: `SubscriptionMailer.defer(:payment_failed, user.id)`
- [ ] Schedule grace period reminder for 6 days later

## Phase 5: Controllers ✅ COMPLETED

### 5.1 Internal::SubscriptionsController ✅

#### Action: `POST /internal/subscriptions/checkout_session` ✅
- ✅ Implemented with 16 controller tests
- [ ] Params: `{ price_id: "price_xxx" }`
- [ ] Validate price_id (must be premium or max)
- [ ] Call `Stripe::CreateCheckoutSession.(current_user.id, params[:price_id])`
- [ ] Return JSON: `{ client_secret: "cs_xxx" }`
- [ ] Handle errors (already subscribed, invalid price, etc.)

#### Action: `POST /internal/subscriptions/portal_session`
- [ ] Authenticate user
- [ ] Require user has `stripe_customer_id`
- [ ] Call `Stripe::CreatePortalSession.(current_user.id)`
- [ ] Return JSON: `{ url: "https://billing.stripe.com/..." }`
- [ ] Handle errors (no customer, etc.)

#### Action: `GET /internal/subscriptions/status`
- [ ] Authenticate user
- [ ] Return subscription status:
  ```json
  {
    "subscription": {
      "tier": "premium",
      "status": "active",
      "current_period_end": "2025-12-01T00:00:00Z",
      "payment_failed": false,
      "in_grace_period": false,
      "grace_period_ends_at": null
    }
  }
  ```

### 5.2 Webhooks::StripeController ✅

- ✅ Created with signature verification
- [ ] Inherit from `ApplicationController`
- [ ] Skip CSRF protection: `skip_before_action :verify_authenticity_token`
- [ ] Action: `POST /webhooks/stripe`
  - Read raw request body
  - Call `Stripe::Webhook::HandleEvent.(request.body.read, request.headers['Stripe-Signature'])`
  - Return `head :ok` on success
  - Return `head :bad_request` on signature verification failure
  - Log errors for debugging

## Phase 6: Routes ✅ COMPLETED

- ✅ Added subscription routes under `/internal/subscriptions`
- ✅ Added webhook route: `POST /webhooks/stripe`

## Phase 7: Mailers & Email Templates

### 7.1 Create SubscriptionMailer

Create `app/mailers/subscription_mailer.rb`:

```ruby
class SubscriptionMailer < ApplicationMailer
  def confirmed(user, tier:)
    with_locale(user) do
      @user = user
      @tier = tier
      mail(to: user.email, subject: t('.subject'))
    end
  end

  def upgraded(user, from_tier:, to_tier:)
    # ...
  end

  def downgraded(user, from_tier:, to_tier:, effective_date:)
    # ...
  end

  def payment_failed(user)
    # ...
  end

  def grace_period_ending(user)
    # ...
  end

  def cancelled(user)
    # ...
  end
end
```

### 7.2 Email Templates

Create MJML/HAML templates in `app/views/subscription_mailer/`:
- [ ] `confirmed.html.mjml` - Welcome to Premium/Max
- [ ] `confirmed.text.erb` - Plain text version
- [ ] `upgraded.html.mjml` - Upgraded tier confirmation
- [ ] `upgraded.text.erb`
- [ ] `downgraded.html.mjml` - Downgrade scheduled notice
- [ ] `downgraded.text.erb`
- [ ] `payment_failed.html.mjml` - Payment failed, grace period notice
- [ ] `payment_failed.text.erb`
- [ ] `grace_period_ending.html.mjml` - Grace period ending in 24h
- [ ] `grace_period_ending.text.erb`
- [ ] `cancelled.html.mjml` - Subscription cancelled, now on free tier
- [ ] `cancelled.text.erb`

### 7.3 i18n Translations

Create `config/locales/mailers/subscription_mailer.en.yml`:
- [ ] Add translation keys for all email templates
- [ ] Include subject lines, body copy, CTAs
- [ ] Create Hungarian version: `subscription_mailer.hu.yml`

## Phase 8: Background Jobs

### 8.1 Grace Period Management

Create `app/commands/stripe/send_grace_period_reminder.rb`:
- [ ] Find users where `payment_failed_at` is ~6 days ago
- [ ] Check if still in `past_due` status
- [ ] Send `SubscriptionMailer.grace_period_ending`
- [ ] Mark reminder as sent (add field or use separate tracking)

Create `app/commands/stripe/process_expired_grace_periods.rb`:
- [ ] Find users where grace period has expired (>7 days)
- [ ] Still in `past_due` or `unpaid` status
- [ ] Downgrade to standard tier
- [ ] Send cancellation email
- [ ] Queue as `queue_as :background`

### 8.2 Schedule Jobs (if using sidekiq-scheduler)

Add to `config/sidekiq.yml` or use cron:
```yaml
:schedule:
  grace_period_reminders:
    cron: '0 9 * * *'  # Daily at 9 AM
    class: Stripe::SendGracePeriodReminder

  expired_grace_periods:
    cron: '0 10 * * *'  # Daily at 10 AM
    class: Stripe::ProcessExpiredGracePeriods
```

## Phase 9: Testing ✅ COMPLETED (44 new tests)

### 9.1 Command Tests ✅
- ✅ `GetOrCreateCustomer` (3 tests)
- ✅ `CreateCheckoutSession` (2 tests)
- ✅ `CreatePortalSession` (2 tests)
- [ ] Test `GetOrCreateCustomer` (existing vs new)
- [ ] Test `CreateCheckoutSession` with mock Stripe API
- [ ] Test `CreatePortalSession`
- [ ] Test all webhook handlers with fixture events

### 9.2 Controller Tests ✅
- ✅ `Internal::SubscriptionsController` (16 tests)
  - Authentication guards
  - All 3 actions tested with success/error cases
- [ ] Test checkout session creation (mock command)
- [ ] Test portal session creation
- [ ] Test status endpoint response format

Create `test/controllers/webhooks/stripe_controller_test.rb`:
- [ ] Test signature verification
- [ ] Test successful webhook processing
- [ ] Test invalid signature handling

### 9.3 Model Tests ✅
- ✅ `User::Data` (21 tests)
  - All helper methods tested
- [ ] Test `subscription_paid?` logic
- [ ] Test `in_grace_period?` calculations
- [ ] Test `grace_period_ends_at` calculation

### 9.4 Webhook Tests
- [ ] TODO: Add webhook handler tests

### 9.5 Mailer Tests
- [ ] TODO: When mailers implemented
- [ ] Test locale support (English and Hungarian)
- [ ] Test email content includes expected data

## Phase 10: Security & Error Handling

### 10.1 Security Checklist
- [ ] Webhook signature verification implemented
- [ ] Stripe secret keys in secure credential storage (not ENV)
- [ ] Rate limiting on checkout endpoint (prevent abuse)
- [ ] Validate price_id against known prices (prevent arbitrary subscription creation)
- [ ] Customer ID ownership verification (user can only access their own)

### 10.2 Error Handling
- [ ] Graceful handling of Stripe API errors
- [ ] Retry logic for transient failures (use Sidekiq retries)
- [ ] Log all Stripe errors for debugging
- [ ] User-friendly error messages (don't expose Stripe internals)
- [ ] Dead letter queue for failed webhooks

## Phase 11: Documentation

### 11.1 Update Context Files

Update `.context/` files:
- [ ] Create `.context/stripe.md` with:
  - Subscription flow overview
  - Command usage examples
  - Webhook handling patterns
  - Testing with Stripe CLI
- [ ] Update `configuration.md` with Stripe config requirements
- [ ] Update `controllers.md` with subscription controller patterns
- [ ] Update `mailers.md` with subscription email examples

### 11.2 Update CLAUDE.md
- [ ] Add Stripe setup instructions for new developers
- [ ] Add testing instructions with Stripe test mode
- [ ] Add webhook testing with Stripe CLI

## Phase 12: Stripe Dashboard Setup (Manual)

**Note:** These steps are done manually in Stripe Dashboard:

1. **Products & Prices:**
   - Create "Premium" product with $3/month price
   - Create "Max" product with $10/month price
   - Copy price IDs to configuration

2. **Webhook Endpoint:**
   - Add webhook endpoint: `https://api.jiki.io/webhooks/stripe`
   - Select events to listen for (all subscription + invoice events)
   - Copy webhook signing secret to credentials

3. **Customer Portal:**
   - Configure branding (logo, colors)
   - Enable subscription cancellation (at period end)
   - Enable subscription upgrades/downgrades

## Phase 13: Pre-Commit Checklist

Before committing:
- [ ] Run `bin/rails test` - All tests pass
- [ ] Run `bin/rubocop` - No linting errors
- [ ] Run `bin/brakeman` - No security warnings
- [ ] Update context files if needed
- [ ] Use git-commit subagent for commit

## Deployment Checklist

Before deploying to production:
- [ ] Stripe secret keys configured in production
- [ ] Webhook endpoint configured in Stripe (production)
- [ ] Products and prices created in Stripe (production mode)
- [ ] Frontend configured with production price IDs
- [ ] Test complete flow in staging environment
- [ ] Monitor webhook deliveries in Stripe Dashboard

## Future Enhancements (Out of Scope)

These are intentionally excluded from this implementation:
- Annual billing option
- Free trials or promotional periods
- Coupon/discount codes
- Metered billing or usage-based pricing
- PPP (Purchasing Power Parity) pricing
- Tax calculation (Stripe Tax)
- Invoicing and receipts customization
- Multiple payment methods per customer
- Pause/resume subscription functionality
