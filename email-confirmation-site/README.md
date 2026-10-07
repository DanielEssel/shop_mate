# ShopMate email confirmation page

A standalone static page that Supabase redirects to after a user clicks the
"Confirm signup" link. It is not part of the Flutter app and has no build
step, dependencies, analytics or external resources.

- `shopmate/email-confirmed/index.html` — the page (inline CSS and one inline
  script).
- `_headers` — security headers for Cloudflare Pages (the `!` line that
  removes `Access-Control-Allow-Origin` is Cloudflare-specific syntax).

## What it does

- Normal case: shows "Email confirmed" and tells the user to return to the
  ShopMate app and sign in.
- If the address contains an `error` parameter (e.g.
  `#error=access_denied&error_code=otp_expired`): shows "Confirmation link
  expired" with a generic message. No error details are shown.
- In both cases it then removes the query and fragment (which may hold
  session tokens or codes) from the address bar with `history.replaceState`.
  Nothing from the address is displayed, logged, stored or sent.

## Preview locally

```sh
cd email-confirmation-site
python3 -m http.server 8080
```

Then open:

- http://localhost:8080/shopmate/email-confirmed/
- http://localhost:8080/shopmate/email-confirmed/#error=access_denied&error_code=otp_expired

## Hosting

Publish this folder as the site root on any static HTTPS host on a domain you
control (Cloudflare Pages, Netlify, GitHub Pages, Vercel). Supabase Storage is
not suitable: it serves HTML as plain text.

- Output/publish directory: `email-confirmation-site` (no build command).
- HTTPS required.
- Cloudflare Pages and Netlify apply `_headers` automatically. On other hosts,
  set the same headers in the host's configuration if it supports custom
  headers; the page's own `<meta>` Content-Security-Policy still applies
  either way.

The page is served at `/shopmate/email-confirmed/` (with the trailing slash).

## Supabase setting

Authentication → URL Configuration → Site URL:

```
https://<your-domain>/shopmate/email-confirmed/
```

Use the trailing slash so the host serves the page directly instead of
redirecting first.

## If the inline script changes

The Content-Security-Policy allows the inline script by its SHA-256 hash, in
both `index.html` and `_headers`. After editing the script, recompute the hash
of the exact text between `<script>` and `</script>` and update both places,
or the browser will block the script (the page then always shows the success
message).
