# Stripe Integration - Frontend Plan

This document outlines the implementation plan for Stripe subscription billing on the Jiki Frontend (React/Next.js).

## Overview

Based on Stripe's official React examples and 2025 best practices, this plan uses **Embedded Checkout** with the **EmbeddedCheckout** component for a seamless on-site payment experience.

**User Flows:**
1. **Pricing Page** - User selects Premium ($3) or Max ($10)
2. **Checkout Page** - Embedded Stripe payment form
3. **Completion Page** - Confirmation after payment
4. **Settings Page** - Manage subscription via Customer Portal
5. **Account Status** - Display subscription tier and status throughout app

## Architecture Overview

```
User Journey:
/pricing → /subscribe → /subscribe/complete → /settings/subscription

Components:
- PricingPage: Display tiers, trigger checkout
- SubscribePage: Embedded Checkout form
- SubscribeCompletePage: Success/error handling
- SubscriptionSettings: Manage via Customer Portal
- SubscriptionBanner: Grace period warnings
- SubscriptionBadge: Show tier throughout app
```

## Phase 1: Dependencies & Setup

### 1.1 Install Stripe Libraries
```bash
npm install @stripe/react-stripe-js @stripe/stripe-js
```

### 1.2 Environment Configuration

Add to `.env.local` (development):
```
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
NEXT_PUBLIC_API_BASE_URL=http://localhost:3060
```

Add to production environment:
```
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_...
NEXT_PUBLIC_API_BASE_URL=https://api.jiki.io
```

### 1.3 Stripe Initialization

Create `lib/stripe.ts`:
```typescript
import { loadStripe } from '@stripe/stripe-js';

export const stripePromise = loadStripe(
  process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!
);
```

## Phase 2: API Client Functions

Create `lib/api/subscriptions.ts`:

```typescript
const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL;

export interface SubscriptionStatus {
  tier: 'standard' | 'premium' | 'max';
  status: string;
  current_period_end: string | null;
  payment_failed: boolean;
  in_grace_period: boolean;
  grace_period_ends_at: string | null;
}

export async function createCheckoutSession(
  priceId: string,
  authToken: string
): Promise<{ clientSecret: string }> {
  const response = await fetch(`${API_BASE}/internal/subscriptions/checkout_session`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${authToken}`,
    },
    body: JSON.stringify({ price_id: priceId }),
  });

  if (!response.ok) {
    throw new Error('Failed to create checkout session');
  }

  return response.json();
}

export async function createPortalSession(
  authToken: string
): Promise<{ url: string }> {
  const response = await fetch(`${API_BASE}/internal/subscriptions/portal_session`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${authToken}`,
    },
  });

  if (!response.ok) {
    throw new Error('Failed to create portal session');
  }

  return response.json();
}

export async function getSubscriptionStatus(
  authToken: string
): Promise<{ subscription: SubscriptionStatus }> {
  const response = await fetch(`${API_BASE}/internal/subscriptions/status`, {
    headers: {
      'Authorization': `Bearer ${authToken}`,
    },
  });

  if (!response.ok) {
    throw new Error('Failed to fetch subscription status');
  }

  return response.json();
}
```

## Phase 3: Pricing Configuration

Create `lib/pricing.ts`:

```typescript
export interface PricingTier {
  id: 'standard' | 'premium' | 'max';
  name: string;
  price: number; // in dollars
  priceId: string; // Stripe price ID
  features: string[];
  popular?: boolean;
}

export const PRICING_TIERS: PricingTier[] = [
  {
    id: 'standard',
    name: 'Standard',
    price: 0,
    priceId: '', // Not needed for free tier
    features: [
      'Access to all lessons',
      'Code exercises',
      'Basic support',
    ],
  },
  {
    id: 'premium',
    name: 'Premium',
    price: 3,
    priceId: process.env.NEXT_PUBLIC_STRIPE_PREMIUM_PRICE_ID!,
    features: [
      'Everything in Standard',
      'Premium video content',
      'Priority support',
      'Certificate of completion',
    ],
    popular: true,
  },
  {
    id: 'max',
    name: 'Max',
    price: 10,
    priceId: process.env.NEXT_PUBLIC_STRIPE_MAX_PRICE_ID!,
    features: [
      'Everything in Premium',
      'AI-powered code reviews',
      '1-on-1 mentorship sessions',
      'Exclusive community access',
      'Early access to new content',
    ],
  },
];

export function getTier(tierId: string): PricingTier | undefined {
  return PRICING_TIERS.find(tier => tier.id === tierId);
}
```

## Phase 4: Pricing Page Component

Create `app/pricing/page.tsx`:

```tsx
'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/hooks/useAuth'; // Your auth hook
import { PRICING_TIERS } from '@/lib/pricing';
import { createCheckoutSession } from '@/lib/api/subscriptions';

export default function PricingPage() {
  const router = useRouter();
  const { user, token } = useAuth();
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleSelectTier = async (priceId: string, tierId: string) => {
    if (!user) {
      // Redirect to login, then back to pricing
      router.push(`/auth/login?redirect=/pricing`);
      return;
    }

    if (tierId === 'standard') {
      // Already on free tier or downgrade via portal
      router.push('/settings/subscription');
      return;
    }

    setLoading(tierId);
    setError(null);

    try {
      const { clientSecret } = await createCheckoutSession(priceId, token);

      // Store client secret and navigate to checkout
      sessionStorage.setItem('stripe_checkout_secret', clientSecret);
      router.push('/subscribe');
    } catch (err) {
      setError('Failed to start checkout. Please try again.');
      console.error(err);
    } finally {
      setLoading(null);
    }
  };

  return (
    <div className="pricing-page">
      <div className="header">
        <h1>Choose Your Plan</h1>
        <p>Upgrade anytime. Cancel anytime. No hidden fees.</p>
      </div>

      {error && (
        <div className="error-banner" role="alert">
          {error}
        </div>
      )}

      <div className="pricing-tiers">
        {PRICING_TIERS.map((tier) => (
          <div
            key={tier.id}
            className={`pricing-card ${tier.popular ? 'popular' : ''}`}
          >
            {tier.popular && <div className="badge">Most Popular</div>}

            <h2>{tier.name}</h2>
            <div className="price">
              <span className="amount">${tier.price}</span>
              {tier.price > 0 && <span className="period">/month</span>}
            </div>

            <ul className="features">
              {tier.features.map((feature, index) => (
                <li key={index}>{feature}</li>
              ))}
            </ul>

            <button
              onClick={() => handleSelectTier(tier.priceId, tier.id)}
              disabled={loading === tier.id}
              className={tier.popular ? 'btn-primary' : 'btn-secondary'}
            >
              {loading === tier.id ? 'Loading...' :
               tier.price === 0 ? 'Current Plan' : 'Subscribe'}
            </button>
          </div>
        ))}
      </div>

      <div className="faq">
        <h3>Frequently Asked Questions</h3>
        {/* Add FAQ items */}
      </div>
    </div>
  );
}
```

## Phase 5: Subscribe Page (Embedded Checkout)

Create `app/subscribe/page.tsx`:

```tsx
'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { EmbeddedCheckoutProvider, EmbeddedCheckout } from '@stripe/react-stripe-js';
import { stripePromise } from '@/lib/stripe';

export default function SubscribePage() {
  const router = useRouter();
  const [clientSecret, setClientSecret] = useState<string | null>(null);

  useEffect(() => {
    // Retrieve client secret from session storage
    const secret = sessionStorage.getItem('stripe_checkout_secret');

    if (!secret) {
      // No checkout session, redirect to pricing
      router.push('/pricing');
      return;
    }

    setClientSecret(secret);
  }, [router]);

  if (!clientSecret) {
    return (
      <div className="subscribe-loading">
        <p>Loading checkout...</p>
      </div>
    );
  }

  return (
    <div className="subscribe-page">
      <div className="checkout-container">
        <EmbeddedCheckoutProvider
          stripe={stripePromise}
          options={{ clientSecret }}
        >
          <EmbeddedCheckout />
        </EmbeddedCheckoutProvider>
      </div>

      <div className="checkout-sidebar">
        <h3>Secure Checkout</h3>
        <ul className="security-features">
          <li>🔒 Encrypted payment processing</li>
          <li>💳 No card details stored on our servers</li>
          <li>✅ Cancel anytime</li>
        </ul>
      </div>
    </div>
  );
}
```

## Phase 6: Completion Page

Create `app/subscribe/complete/page.tsx`:

```tsx
'use client';

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useAuth } from '@/hooks/useAuth';

export default function SubscribeCompletePage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { refreshUser } = useAuth();
  const [status, setStatus] = useState<'loading' | 'success' | 'error'>('loading');

  useEffect(() => {
    const sessionId = searchParams.get('session_id');

    if (!sessionId) {
      setStatus('error');
      return;
    }

    // Clear the stored client secret
    sessionStorage.removeItem('stripe_checkout_secret');

    // Wait a moment for webhook to process, then refresh user data
    setTimeout(async () => {
      try {
        await refreshUser(); // Refresh to get updated membership tier
        setStatus('success');
      } catch (err) {
        console.error('Failed to refresh user:', err);
        setStatus('success'); // Still show success, webhook will process
      }
    }, 2000);
  }, [searchParams, refreshUser]);

  if (status === 'loading') {
    return (
      <div className="completion-loading">
        <div className="spinner" />
        <h2>Processing your subscription...</h2>
        <p>Please wait while we confirm your payment.</p>
      </div>
    );
  }

  if (status === 'error') {
    return (
      <div className="completion-error">
        <h2>Something went wrong</h2>
        <p>We couldn't complete your subscription. Please contact support.</p>
        <button onClick={() => router.push('/pricing')}>
          Back to Pricing
        </button>
      </div>
    );
  }

  return (
    <div className="completion-success">
      <div className="success-icon">✓</div>
      <h1>Welcome to Premium!</h1>
      <p>Your subscription is now active. You have access to all premium features.</p>

      <div className="next-steps">
        <h3>What's next?</h3>
        <ul>
          <li>Access premium video content</li>
          <li>Get priority support</li>
          <li>Earn your certificate</li>
        </ul>
      </div>

      <div className="actions">
        <button
          onClick={() => router.push('/lessons')}
          className="btn-primary"
        >
          Start Learning
        </button>
        <button
          onClick={() => router.push('/settings/subscription')}
          className="btn-secondary"
        >
          Manage Subscription
        </button>
      </div>
    </div>
  );
}
```

## Phase 7: Subscription Settings Page

Create `app/settings/subscription/page.tsx`:

```tsx
'use client';

import { useState, useEffect } from 'react';
import { useAuth } from '@/hooks/useAuth';
import { getTier } from '@/lib/pricing';
import {
  getSubscriptionStatus,
  createPortalSession,
  type SubscriptionStatus
} from '@/lib/api/subscriptions';

export default function SubscriptionSettingsPage() {
  const { token, user } = useAuth();
  const [subscription, setSubscription] = useState<SubscriptionStatus | null>(null);
  const [loading, setLoading] = useState(true);
  const [portalLoading, setPortalLoading] = useState(false);

  useEffect(() => {
    async function loadSubscription() {
      try {
        const { subscription: status } = await getSubscriptionStatus(token);
        setSubscription(status);
      } catch (err) {
        console.error('Failed to load subscription:', err);
      } finally {
        setLoading(false);
      }
    }

    loadSubscription();
  }, [token]);

  const handleManageSubscription = async () => {
    setPortalLoading(true);
    try {
      const { url } = await createPortalSession(token);
      window.location.href = url; // Redirect to Stripe Customer Portal
    } catch (err) {
      console.error('Failed to open portal:', err);
      alert('Failed to open subscription management. Please try again.');
    } finally {
      setPortalLoading(false);
    }
  };

  if (loading) {
    return <div>Loading subscription...</div>;
  }

  if (!subscription) {
    return <div>Failed to load subscription status.</div>;
  }

  const currentTier = getTier(subscription.tier);

  return (
    <div className="subscription-settings">
      <h1>Subscription</h1>

      <div className="current-plan">
        <h2>Current Plan</h2>
        <div className="plan-card">
          <div className="plan-header">
            <h3>{currentTier?.name}</h3>
            <span className="price">
              {currentTier?.price === 0 ? 'Free' : `$${currentTier?.price}/month`}
            </span>
          </div>

          {subscription.tier !== 'standard' && (
            <div className="plan-details">
              <p>
                <strong>Status:</strong>{' '}
                <span className={`status ${subscription.status}`}>
                  {subscription.status}
                </span>
              </p>

              {subscription.current_period_end && (
                <p>
                  <strong>Renews on:</strong>{' '}
                  {new Date(subscription.current_period_end).toLocaleDateString()}
                </p>
              )}

              {subscription.in_grace_period && (
                <div className="grace-period-warning" role="alert">
                  <strong>Payment Failed</strong>
                  <p>
                    Your subscription will be cancelled on{' '}
                    {new Date(subscription.grace_period_ends_at!).toLocaleDateString()}
                    {' '}unless payment is successful.
                  </p>
                </div>
              )}
            </div>
          )}
        </div>

        {subscription.tier === 'standard' && (
          <a href="/pricing" className="btn-primary">
            Upgrade Plan
          </a>
        )}

        {subscription.tier !== 'standard' && (
          <button
            onClick={handleManageSubscription}
            disabled={portalLoading}
            className="btn-secondary"
          >
            {portalLoading ? 'Loading...' : 'Manage Subscription'}
          </button>
        )}
      </div>

      <div className="billing-info">
        <h2>Billing Information</h2>
        <p>
          Manage your payment methods, billing history, and invoices through
          the Stripe Customer Portal.
        </p>
        {subscription.tier !== 'standard' && (
          <button
            onClick={handleManageSubscription}
            disabled={portalLoading}
            className="btn-secondary"
          >
            View Billing Details
          </button>
        )}
      </div>
    </div>
  );
}
```

## Phase 8: Subscription Status Components

### 8.1 Subscription Badge Component

Create `components/SubscriptionBadge.tsx`:

```tsx
'use client';

import { useAuth } from '@/hooks/useAuth';

export function SubscriptionBadge() {
  const { user } = useAuth();

  if (!user || user.membership_type === 'standard') {
    return null;
  }

  const badgeColors = {
    premium: 'bg-blue-500',
    max: 'bg-purple-600',
  };

  const badgeColor = badgeColors[user.membership_type as 'premium' | 'max'];

  return (
    <span className={`badge ${badgeColor}`}>
      {user.membership_type}
    </span>
  );
}
```

### 8.2 Grace Period Banner Component

Create `components/GracePeriodBanner.tsx`:

```tsx
'use client';

import { useEffect, useState } from 'react';
import { useAuth } from '@/hooks/useAuth';
import { getSubscriptionStatus } from '@/lib/api/subscriptions';
import { useRouter } from 'next/navigation';

export function GracePeriodBanner() {
  const { token, user } = useAuth();
  const router = useRouter();
  const [inGracePeriod, setInGracePeriod] = useState(false);
  const [gracePeriodEnd, setGracePeriodEnd] = useState<string | null>(null);

  useEffect(() => {
    if (!user || user.membership_type === 'standard') {
      return;
    }

    async function checkStatus() {
      try {
        const { subscription } = await getSubscriptionStatus(token);
        setInGracePeriod(subscription.in_grace_period);
        setGracePeriodEnd(subscription.grace_period_ends_at);
      } catch (err) {
        console.error('Failed to check subscription status:', err);
      }
    }

    checkStatus();
  }, [user, token]);

  if (!inGracePeriod) {
    return null;
  }

  return (
    <div className="grace-period-banner" role="alert">
      <div className="banner-content">
        <strong>⚠️ Payment Issue</strong>
        <p>
          Your payment failed. Please update your payment method by{' '}
          {gracePeriodEnd && new Date(gracePeriodEnd).toLocaleDateString()}
          {' '}to keep your subscription active.
        </p>
      </div>
      <button
        onClick={() => router.push('/settings/subscription')}
        className="btn-warning"
      >
        Update Payment
      </button>
    </div>
  );
}
```

### 8.3 Feature Gate Component

Create `components/FeatureGate.tsx`:

```tsx
'use client';

import { ReactNode } from 'react';
import { useAuth } from '@/hooks/useAuth';
import { useRouter } from 'next/navigation';

interface FeatureGateProps {
  requiredTier: 'premium' | 'max';
  children: ReactNode;
  fallback?: ReactNode;
}

export function FeatureGate({ requiredTier, children, fallback }: FeatureGateProps) {
  const { user } = useAuth();
  const router = useRouter();

  const hasAccess = () => {
    if (!user) return false;
    if (requiredTier === 'premium') {
      return user.membership_type === 'premium' || user.membership_type === 'max';
    }
    if (requiredTier === 'max') {
      return user.membership_type === 'max';
    }
    return false;
  };

  if (hasAccess()) {
    return <>{children}</>;
  }

  if (fallback) {
    return <>{fallback}</>;
  }

  return (
    <div className="feature-locked">
      <h3>🔒 Premium Feature</h3>
      <p>This feature requires a {requiredTier} subscription.</p>
      <button
        onClick={() => router.push('/pricing')}
        className="btn-primary"
      >
        Upgrade to {requiredTier}
      </button>
    </div>
  );
}

// Usage example:
// <FeatureGate requiredTier="premium">
//   <PremiumVideoPlayer />
// </FeatureGate>
```

## Phase 9: Layout Integration

Update `app/layout.tsx` to include the grace period banner:

```tsx
import { GracePeriodBanner } from '@/components/GracePeriodBanner';

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <Header />
        <GracePeriodBanner />
        <main>{children}</main>
        <Footer />
      </body>
    </html>
  );
}
```

Update navigation to include subscription badge:

```tsx
import { SubscriptionBadge } from '@/components/SubscriptionBadge';

export function UserMenu() {
  return (
    <div className="user-menu">
      <Avatar />
      <span>{user.name}</span>
      <SubscriptionBadge />
    </div>
  );
}
```

## Phase 10: TypeScript Types

Create `types/subscription.ts`:

```typescript
export type MembershipTier = 'standard' | 'premium' | 'max';

export type SubscriptionStatus =
  | 'active'
  | 'past_due'
  | 'canceled'
  | 'unpaid'
  | 'trialing'
  | 'incomplete';

export interface User {
  id: string;
  email: string;
  name: string;
  membership_type: MembershipTier;
  // ... other user fields
}

export interface SubscriptionDetails {
  tier: MembershipTier;
  status: SubscriptionStatus;
  current_period_end: string | null;
  payment_failed: boolean;
  in_grace_period: boolean;
  grace_period_ends_at: string | null;
}
```

## Phase 11: Error States & Edge Cases

### 11.1 Handle Common Errors

Create `components/SubscriptionError.tsx`:

```tsx
interface SubscriptionErrorProps {
  error: 'already_subscribed' | 'invalid_tier' | 'payment_failed' | 'network_error';
  onRetry?: () => void;
}

export function SubscriptionError({ error, onRetry }: SubscriptionErrorProps) {
  const messages = {
    already_subscribed: {
      title: 'Already Subscribed',
      message: 'You already have an active subscription. Visit settings to manage it.',
      action: 'Go to Settings',
      href: '/settings/subscription',
    },
    invalid_tier: {
      title: 'Invalid Plan',
      message: 'The selected plan is not available.',
      action: 'View Plans',
      href: '/pricing',
    },
    payment_failed: {
      title: 'Payment Failed',
      message: 'Your payment could not be processed. Please try again or use a different payment method.',
      action: 'Retry',
      onClick: onRetry,
    },
    network_error: {
      title: 'Connection Error',
      message: 'Could not connect to the server. Please check your internet connection.',
      action: 'Retry',
      onClick: onRetry,
    },
  };

  const config = messages[error];

  return (
    <div className="subscription-error">
      <h2>{config.title}</h2>
      <p>{config.message}</p>
      {config.href ? (
        <a href={config.href} className="btn-primary">
          {config.action}
        </a>
      ) : (
        <button onClick={config.onClick} className="btn-primary">
          {config.action}
        </button>
      )}
    </div>
  );
}
```

### 11.2 Loading States

Ensure all async operations show loading indicators:
- Checkout session creation
- Portal session creation
- Subscription status fetching
- Completion page processing

### 11.3 Navigation Guards

Protect routes that require authentication:
- `/subscribe` - Must have active checkout session
- `/subscribe/complete` - Must have session_id in URL
- `/settings/subscription` - Must be authenticated

## Phase 12: Analytics & Tracking (Optional)

Add analytics events for:
- Viewed pricing page
- Selected plan
- Started checkout
- Completed subscription
- Upgraded plan
- Downgraded plan
- Cancelled subscription

## Phase 13: Mobile Responsiveness

Ensure all components are mobile-friendly:
- Pricing cards stack on mobile
- Embedded checkout is responsive (Stripe handles this)
- Settings page adapts to small screens
- Banners don't obstruct content

## Phase 14: Testing Checklist

### Manual Testing Flow
- [ ] View pricing page (logged out)
- [ ] Click subscribe → redirected to login
- [ ] Login and return to pricing
- [ ] Select Premium plan
- [ ] Complete checkout with test card `4242424242424242`
- [ ] Verify redirect to completion page
- [ ] Verify subscription shows as active in settings
- [ ] Open Customer Portal
- [ ] Upgrade to Max plan via portal
- [ ] Downgrade to Premium via portal
- [ ] Cancel subscription via portal
- [ ] Test failed payment with card `4000000000000341`
- [ ] Verify grace period banner appears
- [ ] Test SCA card `4000002500003155`

### Test Cards (from Stripe docs)
- Success: `4242424242424242`
- Requires SCA: `4000002500003155`
- Declined: `4000000000000002`
- Payment fails: `4000000000000341`

## Phase 15: Accessibility

Ensure WCAG 2.1 AA compliance:
- [ ] All interactive elements keyboard accessible
- [ ] ARIA labels on status indicators
- [ ] Error messages in `role="alert"`
- [ ] Color contrast meets standards
- [ ] Screen reader tested

## Phase 16: Performance Optimization

- [ ] Lazy load Stripe.js only on checkout page
- [ ] Memoize pricing configuration
- [ ] Optimize images in pricing cards
- [ ] Preload critical fonts
- [ ] Add loading skeletons for async content

## Phase 17: Documentation

### For Developers
- Add Stripe setup instructions to README
- Document environment variables
- Add testing guide with Stripe test cards
- Document webhook testing with Stripe CLI

### For Users
- Add FAQ section to pricing page
- Create help docs for subscription management
- Add tooltips for subscription status

## Out of Scope (Future Enhancements)

- Annual billing toggle
- Promo code entry
- Gift subscriptions
- Team/family plans
- Usage analytics dashboard
- A/B testing pricing
- Localized pricing (PPP)
- Invoice customization
- Multiple payment methods
- Trial period countdown

## Dependencies on API

This frontend implementation depends on:
1. API endpoints: `/internal/subscriptions/*` and `/webhooks/stripe`
2. User object includes `membership_type` field in JWT
3. Auth token refresh after subscription changes
4. CORS configured to allow frontend domain

## Deployment Checklist

Before deploying:
- [ ] Add production Stripe publishable key to env
- [ ] Add production price IDs to env
- [ ] Test complete flow in staging
- [ ] Verify webhook delivery in Stripe Dashboard
- [ ] Test on multiple browsers (Chrome, Safari, Firefox)
- [ ] Test on mobile devices (iOS, Android)
- [ ] Set up error monitoring (Sentry, etc.)
- [ ] Configure analytics events
