# Stripe Configuration
#
# Initialize Stripe with API credentials from Jiki.secrets

Stripe.api_key = Jiki.secrets.stripe_secret_key

# Pin the outbound API version explicitly so a gem upgrade can't silently change
# request/response shapes. Keep this in sync with the webhook endpoint's API version.
Stripe.api_version = "2026-05-27.dahlia"
