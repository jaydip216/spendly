# Spendly development status

Updated: 8 September 2026

## Working now

- Android expense tracking from historical, foreground and background SMS.
- Conservative debit parsing with OTP, credit, refund, reversal, declined,
  pending and future-payment rejection.
- Manual entry, category management, search and filtering.
- Month summaries, insights and merchant details.
- Local JSON backup/import and optional Google Drive backup/restore.
- Light and dark Classical themes with fonts bundled for offline use.
- Review flow for saved SMS entries that the current parser rejects. Removal
  is manual, selected-entry only, and leaves the Android inbox unchanged.

## Verification

- Static analysis must report zero issues.
- The full Flutter test suite covers parser rules, repositories, backup,
  screen layouts in both themes, and review confirmation.
- Emulator checks cover foreground SMS, background SMS, OTP/credit rejection,
  and inbox rescan deduplication.

## Before public release

- Test with redacted examples from the user's actual banks and payment apps.
- Verify Google Drive with production OAuth credentials.
- Configure a private Android release keystore and replace debug signing.
- Exercise backup export/import and permission revocation on a physical phone.

The current debug APK is intended for local testing. It is not a signed
distribution build.
