# PratiCase Auth Email Templates

PratiCase uses the shared Medasi Supabase Auth instance, so Auth email
templates must not be replaced with PratiCase-only copy. A global replacement
would also affect Qlinik. The templates in `supabase/auth-templates/` keep that
boundary by branching:

- `confirmation.html`: shows PratiCase OTP copy only when the confirmation
  redirect is `https://praticase.medasi.com.tr/auth/callback`.
- `recovery.html`: shows PratiCase OTP copy only when the recovery redirect is
  `https://praticase.medasi.com.tr/auth/callback`.
- The fallback block remains generic Medasi and includes the Supabase
  confirmation URL, so Qlinik link-based flows continue to work.

## Self-hosted Supabase wiring

Supabase Auth fetches self-hosted email templates from HTTP URLs, not directly
from mounted files. Serve these HTML files from a private static template
service that is reachable by the `auth` container, then set:

```yaml
GOTRUE_MAILER_TEMPLATES_CONFIRMATION: "http://templates-server/confirmation.html"
GOTRUE_MAILER_SUBJECTS_CONFIRMATION: "Medasi e-posta doğrulama"
GOTRUE_MAILER_TEMPLATES_RECOVERY: "http://templates-server/recovery.html"
GOTRUE_MAILER_SUBJECTS_RECOVERY: "Medasi şifre sıfırlama"
```

Do not set the subjects to PratiCase-only wording on the shared Auth instance;
subjects are global and Qlinik receives the same subject. Keep product-specific
branding inside the conditional HTML body.

## PratiCase app contract

The Flutter app already uses OTP-first screens:

- Signup verification calls `verifyOTP(..., type: OtpType.email)`.
- Password recovery calls `verifyOTP(..., type: OtpType.recovery)` before
  `updateUser`.

If `AUTH_REDIRECT_URL` changes, update the condition in
`supabase/auth-templates/confirmation.html` and
`supabase/auth-templates/recovery.html` before deploying the template.
