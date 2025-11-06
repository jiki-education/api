# Stripe Upgrade/Downgrade Implementation Plan - Frontend

## Overview

Update the frontend to support upgrading and downgrading subscription tiers for users who already have an active subscription.

## User Experience

### Current Flow (New Subscriptions)
- User on Standard tier clicks "Upgrade to Premium" or "Upgrade to Max"
- Frontend creates checkout session via API
- User completes payment in Stripe checkout UI
- User returned to app with updated tier

### New Flow (Tier Changes)

#### Upgrade (Premium → Max)
1. User clicks "Upgrade to Max"
2. Frontend calls `POST /internal/subscriptions/update` with `{"product": "max"}`
3. **Immediate change** - user's tier updates right away with prorated charge
4. Show success message: "You've been upgraded to Max! Your card will be charged the prorated amount."
5. Refresh user data to show new tier

#### Downgrade (Max → Premium)
1. User clicks "Downgrade to Premium"
2. Frontend shows confirmation: "Your plan will change to Premium at the end of your billing period (MMM DD, YYYY). You'll continue to have Max access until then."
3. User confirms
4. Frontend calls `POST /internal/subscriptions/update` with `{"product": "premium"}`
5. **Scheduled change** - user keeps current tier until period end
6. Show success message: "Your plan will change to Premium on [date]. You'll keep Max access until then."
7. Display pending change status in subscription UI

## API Changes

### New Endpoint: Update Subscription

**Endpoint**: `POST /internal/subscriptions/update`

**Request**:
```typescript
{
  product: 'premium' | 'max'
}
```

**Success Response** (200):
```typescript
{
  success: true,
  tier: 'premium' | 'max',
  effective_at: 'immediate' | Date // ISO 8601 string for scheduled changes
}
```

**Error Responses**:

- **400 - Invalid Product**:
```typescript
{
  error: {
    type: 'invalid_product',
    message: 'Invalid product. Must be \'premium\' or \'max\''
  }
}
```

- **400 - No Subscription**:
```typescript
{
  error: {
    type: 'no_subscription',
    message: 'You don\'t have an active subscription. Use checkout to create one.'
  }
}
```

- **400 - Same Tier**:
```typescript
{
  error: {
    type: 'same_tier',
    message: 'You are already subscribed to premium'
  }
}
```

- **500 - Update Failed**:
```typescript
{
  error: {
    type: 'update_failed',
    message: 'Failed to update subscription'
  }
}
```

### Updated Endpoint: Create Checkout Session

**Endpoint**: `POST /internal/subscriptions/checkout_session`

**New Error Response** (400 - Existing Subscription):
```typescript
{
  error: {
    type: 'existing_subscription',
    message: 'You already have an active subscription. Use the update endpoint to change tiers.'
  }
}
```

**Frontend Handling**: If this error is received, redirect user to subscription management page instead of showing checkout.

## Implementation Tasks

### 1. Add API Client Method

**Location**: API client file (e.g., `api/subscriptions.ts`)

```typescript
export async function updateSubscription(product: 'premium' | 'max') {
  const response = await fetch('/internal/subscriptions/update', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({ product })
  });

  if (!response.ok) {
    const error = await response.json();
    throw new SubscriptionError(error.error.type, error.error.message);
  }

  return response.json();
}
```

### 2. Update Subscription Management UI

**Location**: Settings/Subscription page component

Add logic to determine if user should:
- Use checkout flow (no subscription or standard tier)
- Use update flow (has premium/max subscription)

```typescript
const handleTierChange = async (newTier: 'premium' | 'max') => {
  const currentTier = user.subscription.tier;

  // Standard tier users use checkout
  if (currentTier === 'standard') {
    return handleCheckout(newTier);
  }

  // Users with active subscription use update
  if (currentTier === newTier) {
    // Should be disabled in UI, but handle gracefully
    showError('You are already on this plan');
    return;
  }

  const isDowngrade = tierValue(newTier) < tierValue(currentTier);

  // Show confirmation for downgrades
  if (isDowngrade) {
    const confirmed = await showDowngradeConfirmation(newTier);
    if (!confirmed) return;
  }

  try {
    const result = await updateSubscription(newTier);

    if (result.effective_at === 'immediate') {
      showSuccess(`Upgraded to ${newTier}! Your card has been charged the prorated amount.`);
      await refreshUser(); // Refresh to show new tier
    } else {
      showSuccess(`Your plan will change to ${newTier} on ${formatDate(result.effective_at)}. You'll keep ${currentTier} access until then.`);
      // Show pending change indicator
      setPendingTierChange({ tier: newTier, effectiveAt: result.effective_at });
    }
  } catch (error) {
    if (error.type === 'no_subscription') {
      // Fallback to checkout
      handleCheckout(newTier);
    } else {
      showError(error.message);
    }
  }
};
```

### 3. Update Checkout Flow Error Handling

**Location**: Checkout component

```typescript
try {
  const session = await createCheckoutSession(product, returnUrl);
  // ... existing checkout flow
} catch (error) {
  if (error.type === 'existing_subscription') {
    // Redirect to subscription management
    router.push('/settings/subscription');
    showError('You already have a subscription. Manage it in your settings.');
  } else {
    showError(error.message);
  }
}
```

### 4. Display Pending Tier Changes

**Location**: Subscription status component

```typescript
{user.subscription.tier === 'max' && pendingTierChange?.tier === 'premium' && (
  <Alert variant="info">
    Your plan will change to Premium on {formatDate(pendingTierChange.effectiveAt)}.
    You'll keep Max access until then.
    <Button onClick={openCustomerPortal}>Manage Subscription</Button>
  </Alert>
)}
```

### 5. Add Downgrade Confirmation Dialog

**Location**: New modal/dialog component

```typescript
const DowngradeConfirmationDialog = ({ currentTier, newTier, periodEnd, onConfirm, onCancel }) => (
  <Dialog>
    <DialogTitle>Confirm Plan Change</DialogTitle>
    <DialogContent>
      <p>Your plan will change from {currentTier} to {newTier} at the end of your billing period.</p>
      <p><strong>Effective Date:</strong> {formatDate(periodEnd)}</p>
      <p>You'll continue to have {currentTier} access until then.</p>
      <p>After {formatDate(periodEnd)}, you'll lose access to {currentTier}-only features.</p>
    </DialogContent>
    <DialogActions>
      <Button onClick={onCancel}>Cancel</Button>
      <Button onClick={onConfirm} variant="primary">Confirm Change</Button>
    </DialogActions>
  </Dialog>
);
```

## UI/UX Considerations

### Subscription Management Page Layout

**For Standard Tier Users**:
```
Current Plan: Standard (Free)

Available Plans:
┌─────────────┐  ┌─────────────┐
│  Premium    │  │     Max     │
│   $X/mo     │  │   $Y/mo     │
│             │  │             │
│ [Upgrade]   │  │ [Upgrade]   │
└─────────────┘  └─────────────┘
```

**For Premium Users**:
```
Current Plan: Premium ($X/mo)
Next billing: MMM DD, YYYY

Available Plans:
┌─────────────┐  ┌─────────────┐
│  Standard   │  │     Max     │
│    Free     │  │   $Y/mo     │
│             │  │             │
│ [Downgrade] │  │ [Upgrade]   │
└─────────────┘  └─────────────┘

[Manage Subscription] (link to Stripe portal)
```

**For Max Users with Pending Downgrade**:
```
Current Plan: Max ($Y/mo)
⚠️ Your plan will change to Premium on MMM DD, YYYY

Next billing: MMM DD, YYYY

Available Plans:
┌─────────────┐  ┌─────────────┐
│  Standard   │  │   Premium   │
│    Free     │  │   $X/mo     │
│             │  │  (Pending)  │
│ [Downgrade] │  │             │
└─────────────┘  └─────────────┘

[Cancel Scheduled Change] (link to Stripe portal)
```

## Button States

- **Same as current tier**: Disabled, show "Current Plan"
- **Upgrade available**: Enabled, "Upgrade to [Tier]"
- **Downgrade available**: Enabled, "Downgrade to [Tier]"
- **Pending change**: Disabled, show "(Pending)" or "(Scheduled)"

## Error Handling

1. **Network errors**: Show generic error, allow retry
2. **Same tier error**: Shouldn't happen (button disabled), but show friendly message
3. **No subscription error**: Fallback to checkout flow automatically
4. **Stripe API errors**: Show "Unable to update subscription. Please try again or contact support."

## Testing Checklist

- [ ] Standard user can upgrade to Premium via checkout
- [ ] Standard user can upgrade to Max via checkout
- [ ] Premium user can upgrade to Max (immediate)
- [ ] Max user can downgrade to Premium (scheduled)
- [ ] Premium user cannot "upgrade" to Premium (button disabled)
- [ ] Pending downgrade shows correct effective date
- [ ] User with existing subscription cannot create checkout session
- [ ] Error handling for all API error types
- [ ] Downgrade confirmation dialog works correctly
- [ ] Customer Portal link works for all subscription states

## Future Enhancements

- Show prorated amount before confirming upgrade
- Allow canceling pending tier changes (via Customer Portal or custom endpoint)
- Show detailed billing history
- Support for annual billing cycles
- Promotional pricing display
