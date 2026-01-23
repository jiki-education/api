# Plan: Add User Tier Change Commands

## Goal

Create `User::UpgradeToPremium`, `User::UpgradeToMax`, and `User::DowngradeToStandard` commands that encapsulate tier change logic, enabling side effects like emails.

## Implementation Checklist

### Mailer Setup
- [x] Create UserMailer with `welcome_to_premium`, `welcome_to_max`, and `subscription_ended` methods
- [x] Create MJML templates for each email
- [x] Create text templates for each email
- [x] Add i18n strings for all email content

### Commands
- [x] Create `User::UpgradeToPremium` command
- [x] Create `User::UpgradeToMax` command
- [x] Create `User::DowngradeToStandard` command

### Integration
- [x] Update `Stripe::SyncSubscriptionToUser` to use new commands
- [x] Update `Stripe::Webhook::SubscriptionUpdated` to use new commands
- [x] Update `Stripe::Webhook::SubscriptionDeleted` to use new commands
- [x] Update `Stripe::UpdateSubscription` to use new commands

### Tests
- [x] Create `User::UpgradeToPremium` tests
- [x] Create `User::UpgradeToMax` tests
- [x] Create `User::DowngradeToStandard` tests
- [x] Create UserMailer tests

### Verification
- [x] Run full test suite (1803 runs, 0 failures, 0 errors)
- [x] Run linting (no offenses detected)
