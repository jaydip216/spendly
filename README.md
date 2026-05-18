# Spendly

Auto-tracks your expenses from bank SMS — because you're too lazy to do it manually.

## Motivation

I built this for myself. Every month I'd wonder "where did all my money go?" and then spend 20 minutes scrolling through bank SMS trying to piece together my spending. That's dumb.

Spendly reads your bank SMS, extracts transaction details (amount, merchant, UPI/card info), and shows you exactly where your money went. Open the app, see the damage. That's it.

I know there are apps available which can do this task for me but I am too cautious giving my inbox access. 

## Features

- 📱 **Auto-parses bank SMS** — UPI, card transactions, net banking
- 📊 **Spending analytics** — Pie chart (top merchants) + bar chart (monthly trend)
- ✍️ **Manual expense entry** — For cash or non-SMS transactions
- 🔍 **Search & filter** — Find expenses by merchant, type, or source
- 💾 **Backup & restore** — Local JSON export + Google Drive
- 🛡️ **Data safety nudges** — Colored indicator + reminder if you haven't backed up
- 🎨 **Material 3** — Dark/light theme, clean UI

## Tech Stack

| Layer | Tech |
|-------|------|
| Framework | Flutter 3.x / Dart 3.11+ |
| Database | Isar (local NoSQL) |
| State | Riverpod |
| Navigation | go_router |
| Charts | fl_chart |
| SMS | another_telephony |
| Backup | google_sign_in + googleapis |

## Running Locally

```bash
# Get dependencies
flutter pub get

# Generate Isar schemas (required after model changes)
dart run build_runner build --delete-conflicting-outputs

# Run on connected Android device/emulator
flutter run

# Build release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Requirements:**
- Flutter SDK 3.x+
- Android device or emulator (iOS not supported)
- SMS permission granted for auto-parsing

## Google Drive Backup Setup (Optional)

1. Create a project in [Google Cloud Console](https://console.cloud.google.com/)
2. Enable the Google Drive API
3. Create OAuth 2.0 credentials (Android client)
4. Add your app's SHA-1 fingerprint
5. Download `google-services.json` to `android/app/`

Without this setup, local JSON backup still works fine.

## Project Structure

```
lib/
├── app/                  # App widget + go_router config
├── core/
│   ├── database/         # Isar DB setup
│   ├── models/           # Expense model + generated schema
│   ├── providers/        # All Riverpod providers (single file)
│   └── repositories/     # ExpenseRepository (CRUD + search)
├── features/
│   ├── analytics/        # Pie + bar chart screens
│   ├── backup/           # Backup/restore UI
│   ├── expenses/         # ExpenseCard widget
│   ├── home/             # Home screen + monthly view
│   ├── manual_entry/     # Manual expense form
│   └── onboarding/       # SMS permission + data safety info
├── services/
│   ├── backup/           # BackupService + GoogleDriveService
│   ├── parser/           # SMS → Expense parsing rules
│   └── sms/              # SMS ingestion service
└── main.dart             # Bootstrap
```

## Commands

```bash
flutter run                                          # Dev
flutter test                                         # Run tests (53 pass)
flutter analyze                                      # Lint (0 issues)
dart run build_runner build --delete-conflicting-outputs  # Regen schemas
flutter build apk --release                          # Release build
```

---

## The Vibe Code Disclaimer

> This entire project was vibe coded. The whole thing. Every screen, every test, every carefully-crafted sealed class — all summoned into existence through the dark art of talking to an AI and trusting it knows what it's doing.
>
> No Stack Overflow tabs were opened. No documentation was read by human eyes. The commit messages are better than anything I'd write myself.
>
> If something breaks, just know that the vibes were absolutely immaculate at the time of shipping.
