# Stripe Integration Status

## ✅ COMPLETED (Core Functionality Ready)

### Configuration & Setup
- ✅ Stripe gem installed
- ✅ Configuration in local.yml, ci.yml, secrets.yml
- ✅ Initializer created (API version managed by gem)
- ✅ Database migration (merged into CreateUserData)
- ✅ Webhook secret configured (ngrok-based)

### Models
- ✅ User::Data helpers (21 tests passing)

### Commands
- ✅ Stripe::GetOrCreateCustomer
- ✅ Stripe::CreateCheckoutSession
- ✅ Stripe::CreatePortalSession
- ✅ Stripe::Webhook::HandleEvent
- ✅ Stripe::Webhook::CheckoutCompleted
- ✅ Stripe::Webhook::SubscriptionCreated
- ✅ Stripe::Webhook::SubscriptionUpdated
- ✅ Stripe::Webhook::SubscriptionDeleted
- ✅ Stripe::Webhook::InvoicePaymentSucceeded
- ✅ Stripe::Webhook::InvoicePaymentFailed

### Controllers
- ✅ Internal::SubscriptionsController (16 tests)
- ✅ Webhooks::StripeController

### Routes
- ✅ POST /internal/subscriptions/checkout_session
- ✅ POST /internal/subscriptions/portal_session
- ✅ GET /internal/subscriptions/status
- ✅ POST /webhooks/stripe

### Tests
- ✅ 1137 total tests passing
- ✅ 44 new Stripe-related tests
- ✅ Rubocop clean
- ✅ Brakeman clean

## ⏳ TODO (Future Enhancements)

### Testing
- [ ] Webhook handler tests
- [ ] Integration tests with Stripe CLI

### Mailers & Jobs
- [ ] SubscriptionMailer with 6 email templates
- [ ] Background jobs for grace period management
- [ ] Email i18n (EN/HU)

### Documentation
- [ ] Update .context/stripe.md
- [ ] Webhook testing instructions

## 🧪 Testing with Stripe

### Local Development Setup

#### Option A: Using ngrok (Recommended - No Stripe CLI needed)

1. **Set up ngrok webhook in Stripe Dashboard**
   - Go to https://dashboard.stripe.com/test/webhooks
   - Click "Add endpoint"
   - URL: `https://ihid.ngrok.dev/webhooks/stripe`
   - Select these events:
     - `checkout.session.completed`
     - `customer.subscription.created`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
     - `invoice.payment_succeeded`
     - `invoice.payment_failed`
   - Click "Add endpoint"
   - Copy the webhook signing secret (starts with `whsec_...`)

2. **Add webhook secret** to `~/.config/jiki/secrets.yml`:
   ```yaml
   stripe_webhook_secret: "whsec_uuc4hE8k4lrNbZn4N1203EYlRFfT9pBz"
   ```

3. **Make sure ngrok is running** (pointing to port 3060)

4. **Start the server**:
   ```bash
   foreman start -f Procfile.dev
   ```

#### Option B: Using Stripe CLI (Alternative)

1. **Install Stripe CLI** (one-time)
   ```bash
   brew install stripe/stripe-brew/stripe
   ```

2. **Authenticate** (one-time)
   ```bash
   stripe login
   ```

3. **Start webhook forwarding** (each dev session)
   ```bash
   bin/stripe-webhooks
   ```
   Copy the webhook signing secret and add to `~/.config/jiki/secrets.yml`

4. **Start the server** (in another terminal):
   ```bash
   foreman start -f Procfile.dev
   ```

### Test Cards
- Success: `4242424242424242`
- Requires SCA: `4000002500003155`
- Declined: `4000000000000002`
- Payment fails: `4000000000000341`

### Manual Testing Flow

1. **Start Rails server**
   ```bash
   bin/rails server
   ```

2. **Start Stripe webhook forwarding** (in another terminal)
   ```bash
   bin/stripe-webhooks
   ```

3. **Create user and get JWT token**
   ```bash
   # Sign up or login via your frontend
   ```

4. **Test checkout session creation**
   ```bash
   curl -X POST http://localhost:3060/internal/subscriptions/checkout_session \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"price_id":"price_1SPyjBEvAkEDKF4o2OAJy7Ir"}'
   ```

5. **Use returned `client_secret` in frontend**

6. **Complete checkout** with test card `4242424242424242`

7. **Verify webhook received** - Check Rails logs for:
   ```
   Checkout completed for user X, subscription: sub_xxx
   Subscription created for user X: premium (sub_xxx)
   ```

8. **Verify user upgraded**
   ```bash
   curl http://localhost:3060/internal/subscriptions/status \
     -H "Authorization: Bearer YOUR_JWT_TOKEN"
   ```

9. **Test subscription management**
   ```bash
   # Get portal URL
   curl -X POST http://localhost:3060/internal/subscriptions/portal_session \
     -H "Authorization: Bearer YOUR_JWT_TOKEN"

   # Open the returned URL in browser to manage subscription
   ```

## 🎯 Next Steps

1. ✅ **Webhooks tested** - All webhook handlers have tests
2. **Implement mailers** - Create email templates for subscription events (when needed)
3. **Background jobs** - Grace period management (when needed)
4. **Frontend** - Follow STRIPE_PLAN_FE.md

## 🔧 Configuration Notes

### API Version
The Stripe API version is **not pinned** in the initializer. The stripe-ruby gem v9+ uses the API version that was current when the gem was released. This ensures compatibility without hardcoding versions that may become invalid.

### Webhook Setup
Currently using **ngrok** (`https://ihid.ngrok.dev`) for webhook forwarding in development. This avoids needing to install/update the Stripe CLI.

Production webhooks should be configured in Stripe Dashboard pointing to: `https://api.jiki.io/webhooks/stripe`
