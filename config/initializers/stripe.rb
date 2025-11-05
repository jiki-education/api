# Stripe Configuration
#
# Initialize Stripe with API credentials from Jiki.secrets
# API version is determined by the stripe gem version

Stripe.api_key = Jiki.secrets.stripe_secret_key
