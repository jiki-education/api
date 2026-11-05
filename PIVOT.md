# Pivot: finite Coding Fundamentals course (API)

## Context (read this first)

**The decision.** Jiki is being pivoted from an open-ended platform into one finished product: the
Coding Fundamentals course (roughly 2-3 months for a learner). Everything that implied ongoing
expansion is removed, what remains is finished properly, and the whole thing is then left running
with minimal maintenance. The master plan lives in `../front-end/pivot.md`; read its Context section
first. This file is the API-side breakdown of that plan and nothing more.

**What changes for this repo, in one line each:**

- Learn to Build never had API models, so removal here is copy only: the onboarding drip and the
  premium welcome email.
- The course gets its last level(s) seeded and the milestone emails for them finished and
  translated.
- Premium changes from a monthly/annual Stripe subscription to a one-off lifetime purchase. This is
  the bulk of the API work: checkout, webhooks, entitlements, `User::Data` columns, pricing table,
  serializers, emails, ~3,500 lines of tests.
- Existing subscribers are converted to lifetime and their Stripe subscriptions cancelled.
- Copy is frozen, then mailer translations are finished for the locales that are kept.
- Recurring jobs, workflows and alerting are trimmed to a maintenance footprint.

**Why the ordering matters.** Same as the front-end: translation multiplies by locale, so copy must
be frozen first. Do content, then pricing model, then emails, then translate once. The pricing
change also has a hard dependency on the front-end data layer, so the API and front-end pricing PRs
must land together (or the API must keep serving the old shape until the front-end switches).

**Open decisions (not yet made, do not assume):** base price and PPP scaling, the Ask Jiki cap for
lifetime users, the refund policy, which locales are kept, whether Exercism Insider/Bootcamp
entitlements still grant lifetime Premium, whether `everything` is a real level, and whether the
`Payment` history endpoint stays.

**Repos involved.** This repo (`jiki/api`, Rails), `../front-end` (Next.js app, curriculum,
content, `llm-chat-proxy`), `../config` (the `Jiki.config` / `Jiki.secrets` gem, which owns the
Stripe price-id keys) and `../terraform` (billing cap). File paths below are relative to this repo
unless prefixed with `front-end/` or `config/` (the gem).

**Useful facts discovered while building this list:**

- Curriculum seed: `db/seeds/curriculum.json` has **19 levels, 124 lessons (90 exercises)**. The
  front-end registry has 20: this repo has **no `everything` level**. The front-end's
  `everything.ts` describes itself as "All language features enabled for testing and advanced
  exercises" with no exercise list, and the `changing-dictionaries` milestone email already says
  "that's the last level of Coding Fundamentals". Decide which is true before touching seeds.
- The API stores slugs only. All screen copy is authored in `front-end/curriculum/src`.
  `lib/curriculum_content_check.rb` (run by `.github/workflows/curriculum-content.yml` against
  front-end@main, weekly) is the only thing coupling the repos.
- Level milestone email copy is the one DB-translated curriculum thing here: `Level` +
  `Level::Translation`, seeded from `db/seeds/level_translations/{locale}.json` (18 locales, 19
  entries each; `hu.json` is `[HU TBD]` placeholders). `dictionaries` and `changing-dictionaries`
  already have English milestone copy.
- Learn to Build / projects / episodes / livestreams / roadmap have **no models, tables, routes,
  commands or jobs** here. Grep hits are copy only: `onboarding_mailer.{en,bn,el,uk}.yml`,
  `premium_mailer.en.yml`, and one "fun projects" line in `account_mailer.en.yml`.
- Premium access is driven solely by `user_data.membership_type`. `PremiumEntitlement` only blocks
  `User::DowngradeToStandard`. `PremiumEntitlement::STRIPE` is declared but never granted anywhere.
  Only `EXERCISM_INSIDER` (revocable) and `EXERCISM_BOOTCAMP` (one-way) are used, synced daily by
  `User::Exercism::SyncEntitlements`.
- Checkout is hardcoded `mode: 'subscription'` (`app/commands/stripe/create_checkout_session.rb`)
  and `VerifyCheckoutSession` hard-requires `session.subscription`. `Payment` rows are only ever
  created from `invoice.payment_succeeded`; there is no one-off `payment_intent` path.
- `PREMIUM_PRICES` in `config/initializers/pricing.rb` has 103 currencies, each `{monthly:, annual:}`
  only. `COUNTRY_CURRENCIES` (same file) maps country → currency and is unaffected.
  `lib/tasks/stripe_currency_options.rake` syncs those to the two recurring Stripe prices.
- Stripe price ids come from the config gem: `stripe_premium_monthly_price_id` and
  `stripe_premium_annual_price_id` (`config/settings/{local,ci}.yml` in `../config`).
- `user_data.subscription_interval` is `NOT NULL DEFAULT 'monthly'`; `subscription_status` is an
  integer enum with 6 values (`never_subscribed incomplete active payment_failed cancelling
  canceled`); plus `stripe_subscription_id/status`, `subscription_valid_until`, `subscriptions`
  jsonb. `SerializeUser` exposes `subscription_status`, `subscription {interval, in_grace_period,
  grace_period_ends_at, subscription_valid_until}` and `premium_prices {currency, monthly, annual,
  country_code}`.
- Ask Jiki gating (`app/commands/assistant_conversation/check_user_access.rb`): premium = unlimited,
  free = one lesson conversation ever. There are no usage counters in this repo; the daily/monthly
  cap lives in `front-end/llm-chat-proxy/src/usage.ts`. Challenge chat is premium-only.
- The `welcome_modal` flag is a generic client-namespaced row in `user_flags`
  (`client:welcome_modal`). Nothing in app code knows the key; only tests use it as an example.
  No API change is needed to remove the modal.
- The API does not issue certificates. Nothing here needs to change for course completion unless a
  "course completed" email is wanted (`ProgressionMailer` has a "future: course completion" note).
- Locales: `config/initializers/i18n.rb` has `ALL_LOCALES` (31) and `PRODUCTION_LOCALES` (11:
  `bn el en es-ES es-419 fr hu it pt-PT pt-BR uk`). `devise_mailer`, `notifications_mailer`,
  `progression_mailer`, `shared` exist for ~31 locales; `account_mailer`, `onboarding_mailer`,
  `premium_mailer` exist for the 11 only. Non-en onboarding files are independent rewrites, not
  translations (hu is 3KB vs 8KB en), and only `bn el en uk` contain the Learn to Build pitch.
- Docs: `docs/` holds only `api_error_types.md` and `i18n.md`. Business-model statements live in
  `CLAUDE.md` lines 24-25 only.
- There is a `lesson_translations` migration with no model or code reference (dead).

**How to use this file.** Pick a section, tick items as they land, commit the tick with the work.
Work on feature branches prefixed `ihid-`. Keep sections in this order when adding items.

Suggested order: finish the levels -> strip Learn to Build copy -> pricing model -> migrate
subscribers -> freeze copy -> translations -> maintenance/cleanup.

## Finish the last levels

- [ ] Decide whether `everything` is a real published level or a front-end testing scaffold; if
      real, append it to `db/seeds/curriculum.json` with its lessons (goes through
      `Level::CreateAllFromJson` on deploy; use `Curriculum::AppendLesson` semantics, never mid-level inserts)
- [ ] Reconcile lesson lists for `dictionaries` (3 here: video + 2 exercises) and
      `changing-dictionaries` (7 here: video + 6 exercises) against the front-end's final content
      once the 16 exercises are reviewed there; run `bin/rails curriculum:verify_content`
- [ ] Write the final-level milestone email: `changing-dictionaries` currently says "that's the last
      level of Coding Fundamentals" and "That's a wrap"; move/rewrite if `everything` is added
- [ ] Add an Exercism "what next" CTA to the final level's milestone email (the API is the only
      thing that emails users at course end)
- [ ] Decide whether to add a `course_completed` email to `ProgressionMailer` (noted as "future"
      in `app/mailers/progression_mailer.rb`) or rely on the front-end certificate flow
- [ ] Add milestone translations for any new level to `db/seeds/level_translations/*.json` for kept
      locales (`test/db/seeds/level_translations_completeness_test.rb` will fail until done);
      replace the `[HU TBD]` placeholders in `hu.json` if hu is kept
- [ ] Review `db/seeds/challenges.json` (14 challenges) for anything gated behind unshipped levels
- [ ] Keep `.github/workflows/curriculum-content.yml` (weekly check against front-end@main) or
      reduce it to PR-only once content is frozen

## Remove Learn to Build (copy only)

### Onboarding drip

- [ ] Rewrite `config/locales/mailers/onboarding_mailer.en.yml` `overview` ("The Two Halves of
      Becoming a Developer", "Make stuff… Learn to Build", "both the coding and the building sides")
- [ ] Remove or replace the `building` email: `config/locales/mailers/onboarding_mailer.*.yml`
      `building.*`, `app/views/onboarding_mailer/building.{mjml,text.erb}`,
      `User::Notifications::OnboardingBuildingNotification`, the `building` entry in
      `OnboardingMailer::HEADER_IMAGES`, and day 3 in `User::Onboarding::CreateDueNotifications::EMAILS`
      (renumber or leave a gap; existing notifications are idempotent by kind)
- [ ] Rewrite `premium` drip bullets ("Premium Projects", "Learn to Build") — do this together with
      the pricing rewrite below, not twice
- [ ] Rewrite `community` YouTube line ("AMAs and other livestreams") if livestreams stop
- [ ] Drop `onboarding-building-*.jpg` from `scripts/upload_email_images.sh` and S3 if the email goes
- [ ] Update `test/mailers/onboarding_mailer_test.rb`, `test/commands/user/onboarding/*`, mailer
      previews, and `docs/i18n.md` line 45 mailer list if a mailer action is deleted

### Other mailers

- [ ] `config/locales/mailers/premium_mailer.en.yml` `welcome_to_premium`: "see you on a livestream
      soon" and "Thank you for subscribing"
- [ ] `config/locales/mailers/account_mailer.en.yml` `welcome`: "working on fun projects" (decide
      whether "projects" still reads fine as exercises)
- [ ] Propagate every change above to the 10 non-en copies (`bn el es-419 es-ES fr hu it pt-BR
      pt-PT uk`) — or blank the keys and let the translation pass rewrite them; the locale
      completeness workflow hard-fails on missing keys for production locales

## Change Premium to a one-off payment

### Decisions first (shared with the front-end list; recorded here for the API-specific angle)

- [ ] Base price and PPP scaling: the 103-row `PREMIUM_PRICES` table needs a single amount per
      currency; decide formula (e.g. scale from `annual`) before rewriting by hand
- [ ] Lifetime representation: (a) grant a non-expiring `PremiumEntitlement` with source `STRIPE`
      (constant already exists), or (b) a new `LIFETIME` source. Recommend (a); it makes
      `DowngradeToStandard` refuse to downgrade for free
- [ ] Whether `premium?` should be derived from active entitlements instead of `membership_type`
      (today `membership_type` is the source of truth and entitlements only block downgrade)
- [ ] Exercism Insider entitlement is revocable daily; decide if it stays revocable or becomes
      one-way like Bootcamp
- [ ] Ask Jiki cap for lifetime users, and whether the API should own a per-user counter
      (`assistant_conversations` has no usage columns) or leave it in the proxy
- [ ] Refund policy, and whether refunds revoke the entitlement (`charge.refunded` webhook)
- [ ] Whether `Payment` history (`internal/payments_controller.rb`, `SerializePayments`) stays

### Stripe integration

- [ ] Create one-off Stripe Prices (one product, multi-currency price or per-currency prices);
      replace `stripe_premium_monthly_price_id` / `stripe_premium_annual_price_id` in the config gem
      (`../config/settings/*.yml`, `../config/lib`) with a single `stripe_premium_lifetime_price_id`;
      include the config PR in the plan
- [ ] Rewrite `config/initializers/pricing.rb` `PREMIUM_PRICES` to `{ currency => amount }`; update
      `lib/tasks/stripe_currency_options.rake` for the new price
- [ ] `Stripe::CreateCheckoutSession`: `mode: 'payment'`, drop `subscription_data`, keep
      `ui_mode: 'elements'` and metadata
- [ ] Replace `Stripe::DetermineSubscriptionDetails` (interval → price id map) with a single-price
      lookup
- [ ] `Stripe::VerifyCheckoutSession`: verify `payment_status == 'paid'` / `payment_intent`, not
      `session.subscription`; drop interval/decline handling that assumed subscriptions; keep
      `StripeCheckoutSessionIncompleteError` (remove `interval` attribute)
- [ ] `Stripe::Webhook::HandleEvent`: route `checkout.session.completed` (payment mode) and
      `payment_intent.succeeded` / `charge.refunded`; delete `customer.subscription.*` and
      `invoice.payment_*` handlers (`subscription_created/updated/deleted`,
      `invoice_payment_succeeded/failed`)
- [ ] New grant path: on paid checkout → `User::PremiumEntitlement::Grant.(user, STRIPE)` +
      `Payment` row from the payment intent / charge (replace `CreatePaymentFromInvoice`)
- [ ] Delete `Stripe::UpdateSubscription`, `CancelSubscription`, `ReactivateSubscription`,
      `CreatePortalSession`, `SyncSubscriptionToUser`, `UpdateSubscriptionsFromInvoice`
- [ ] `Internal::SubscriptionsController`: keep `checkout_session` (no `interval` param) and
      `verify_checkout`; remove `portal_session`, `update`, `cancel`, `reactivate` and their routes
      (`config/routes.rb` subscriptions namespace); consider renaming to `purchases`
- [ ] `External::PricingController`: return a single `price` (+ currency, country_code)
- [ ] Remove `StripeSubscriptionCancellationError` from `config/initializers/exceptions.rb`; remove
      `existing_subscription`, `invalid_interval`, `cancel_failed`, `reactivate_failed`,
      `portal_failed` from `docs/api_error_types.md`
- [ ] `Dev::UsersController#clear_stripe_history` and `dev` routes: simplify or delete

### User data model

- [ ] `User::Data`: remove `subscription_status` enum and helpers (`monthly?`, `annual?`,
      `subscription_paid?`, `in_grace_period?`, `grace_period_ends_at`, `current_subscription`,
      `can_change_interval?`); `can_checkout?` becomes `!premium?`
- [ ] Migration: drop or leave dormant `stripe_subscription_id`, `stripe_subscription_status`,
      `subscription_interval` (NOT NULL default 'monthly'), `subscription_status`,
      `subscription_valid_until`, `subscriptions` jsonb; keep `stripe_customer_id`,
      `membership_type`, `welcome_to_premium_email_status`
- [ ] `User::DowngradeToStandard`: keep for admin/refund use only; remove subscription-lapse callers
- [ ] `User::PremiumEntitlement::Revoke`: drop the "skip downgrade if Stripe subscription still
      active" branch, replace with "skip if any other active entitlement"
- [ ] `User::UpgradeToPremium`: default analytics source and `welcome_to_premium` still fit
- [ ] `SerializeUser`: drop `subscription_status` and `subscription`; make `premium_prices` a single
      amount; coordinate with `front-end/types/auth.ts` and `tests/mocks/user.ts`
- [ ] Analytics (`app/commands/analytics/track_event.rb` callers): `checkout_started` loses
      plan/interval; remove `subscription_reactivated`, `subscription_cancelled` etc.

### Emails

- [ ] Delete `PremiumMailer#subscription_ended` + views + locale keys in all 11 files, or repurpose
      as `premium_revoked` for refunds
- [ ] Rewrite `welcome_to_premium` ("subscribing", livestream)
- [ ] Rewrite onboarding `premium` drip: bullets and the PPP "two takeaway drinks" line (per-month
      framing), keep the `next if user.premium?` skip
- [ ] Decide the `invoice_payment_failed` "TODO payment failed mailer" is now moot and delete the note
- [ ] `test/mailers/premium_mailer_test.rb`, `test/mailers/previews/premium_mailer_preview.rb`

### Migrate existing subscribers

- [ ] One-off script (rake task or Mandate command under `app/commands/stripe/`): for every user
      with `subscription_status` active/payment_failed/cancelling → grant lifetime entitlement,
      cancel the Stripe subscription immediately (no proration or per policy), append a closing
      `subscriptions` entry, send the announcement email
- [ ] Decide handling for `incomplete` and `canceled`-but-still-in-period users
- [ ] Add a one-off `PremiumMailer#converted_to_lifetime` (or send via `Mailshot::SendToSegment`)
      in kept locales
- [ ] Stripe dashboard: archive recurring prices, disable the customer portal config created by
      `CreatePortalSession`, update webhook endpoint event list
- [ ] Verify no recurring job or webhook can re-downgrade a converted user afterwards
      (`subscription_deleted` webhooks will arrive for every cancellation — handlers must be gone
      or no-ops before the script runs)

### Tests

- [ ] Rewrite/delete under `test/commands/stripe/**` (11 files) and
      `test/commands/stripe/webhook/**` (7 files), `test/controllers/internal/subscriptions_controller_test.rb`
      (824 lines), `test/controllers/webhooks/stripe_controller_test.rb`,
      `test/controllers/external/pricing_controller_test.rb`, `test/serializers/serialize_user_test.rb`,
      `test/models/user/data_test.rb`, `test/commands/user/{downgrade_to_standard,premium_entitlement/*}_test.rb`,
      `test/factories/{payments,premium_entitlements,user_data}.rb`

## Ask Jiki gating

- [ ] Decide free tier: keep "one lesson conversation ever" in
      `AssistantConversation::CheckUserAccess` or change; challenge chat stays premium-only via
      `require_premium!`
- [ ] If a per-user lifetime budget is chosen, decide whether the API stores the counter (new
      column on `user_data` or `assistant_conversations`) and exposes it in the JWT from
      `CreateConversationToken`, or the proxy's KV owns it
- [ ] Confirm `terraform/google/billing-cap.tf` against the new exposure (front-end list owns this;
      link only)

## Videos

- [ ] Nothing to do in the API for the welcome modal: `welcome_modal` is a generic
      `client:`-namespaced `user_flags` row. Optionally delete stale rows and swap the example key
      in `test/commands/user/flag/mark_test.rb` and `test/controllers/internal/flags_controller_test.rb`

## Freeze copy, then finish translations

Do every item above before this section. Locales here: `I18n::PRODUCTION_LOCALES` (11) must match
whatever the front-end settles on in `app/lib/locales.ts`; `ALL_LOCALES` (31) is the WIP pool.

- [ ] Prune `PRODUCTION_LOCALES` / `ALL_LOCALES` in `config/initializers/i18n.rb` to the kept set;
      delete orphaned `config/locales/mailers/*.{locale}.yml` and
      `db/seeds/level_translations/{locale}.json` for dropped locales (or keep WIP files, they only warn)
- [ ] Re-translate `onboarding_mailer` (rewritten drip), `premium_mailer` (rewritten), and
      `account_mailer` for every kept locale; note the non-en onboarding files are independent
      rewrites today, so decide whether they become faithful translations
- [ ] Level milestone emails: complete `db/seeds/level_translations/*.json` for kept locales
      (hu placeholders; any new level)
- [ ] Badge email copy: `badge_translations` via `Badge::Translation::TranslateToAllLocales` for
      kept locales (no live `badge_earned` call site per `docs/i18n.md`; decide whether to wire or drop)
- [ ] Locale-prefixed unsubscribe links in emails (`ApplicationMailer#unsubscribe_url`) — carried
      over from `front-end/i18n_TODO.md`
- [ ] `.github/workflows/locale-completeness.yml` and `test/i18n_parity_test.rb` stay as the gate;
      confirm they cover any new mailer

## Existing users and communication

- [ ] Send the subscriber conversion email (see migration section) via the new mailer or `Mailshot`
- [ ] Optional: a one-off `Mailshot::SendToSegment` announcing the finished course and Exercism as
      the next step to all confirmed users

## Freeze the stack and set a maintenance budget

- [ ] `config/recurring.yml`: keep `clear_solid_queue_finished_jobs`,
      `create_onboarding_notifications`; keep `sync_exercism_entitlements` only if Exercism
      entitlements still grant Premium
- [ ] `.github/workflows/`: decide on `claude-code-review.yml`, `claude.yml`, the weekly
      `curriculum-content.yml` cron, and dependency bots
- [ ] Sentry: quiet alert rules to what will be read; Ops Handler GitHub mirroring likewise
- [ ] Pin gems; decide the Rails / Stripe API version (`Stripe.api_version = "2026-05-27.dahlia"`)
      is the last one and note it
- [ ] Remove the dead `lesson_translations` table (no model) and `Lesson` translation migration
      remnants while the schema is being touched for subscription columns
- [ ] Write down the monthly run cost for this half (ECS, Aurora Serverless, SES, Solid Queue
      worker, Gemini translation calls) alongside the front-end's list

## Docs cleanup

- [ ] `CLAUDE.md` lines 24-25: "Subscriptions: Stripe for payments. Status tracked in User::Data
      with webhooks" → one-off purchase, entitlements
- [ ] `docs/api_error_types.md`: remove subscription-only error types (listed above)
- [ ] `docs/i18n.md`: mailer list (line 45) if `building` / `subscription_ended` are deleted
- [ ] Memory notes referencing subscription states, the stuckometer, or Learn to Build
