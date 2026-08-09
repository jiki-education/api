# API error/message types the front-end must localize

As of this change, the Rails API no longer returns human-readable `message`
text in JSON responses. Every error/success response returns a stable `type`
string (plus, where relevant, structured data) and the front-end is
responsible for mapping `type` to localized copy.

This document is a point-in-time snapshot of every `type` (and structured
extra field) the API currently emits, captured when the localized `message`
fields were removed from `config/locales/api_errors.en.yml`,
`api_messages.en.yml` and `validations.en.yml`. It is not auto-generated and
will drift - treat it as a starting catalogue for building the front-end's
copy, not a live contract. The `type` strings themselves are the actual
contract; grep this API repo for `render_4\d\d\(:` / `render_error` /
`error: { type:` if this list has gone stale.

For standard auth/session copy (unconfirmed, invalid credentials, locked
account, etc.) the [devise-i18n](https://github.com/tigrish/devise-i18n) gem's
locale YAML files are a good reference for already-translated, idiomatic
phrasing across many languages - most of this app's auth error types mirror
Devise's own vocabulary.

## Error types (`error.type` in a 4xx JSON body)

Grouped as they were in the old `api_errors.en.yml`, with the retired English
copy included as a starting point for the front-end catalogue.

### Authentication
- `unauthenticated` - "You need to sign in or sign up before continuing."
- `invalid_credentials` - "Invalid email or password"
- `unconfirmed` - "Please confirm your email address" (extra: `email`)
- `forbidden` - "Admin access required"
- `access_denied` - "Access denied"
- `premium_required` - "This feature is only available to premium members"
- `invalid_signature` - "Invalid signature"
- `invalid_captcha` - "Captcha verification failed"

### Tokens
- `invalid_token` - "Token is invalid or has expired"
- `token_expired` - "Token has expired"
- `session_expired` - "Session expired. Please log in again."
- `invalid_otp` - "Invalid verification code"
- `invalid_unsubscribe_token` - "Invalid or expired unsubscribe token"

### Resources
- `not_found` - "Resource not found"
- `lesson_not_found` - "Lesson not found"
- `level_not_found` - "Level not found"
- `course_not_found` - "Course not found"
- `user_not_found` - "User not found"
- `challenge_not_found` - "Challenge not found"
- `concept_not_found` - "Concept not found"
- `badge_not_found` - "Badge not found"
- `user_challenge_not_found` - "User challenge not found"
- `user_video_not_found` - "User video not found"
- `mailshot_not_found` - "Mailshot not found"
- `unknown_segment` - "Unknown audience segment"
- `mailshot_body_blank` - "Add content before sending this mailshot"
- `mailshot_already_sent` - "This mailshot has already been sent and can't be deleted"
- `validation_error` - "Validation failed" (extra: `errors` - an ActiveRecord `errors.details` hash keyed by field, e.g. `{ "email" => [{ "error" => "invalid", "value" => "bad" }], "password" => [{ "error" => "too_short", "count" => 6 }] }`. Like `error.type`, `error` here is a stable, locale-independent key (Rails' built-in validator error keys - `blank`, `invalid`, `taken`, `too_short`/`too_long` with `count`, `inclusion`, etc.) - map it to your own localized copy per field. Some entries also carry the submitted `value` (present for format/inclusion-style validators, not length/presence) - only ever the user's own input echoed back, nothing else)
- `invalid_event` - "Unknown analytics event"

### File submission
- `duplicate_filename` - "Duplicate filenames: ..." (extra: `filenames` - array of the clashing filenames)
- `file_too_large` - "File '...' is too large (maximum ... bytes)" (extra: `filename`, `max_bytes`)
- `too_many_files` - "Too many files (maximum ...)" (extra: `count`, `max`)
- `invalid_submission` - "Invalid submission" (extra: `reason` - one of `no_files`, `filename_required`, `code_required`)

### User progression
- `lesson_in_progress` - "Complete current lesson before starting a new one"
- `lesson_not_unlocked` - "Complete earlier lessons in this level first"
- `level_not_completed` - "Complete the current level first"
- `challenge_locked` - "Complete the lesson that unlocks this challenge first"
- `user_lesson_not_found` - "User lesson not found"
- `user_level_not_found` - "User level not found"
- `language_already_chosen` - "Language has already been chosen"
- `invalid_language` - "Invalid language selection"
- `missing_course` - "course_slug parameter required"

### Settings
- `invalid_password` - "Current password is incorrect" (currently unreachable - no live call site)
- `locale_update_failed` - "Locale update failed"
- `name_update_failed` - "Name update failed"
- `email_update_failed` - "Email update failed"
- `password_update_failed` - "Password update failed"
- `handle_update_failed` - "Handle update failed"
- `notification_update_failed` - "Notification update failed"
- `streaks_update_failed` - "Streaks update failed" (extra: `errors.enabled` - array containing `"boolean_required"` when the submitted value wasn't a boolean)
- `flag_invalid` - "Flag is invalid"

### Image/Avatar
- `no_image_provided` - "No image file provided"
- `invalid_image_type` - "Invalid image type"
- `invalid_avatar` - "Invalid avatar"
- `avatar_too_large` - "Avatar file is too large"

### Content
- `concept_locked` - "This concept is locked"
- `translation_error` - "Translation failed"
- `lesson_incomplete` - "Complete current lessons first"

### Subscriptions
- `invalid_product` - "Invalid product"
- `existing_subscription` - "Already has an active subscription"
- `invalid_return_url` - "Invalid return URL"
- `checkout_failed` - "Checkout failed"
- `no_customer` - "No Stripe customer found"
- `portal_failed` - "Portal session failed"
- `missing_session_id` - "Missing session ID"
- `invalid_session` - "Invalid session"
- `verification_failed` - "Verification failed"
- `no_subscription` - "No active subscription"
- `same_interval` - was "You are already on {interval} billing" - front-end already has `interval` from its own request, no extra needed
- `update_failed` - "Subscription update failed"
- `invalid_request` - "Invalid request"
- `invalid_interval` - was "Invalid interval. Must be 'monthly' or 'annual'"
- `cancel_failed` - "Cancellation failed"
- `not_cancelling` - "Subscription is not scheduled for cancellation"
- `reactivate_failed` - "Reactivation failed"
- `checkout_payment_incomplete` - was "Your payment wasn't completed. Please try again." (extra: `decline_code`, `interval`, `currency`). `decline_code` is a stable key (e.g. `insufficient_funds`, `expired_card`, `card_declined`), not free text - map it to your own localized copy rather than displaying it directly, same pattern as `error.type` elsewhere in the API.
- `unauthorized` (subscriptions-specific) - was "Checkout session does not belong to current user"

### External services
- `stripe_error` - "Payment processing error"
- `exercism_unavailable` - "Couldn't reach Exercism. Try again shortly."

### Exercism integration
- `no_exercism_link` - "This account isn't linked to Exercism"

### Account deletion
- `invalid_token` (account-deletion-specific, same type string as the OAuth one above) - was "Invalid or expired deletion token"
- `token_expired` - was "Deletion token has expired"
- `stripe_error` - was "Could not cancel your subscription. Please try again or contact support."

## Success/info message types (`type` in a 2xx JSON body via `render_success`)

- `password_reset_sent` - was "Reset instructions sent to %{email}" (extra: `email`)
- `password_reset_success` - was "Password has been reset successfully"
