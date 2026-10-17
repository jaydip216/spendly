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
Two Isar collections: `Expense` and `Category` (`lib/core/models/`), opened as a singleton in `isar_service.dart`. Editing a model requires re-running build_runner to regenerate `*.g.dart` (checked in). `Expense.dedupeKey` has a unique replace-on-conflict index. `Expense.category` is a denormalized string name (not an IsarLink) so the background isolate and JSON backup can handle it; rows predating the field deserialize as `''` — treat `''` as `'Other'`. `searchAndFilter` in the repository filters in-memory (loads all, then `.where`) rather than via Isar queries.

### Categories (`lib/services/categorization/`)
`CategoryRules` is pure/static: keyword auto-categorization (merchant → UPI handle → raw SMS, rules checked in map order — Groceries before Food deliberately) plus the `defaultCategories` list used for seeding. All three ingestion paths auto-assign; users override via the expense detail sheet (tap any spend row). `CategoryRepository.delete/rename` atomically rewrite affected expenses. Defaults are seeded and legacy expenses backfilled once in `main.dart`.

### Backup (`lib/services/backup/`)
`BackupService(isar, expenseRepo)` serializes expenses + categories to versioned JSON (`schemaVersion`, currently 2; v1 payloads still import — defaults seeded, expenses auto-categorized). **Import REPLACES all data atomically** in a single Isar txn after the whole payload parses; it does not merge. `GoogleDriveService` wraps `BackupService` for Drive upload/download and requires OAuth setup + `android/app/google-services.json` (optional; local JSON export works without it).

### UI
The app follows the "Classical" design system (warm paper ground, ink text, a single gold accent, hairline rules instead of cards, Cormorant Garamond figures over Lora prose). The font files and OFL licences are checked into `assets/fonts/`, so typography works offline. **All tokens live in `lib/app/theme/spendly_theme.dart`** as a `SpendlyTokens` `ThemeExtension` with light and dark variants — read them with `SpendlyTokens.of(context)` and never hardcode a colour, font or type size in a screen. Type helpers on the tokens (`heading`, `figure`, `body`, `kicker`, `metricLabel`) are the only way styles are built; `letterSpacingEm` is in ems and gets multiplied by the size.

Shared primitives are in `lib/app/widgets/classical.dart` (`TabPage`, `Rule`, `SectionLabel`, `SectionHeading`, `ClassicalButton`, `IconAction`, `PillChip`, `MetricStrip`, `MeterRow`, `InitialAvatar`, `ListRow`, `EmptyState`, `Callout`, `SheetHandle`, `showClassicalSheet`, `DonutChart`). Charts are plain Flutter — flat bordered bars and a `CustomPainter` ring; there is no charting package. Formatting (Indian rupee grouping, date headings, merchant initials) is centralised in `lib/app/format.dart`, and display-only derivations off an `Expense` (payment method, account label, subtitle line) in `lib/app/expense_presentation.dart`.

Navigation is a `StatefulShellRoute.indexedStack` in `lib/app/spendly_app.dart` with four branches — `/` (Home), `/spends`, `/insights`, `/settings` — hosted by `AppShell` (`lib/features/shell/app_shell.dart`), which also starts SMS ingestion once and gates everything behind onboarding. `/manual-entry`, `/backup`, `/categories` and `/merchant` are pushed above the shell on the root navigator (`/merchant` takes the merchant name via `extra`). Every tab screen returns a `TabPage` so it also renders correctly in isolation (tests).

Screens are month-scoped: `selectedMonthProvider` drives Home and Insights, and `MonthSwitcher`/`showMonthSheet` (`lib/features/home/widgets/month_picker.dart`) are the shared control. Spends filtering is spread across `searchQueryProvider` plus the `filter*Provider`s; `filterCategoryProvider` is applied in `filteredExpensesProvider` rather than in the repository. A stale-backup dot (7+ days, from `lastBackupTimestampKey`) sits on the Home header icon.

`Settings → Review SMS entries` re-runs the current parser against stored raw SMS and shows entries that no longer qualify as expenses. It never deletes automatically. `ExpenseRepository.removeReviewedSms` deletes selected SMS rows atomically after checking that their stored raw messages have not changed.

**When reading an `AsyncValue` outside `.when`, use `.valueOrNull` — `.value` rethrows on error**, which crashes any screen whose repository provider is not overridden.

`test/features/screen_smoke_test.dart` renders every tab at a 412×892 viewport in both themes and fails on overflows; run it after layout changes.
