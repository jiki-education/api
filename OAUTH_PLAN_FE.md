# Google OAuth Implementation Plan - Frontend

## Overview
Add Google OAuth "Sign in with Google" button to the Jiki frontend, allowing users to authenticate using their Google accounts. This integrates with our existing JWT authentication system.

## Implementation Steps

### 1. Install Dependencies

**Command**:
```bash
cd ../fe
npm install @react-oauth/google
```

**Package**: `@react-oauth/google` - Official React library for Google OAuth

### 2. Get Google Client ID

**From API team**: Get the Google OAuth Client ID that was configured in Google Cloud Console and added to Rails credentials.

**File**: `../fe/.env.local` (for development)
```env
NEXT_PUBLIC_GOOGLE_CLIENT_ID=your_client_id_here.apps.googleusercontent.com
```

**File**: `../fe/.env.production` (for production)
```env
NEXT_PUBLIC_GOOGLE_CLIENT_ID=your_client_id_here.apps.googleusercontent.com
```

### 3. Add Google OAuth Provider

**File**: `../fe/app/layout.tsx` (or root layout/provider file)

Wrap your app with GoogleOAuthProvider:
```tsx
import { GoogleOAuthProvider } from '@react-oauth/google';

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <GoogleOAuthProvider clientId={process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID!}>
          {/* Your existing providers */}
          <QueryClientProvider client={queryClient}>
            <AuthProvider>
              {children}
            </AuthProvider>
          </QueryClientProvider>
        </GoogleOAuthProvider>
      </body>
    </html>
  );
}
```

### 4. Create Google Login Hook

**File**: `../fe/src/hooks/useGoogleAuth.ts` (or similar)

```tsx
import { useGoogleLogin } from '@react-oauth/google';
import { useMutation } from '@tanstack/react-query';
import { useAuthStore } from '@/stores/authStore';
import { apiClient } from '@/lib/api';

export const useGoogleAuth = () => {
  const { setAuth } = useAuthStore();

  const googleAuthMutation = useMutation({
    mutationFn: async (credential: string) => {
      const response = await apiClient.post('/auth/google', {
        token: credential
      });
      return response.data;
    },
    onSuccess: (data) => {
      // Extract tokens from response
      const accessToken = data.headers?.authorization?.replace('Bearer ', '');
      const { refresh_token, user } = data;

      // Store in auth store
      setAuth(accessToken, refresh_token, user);

      // Navigate to dashboard or home
      window.location.href = '/dashboard';
    },
    onError: (error: any) => {
      console.error('Google authentication failed:', error);

      // Show user-friendly error message
      const message = error.response?.data?.error?.message || 'Failed to sign in with Google';
      alert(message); // Replace with proper toast notification
    }
  });

  const handleGoogleLogin = useGoogleLogin({
    onSuccess: (tokenResponse) => {
      // Google returns credential (ID token)
      googleAuthMutation.mutate(tokenResponse.credential);
    },
    onError: (error) => {
      console.error('Google login error:', error);
      alert('Failed to authenticate with Google');
    },
    flow: 'implicit', // Use implicit flow for ID token
  });

  return {
    handleGoogleLogin,
    isLoading: googleAuthMutation.isPending,
    error: googleAuthMutation.error,
  };
};
```

### 5. Create Google Login Button Component

**File**: `../fe/src/components/auth/GoogleLoginButton.tsx`

```tsx
import { useGoogleAuth } from '@/hooks/useGoogleAuth';
import { Button } from '@/components/ui/button'; // Your button component

export const GoogleLoginButton = () => {
  const { handleGoogleLogin, isLoading } = useGoogleAuth();

  return (
    <Button
      onClick={() => handleGoogleLogin()}
      disabled={isLoading}
      variant="outline"
      className="w-full"
    >
      {isLoading ? (
        <>
          <Spinner className="mr-2" />
          Signing in...
        </>
      ) : (
        <>
          <GoogleIcon className="mr-2" />
          Continue with Google
        </>
      )}
    </Button>
  );
};

// Google Icon component
const GoogleIcon = ({ className }: { className?: string }) => (
  <svg
    className={className}
    width="18"
    height="18"
    viewBox="0 0 18 18"
    xmlns="http://www.w3.org/2000/svg"
  >
    <g fill="none" fillRule="evenodd">
      <path
        d="M17.64 9.205c0-.639-.057-1.252-.164-1.841H9v3.481h4.844a4.14 4.14 0 01-1.796 2.716v2.259h2.908c1.702-1.567 2.684-3.875 2.684-6.615z"
        fill="#4285F4"
      />
      <path
        d="M9 18c2.43 0 4.467-.806 5.956-2.18l-2.908-2.259c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 009 18z"
        fill="#34A853"
      />
      <path
        d="M3.964 10.71A5.41 5.41 0 013.682 9c0-.593.102-1.17.282-1.71V4.958H.957A8.996 8.996 0 000 9c0 1.452.348 2.827.957 4.042l3.007-2.332z"
        fill="#FBBC05"
      />
      <path
        d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 00.957 4.958L3.964 7.29C4.672 5.163 6.656 3.58 9 3.58z"
        fill="#EA4335"
      />
    </g>
  </svg>
);
```

### 6. Update Login Page

**File**: `../fe/src/app/login/page.tsx` (or your login page)

Add Google button to login form:
```tsx
import { GoogleLoginButton } from '@/components/auth/GoogleLoginButton';
import { LoginForm } from '@/components/auth/LoginForm';

export default function LoginPage() {
  return (
    <div className="auth-container">
      <h1>Sign in to Jiki</h1>

      {/* Google OAuth Button */}
      <GoogleLoginButton />

      {/* Divider */}
      <div className="divider">
        <span>OR</span>
      </div>

      {/* Traditional Email/Password Form */}
      <LoginForm />

      {/* Sign up link */}
      <p className="text-center mt-4">
        Don't have an account? <Link href="/signup">Sign up</Link>
      </p>
    </div>
  );
}
```

### 7. Update Signup Page

**File**: `../fe/src/app/signup/page.tsx` (or your signup page)

Add Google button to signup form:
```tsx
import { GoogleLoginButton } from '@/components/auth/GoogleLoginButton';
import { SignupForm } from '@/components/auth/SignupForm';

export default function SignupPage() {
  return (
    <div className="auth-container">
      <h1>Create your Jiki account</h1>

      {/* Google OAuth Button */}
      <GoogleLoginButton />

      {/* Divider */}
      <div className="divider">
        <span>OR</span>
      </div>

      {/* Traditional Email/Password Form */}
      <SignupForm />

      {/* Login link */}
      <p className="text-center mt-4">
        Already have an account? <Link href="/login">Sign in</Link>
      </p>
    </div>
  );
}
```

### 8. Update API Client

**File**: `../fe/src/lib/api.ts` (or wherever your API client is)

Ensure the API client is configured to handle OAuth responses correctly:
```tsx
import axios from 'axios';
import { useAuthStore } from '@/stores/authStore';

export const apiClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000',
  headers: {
    'Content-Type': 'application/json',
  },
});

// Response interceptor to extract tokens from OAuth responses
apiClient.interceptors.response.use(
  (response) => {
    // Extract access token from Authorization header
    const accessToken = response.headers.authorization?.replace('Bearer ', '');

    // If this is an auth response (login, signup, or OAuth)
    if (accessToken && response.data.user && response.data.refresh_token) {
      const { user, refresh_token } = response.data;
      useAuthStore.getState().setAuth(accessToken, refresh_token, user);
    }

    return response;
  },
  (error) => {
    // Your existing error handling
    return Promise.reject(error);
  }
);
```

### 9. Update Auth Store

**File**: `../fe/src/stores/authStore.ts` (or your auth state management)

Ensure the store handles OAuth user fields:
```tsx
interface User {
  id: number;
  handle: string;
  name: string;
  email: string;
  locale: string;
  provider?: string | null;          // ADD THIS
  email_verified?: boolean;          // ADD THIS
  created_at: string;
  updated_at: string;
}

// Your existing auth store implementation
```

### 10. Add User Profile OAuth Indicator

**File**: `../fe/src/components/profile/ProfileSettings.tsx` (or similar)

Show users how they're authenticated:
```tsx
export const ProfileSettings = () => {
  const { user } = useAuth();

  return (
    <div className="profile-settings">
      <h2>Account Settings</h2>

      <div className="auth-method">
        <label>Authentication Method</label>
        <div>
          {user.provider === 'google' ? (
            <div className="flex items-center">
              <GoogleIcon className="mr-2" />
              <span>Connected with Google</span>
            </div>
          ) : (
            <span>Email and Password</span>
          )}
        </div>
      </div>

      {/* Only show password change for non-OAuth users */}
      {!user.provider && (
        <div className="change-password">
          <Button onClick={() => setShowPasswordModal(true)}>
            Change Password
          </Button>
        </div>
      )}
    </div>
  );
};
```

### 11. Handle OAuth-Specific UX

**Considerations**:

1. **Password Reset**: Hide "Forgot Password?" link when user is signed in via Google
2. **Email Verification**: Skip email verification prompts for OAuth users
3. **Account Linking**: Show message when existing account is linked to Google
4. **Profile Completion**: For OAuth users, pre-fill name and email (but allow editing)

### 12. Error Handling

**File**: `../fe/src/lib/errors.ts`

Add OAuth-specific error handling:
```tsx
export const handleAuthError = (error: any) => {
  const errorType = error.response?.data?.error?.type;
  const errorMessage = error.response?.data?.error?.message;

  switch (errorType) {
    case 'invalid_token':
      return 'Google authentication failed. Please try again.';
    case 'validation_error':
      return 'Could not create account. Please try a different method.';
    case 'expired_token':
      return 'Google authentication expired. Please try again.';
    default:
      return errorMessage || 'Authentication failed. Please try again.';
  }
};
```

### 13. Testing

**Manual Testing Checklist**:
- [ ] Click "Sign in with Google" on login page
- [ ] Complete Google OAuth consent screen
- [ ] Verify redirected to dashboard with tokens stored
- [ ] Logout and login again with same Google account
- [ ] Create traditional email/password account with same email
- [ ] Login with Google using that email (account linking)
- [ ] Verify user profile shows "Connected with Google"
- [ ] Test on mobile device
- [ ] Test with popup blocked (fallback behavior)
- [ ] Test with slow network connection

**Unit Tests**: `../fe/src/hooks/useGoogleAuth.test.ts`
- Test successful Google authentication
- Test failed Google authentication
- Test network errors
- Test invalid token response

**Integration Tests**: `../fe/e2e/auth/google-oauth.spec.ts`
- Test full OAuth flow from button click to dashboard
- Test account linking scenario
- Test error states

### 14. Styling

**File**: `../fe/src/styles/auth.css` (or your styling approach)

Style the Google button to match Google's brand guidelines:
```css
.google-login-button {
  background: white;
  color: #3c4043;
  border: 1px solid #dadce0;
  font-family: 'Google Sans', 'Roboto', sans-serif;
  font-weight: 500;
  padding: 12px 24px;
  border-radius: 4px;
  transition: all 0.15s ease;
}

.google-login-button:hover {
  background: #f8f9fa;
  border-color: #dadce0;
  box-shadow: 0 1px 2px 0 rgba(60, 64, 67, 0.3),
              0 1px 3px 1px rgba(60, 64, 67, 0.15);
}

.google-login-button:active {
  background: #f1f3f4;
  box-shadow: 0 1px 2px 0 rgba(60, 64, 67, 0.3);
}

.divider {
  display: flex;
  align-items: center;
  text-align: center;
  margin: 24px 0;
  color: #5f6368;
  font-size: 14px;
}

.divider::before,
.divider::after {
  content: '';
  flex: 1;
  border-bottom: 1px solid #dadce0;
}

.divider span {
  padding: 0 16px;
}
```

### 15. Analytics

**File**: `../fe/src/lib/analytics.ts`

Track OAuth usage:
```tsx
export const trackGoogleLogin = (success: boolean) => {
  // Your analytics implementation (e.g., Google Analytics, Mixpanel)
  analytics.track('Google OAuth Login', {
    success,
    timestamp: new Date().toISOString(),
  });
};

export const trackAccountLinking = () => {
  analytics.track('Account Linked to Google');
};
```

Call these in the `useGoogleAuth` hook.

## Security Considerations

1. **HTTPS Only**: Always use HTTPS in production for OAuth flows
2. **Client ID Protection**: Keep Client ID in environment variables (it's not secret but should be configurable)
3. **Token Handling**: Never log or expose access tokens
4. **XSS Protection**: Sanitize all user input, especially name from Google profile
5. **CSRF Protection**: OAuth flow includes state parameter (handled by library)

## Browser Compatibility

The `@react-oauth/google` library supports:
- Chrome 60+
- Firefox 55+
- Safari 11+
- Edge 79+

For older browsers, show fallback message or traditional login only.

## Deployment Checklist

Before deploying to production:
- [ ] Update `NEXT_PUBLIC_GOOGLE_CLIENT_ID` in production environment
- [ ] Test on staging environment with real Google accounts
- [ ] Verify CORS configuration allows frontend domain
- [ ] Test on different browsers (Chrome, Firefox, Safari)
- [ ] Test on mobile devices (iOS Safari, Android Chrome)
- [ ] Set up error monitoring for OAuth failures
- [ ] Add analytics tracking for OAuth usage
- [ ] Update user documentation/help center

## Future Enhancements

- [ ] Add "One Tap" sign-in (Google's streamlined flow)
- [ ] Add "Auto Sign-In" for returning users
- [ ] Show multiple auth options (GitHub, Apple)
- [ ] Allow disconnecting Google from account
- [ ] Support linking multiple OAuth providers to same account
- [ ] Add OAuth token refresh for long-lived sessions

## Rollout Strategy

1. **Phase 1**: Deploy to development, test internally
2. **Phase 2**: Deploy to staging, test with beta users
3. **Phase 3**: Production soft launch (10% of users via feature flag)
4. **Phase 4**: Monitor metrics, fix issues
5. **Phase 5**: Full rollout to 100% of users
6. **Phase 6**: Marketing announcement

## Success Metrics

Track these metrics to measure OAuth adoption:
- % of new signups using Google OAuth
- % of logins using Google OAuth
- Time to complete signup (OAuth vs traditional)
- Account linking frequency
- OAuth error rate
- User satisfaction (survey/NPS)
