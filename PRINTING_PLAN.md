# PDF Printing Plan

## Overview

Generate PDFs from React-rendered pages via a Cloudflare Worker running headless Chrome. The React app already contains all the rendering logic, so we let it render a print-friendly page and use the CF Worker purely as a "URL to PDF" converter.

## Architecture

```
User clicks "Download PDF"
  → React calls Rails: POST /auth/temporary_token (session cookie)
  → Rails returns { token: "jwt", url: "CF_WORKER/render?url=...&sig=...&exp=..." }
  → React opens that URL (window.open or fetch + blob download)
  → CF Worker verifies HMAC signature (rejects forged/tampered requests)
  → CF Worker opens headless Chrome, navigates to: react-app.com/documents/123/print?token=jwt
  → React print route reads token from query param, uses it for API calls instead of session cookie
  → CF Worker calls page.pdf(), returns PDF bytes directly to browser
```

### Key Design Decisions

- **React renders the content** — all rendering logic stays in one place, no duplication
- **Rails never proxies PDF bytes** — the signed URL lets the browser get the PDF directly from the CF Worker, keeping Rails connections free
- **JWT is user-scoped, GET-only, 30s expiry** — short-lived enough that leaking it is low risk, but broad enough to allow multiple API calls during page render
- **CF Worker is protected by HMAC signature** — even though the worker URL is visible in the browser, it can't be used to render arbitrary URLs because the signature is bound to the exact URL and expiry, and only Rails knows the signing secret

## What Rails API Needs

### 1. Temporary Token Endpoint

**`POST /auth/temporary_token`** (authenticated via session cookie)

Request body:
```json
{
  "purpose": "pdf",
  "path": "/documents/123/print"
}
```

Response:
```json
{
  "url": "https://pdf-worker.example.com/render?url=https%3A%2F%2Fapp.example.com%2Fdocuments%2F123%2Fprint%3Ftoken%3Deyj...&sig=abc123&exp=1234567890"
}
```

This endpoint:
- Mints a JWT: `{ sub: user_id, purpose: "pdf", methods: ["GET"], exp: now + 30s }`
- Constructs the full React print URL with the JWT as a query param
- HMAC-signs the URL + expiry using a shared secret (shared with the CF Worker)
- Returns the complete signed CF Worker URL ready for the browser to open

### 2. Auth Middleware Update

Update the authentication middleware to accept JWT bearer tokens as an alternative to session cookies:

- If no valid session cookie, check `Authorization: Bearer <token>` header
- Validate the JWT signature and expiry
- Enforce `methods: ["GET"]` — reject non-GET requests made with a temporary token
- Set the current user from `sub` claim
- This is a fallback path — session cookie auth continues to work as before

### Rails Config

New environment variables:
- `PDF_JWT_SECRET` — secret for signing/verifying temporary JWTs
- `PDF_HMAC_SECRET` — shared secret for HMAC-signing CF Worker URLs (shared with CF Worker)
- `PDF_WORKER_URL` — base URL of the CF Worker (e.g. `https://pdf-worker.example.com`)
- `PDF_REACT_URL` — base URL of the React app (e.g. `https://app.example.com`)

## What React Needs

### 1. Print Route

New route: `/documents/:id/print` (and similar for other printable resources)

- Renders the document in a print-friendly layout (clean, no nav/sidebar, print CSS)
- On mount, checks for `?token=xxx` query param
- If token is present, uses it as `Authorization: Bearer xxx` for all API calls instead of session cookie
- This should be scoped to print routes only — don't change the global auth flow

Implementation options:
- A wrapper component or hook (`usePrintAuth`) that reads the token from the URL and configures the API client
- A print layout component that strips chrome and applies print styles

### 2. Download Button/Action

Add a "Download PDF" button to the relevant pages:

```tsx
const handleDownloadPdf = async () => {
  // Call Rails to get the signed CF Worker URL
  const { url } = await api.post("/auth/temporary_token", {
    purpose: "pdf",
    path: `/documents/${id}/print`,
  });

  // Open the URL — browser receives PDF directly from CF Worker
  window.open(url);
};
```

Alternatively, for a more controlled download experience:

```tsx
const handleDownloadPdf = async () => {
  const { url } = await api.post("/auth/temporary_token", {
    purpose: "pdf",
    path: `/documents/${id}/print`,
  });

  const response = await fetch(url);
  const blob = await response.blob();
  const blobUrl = URL.createObjectURL(blob);

  const a = document.createElement("a");
  a.href = blobUrl;
  a.download = `document-${id}.pdf`;
  a.click();
  URL.revokeObjectURL(blobUrl);
};
```

### 3. Print-Friendly Styling

- Print layout component with clean styling (no navigation, no interactive elements)
- Consider `@media print` CSS or a dedicated print stylesheet
- Ensure fonts, images, and styles are fully loaded before the CF Worker captures the page (the worker waits for `networkidle0`)

## What Cloudflare Worker Needs

### 1. New Worker (or new route on existing worker)

**`GET /render?url=<encoded-url>&sig=<hmac>&exp=<timestamp>`**

Flow:
1. Check `exp` — reject if expired
2. Verify HMAC signature — recompute `HMAC(url + exp, secret)` and compare with `sig`
3. Validate the URL origin is in the allowlist (belt and braces — only your React app's domain)
4. Launch headless Chrome via Browser Rendering API
5. Navigate to the URL, wait for `networkidle0`
6. Call `page.pdf({ format: "A4", printBackground: true })`
7. Return PDF bytes with `Content-Type: application/pdf`

```ts
import puppeteer from "@cloudflare/puppeteer";

app.get("/render", async (c) => {
  const url = c.req.query("url");
  const sig = c.req.query("sig");
  const exp = c.req.query("exp");

  // 1. Check expiry
  if (Date.now() > Number(exp) * 1000) {
    return c.text("Expired", 403);
  }

  // 2. Verify HMAC
  const valid = await verifyHmac(url + exp, sig, c.env.PDF_HMAC_SECRET);
  if (!valid) {
    return c.text("Invalid signature", 403);
  }

  // 3. Check URL origin allowlist
  const parsed = new URL(url);
  if (!ALLOWED_ORIGINS.includes(parsed.origin)) {
    return c.text("Disallowed origin", 403);
  }

  // 4. Render PDF
  const browser = await puppeteer.launch(c.env.BROWSER);
  const page = await browser.newPage();
  await page.goto(url, { waitUntil: "networkidle0" });
  const pdf = await page.pdf({ format: "A4", printBackground: true });
  await browser.close();

  return new Response(pdf, {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": "inline; filename=\"document.pdf\"",
    },
  });
});
```

### Worker Config

Environment variables / secrets:
- `PDF_HMAC_SECRET` — shared with Rails, for verifying signed URLs
- `ALLOWED_ORIGINS` — allowlist of React app origins

Browser binding in `wrangler.toml`:
```toml
[browser]
binding = "BROWSER"
```

### CORS

The worker needs to return appropriate CORS headers if using the `fetch` + blob download approach from React (not needed for `window.open`).

## Security Summary

| Layer | Protection |
|-------|-----------|
| Rails token endpoint | Session cookie required — only authenticated users can request tokens |
| JWT | 30s expiry, user-scoped, GET-only — limits blast radius if leaked |
| HMAC signature | Binds the CF Worker request to a specific URL + expiry — can't forge requests for arbitrary URLs |
| URL origin allowlist | CF Worker only renders pages from your React app's domain |
| Short-lived | JWT expires in 30s, HMAC expiry matches — entire flow must complete quickly |

## Implementation Order

1. **Rails: JWT temporary token endpoint + auth middleware update** — can be tested independently
2. **React: Print route** — can be tested by navigating to it directly with a manually-minted token
3. **CF Worker: /render endpoint** — can be tested with a curl + manually-signed URL
4. **React: Download button** — wires everything together
5. **End-to-end testing** — click button, get PDF
