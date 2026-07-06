# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Spendly is an Android-only Flutter app that auto-tracks expenses by parsing bank SMS. Everything is stored locally (Isar); there is no backend. iOS is not supported.

## Commands

```bash
flutter pub get                                          # Install deps
dart run build_runner build --delete-conflicting-outputs # Regenerate Isar schema (expense.g.dart) — REQUIRED after editing lib/core/models/expense.dart
flutter run                                              # Run on connected Android device/emulator
flutter test                                             # Run all tests
flutter test test/services/backup/backup_service_test.dart          # Run one test file
flutter test --plain-name "dedupe"                                  # Run tests matching a name
flutter analyze                                          # Lint (must be 0 issues; CI enforces)
flutter build apk --release                             # Output: build/app/outputs/flutter-apk/app-release.apk
```

Standalone parser sanity scripts (not part of `flutter test`), run against real-world SMS samples:
```bash
dart run tool/sms_check.dart            # Parse a single hardcoded SMS, print extracted fields
dart run tool/real_world_sms_suite.dart # Run the curated SMS case suite
```

CI (`.github/workflows/release.yml`) triggers on `v*` tags and runs pub get → build_runner → test → analyze → build apk. Requires Android SDK Platform 36.

## Architecture

Dependency wiring happens once in `lib/main.dart`: all services/repositories are constructed there and injected into Riverpod via `ProviderScope` overrides. The bare `Provider` declarations in `lib/core/providers/providers.dart` throw `UnimplementedError` by design — they exist only so the type is available and MUST be overridden in `main` (or in tests). `providers.dart` is the single source of truth for all providers and SharedPreferences key constants.

Data flows in one direction: **SMS → parser → repository (Isar) → StreamProviders → UI**. Isar `.watch()` streams (`watchAllExpenses`, `watchMonthlyExpenses`) drive the UI reactively, so writes to the repo automatically refresh screens.

### SMS ingestion (the core feature)
`SmsIngestionService` (`lib/services/sms/`) has three ingestion paths, all funneling through `_ingestRawSms`:
- **Historical backfill**: `ingestHistoricalInbox()` reads the existing inbox on first launch after permission grant.
- **Foreground live**: `listenIncomingSms` via `another_telephony`.
- **Background/killed app**: `backgroundMessageHandler` is a top-level `@pragma('vm:entry-point')` function that runs in a separate isolate. It CANNOT access the app's Riverpod graph — it opens its own Isar instance and rebuilds a `TransactionParser` + `ExpenseRepository` from scratch. There is also a native `SmsReceiver.kt` (MethodChannel `spendly/sms_receiver`) as a fallback path.

Because ingestion happens from multiple paths/isolates, **deduplication is critical**. `buildSmsDedupeKey` produces `amount|sender|merchant|minuteBucket` (timestamp rounded to a 60s window). Every write checks `existsByDedupeKey` first. When changing parser output fields that feed the key, understand you may change dedupe behavior.

### Parser (`lib/services/parser/`)
`TransactionParser.parse()` is pure/stateless and returns `ParsedTransaction?` (null = not a trackable expense). It is regex-driven:
- Extracts amount, UPI id, card last-4, merchant, bank name.
- **Only debits are tracked** — credits/refunds return null (see `_classify` + `BankRules.creditKeywords`).
- Filters out OTP/statement/collect-request noise via `BankRules.nonExpensePatterns`.
- Bank-specific sender patterns and debit/credit keyword lists live in `bank_rules.dart` — extend banks/keywords there, not in the parser.

The parser is the highest-risk area for regressions across diverse Indian bank SMS formats. Add cases to `tool/real_world_sms_suite.dart` and the parser tests when changing regexes.

### Persistence
Single Isar collection: `Expense` (`lib/core/models/expense.dart`), opened as a singleton in `isar_service.dart`. Editing the model requires re-running build_runner to regenerate `expense.g.dart` (checked in). `searchAndFilter` in the repository filters in-memory (loads all, then `.where`) rather than via Isar queries.

### Backup (`lib/services/backup/`)
`BackupService` serializes all expenses to versioned JSON (`schemaVersion`, currently 1). **Import REPLACES all data** (`clearAll` + `saveAll`), it does not merge. `GoogleDriveService` wraps `BackupService` for Drive upload/download and requires OAuth setup + `android/app/google-services.json` (optional; local JSON export works without it).

### UI
`go_router` config and Material 3 theming are both in `lib/app/spendly_app.dart` (routes: `/`, `/analytics`, `/manual-entry`, `/backup`). Features are organized by screen under `lib/features/`. Analytics uses `fl_chart`. A "backup nudge" (colored indicator + reminder) is driven by `lastBackupTimestampKey` in SharedPreferences.
