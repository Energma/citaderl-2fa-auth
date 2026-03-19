# Citadel Auth

**Privacy-first 2FA authenticator. Your secrets. Your fortress. No exceptions.**

Citadel Auth is an open-source, offline-first two-factor authentication app built with Flutter. Your passwords and secrets never leave your device — no accounts, no cloud sync, no telemetry.

## Features

### Authentication Codes
- **TOTP** (Time-based One-Time Password) — RFC 6238 compliant
- **HOTP** (Counter-based One-Time Password) — RFC 4226 compliant
- **Steam Guard** support with custom character set
- Configurable algorithms: SHA-1, SHA-256, SHA-512
- Configurable digits (6–8) and period (15–60s)

### Security
- **AES-256-GCM** encryption for all stored data
- **Argon2id** key derivation (64 MB memory, 3 iterations)
- **Encrypted SQLite** database (SQLCipher)
- Master password protection (minimum 8 characters)
- Optional 6-digit PIN for quick unlock
- Biometric unlock (fingerprint / face recognition)
- Auto-lock with configurable timeout

### Organization
- **Profiles** — group tokens by context (Personal, Work, etc.) with color coding
- **Groups** — organize tokens within profiles
- Pin important tokens to the top
- Tag tokens for easy filtering
- Search across all tokens

### Import & Export
- Export as Citadel JSON or `otpauth://` URIs
- Import from:
  - Citadel Auth
  - Aegis Authenticator
  - 2FAS Authenticator
  - Ente Auth
  - Plain `otpauth://` URI lists

### Add Tokens
- QR code scanning
- Manual entry
- URI import (`otpauth://totp/...` or `otpauth://hotp/...`)

### UI
- Material Design 3 (Material You)
- Light and dark themes
- Live countdown timers with progress indicators
- Swipe actions on token cards
- Copy codes to clipboard with one tap

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/) 3.11.1 or later
- [FVM](https://fvm.app/) (Flutter Version Manager) — recommended
- Android SDK (for Android builds)

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd citadel

# Install Flutter version via FVM
fvm install

# Get dependencies
./dev.sh get
```

### Development

The project includes a `dev.sh` helper script for common tasks:

```bash
./dev.sh start   # Launch emulator, install deps, and run the app
./dev.sh get     # Get dependencies
./dev.sh build   # Run code generation (build_runner)
./dev.sh test    # Run tests
./dev.sh clean   # Clean build artifacts and re-fetch dependencies
```

### Manual Flutter Commands

```bash
fvm flutter pub get
fvm flutter run -d <device-id>
fvm flutter test
```

## Architecture

```
lib/
├── main.dart                     # App entry point
├── core/
│   ├── providers.dart            # Riverpod state management
│   ├── models/
│   │   ├── token.dart            # Token model (TOTP/HOTP)
│   │   └── profile.dart          # Profile & TokenGroup models
│   └── crypto/
│       ├── otp_engine.dart       # OTP code generation (RFC 6238/4226)
│       ├── vault_encryption.dart # Argon2id + AES-256-GCM
│       └── import_export.dart    # Multi-format import/export
├── data/
│   ├── database/
│   │   └── vault_database.dart   # Encrypted SQLite layer
│   └── repositories/
│       ├── token_repository.dart # Token CRUD
│       └── profile_repository.dart
├── platform/
│   ├── biometric_service.dart    # Biometric auth wrapper
│   └── keystore_service.dart     # Secure storage wrapper
└── ui/
    ├── screens/                  # App screens
    ├── widgets/                  # Reusable components
    └── theme/                    # Material 3 theming
```

### Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.11+ |
| State management | Riverpod |
| Database | SQLCipher (encrypted SQLite) |
| Key derivation | Argon2id |
| Encryption | AES-256-GCM |
| Biometrics | local_auth |
| Secure storage | flutter_secure_storage |
| QR scanning | mobile_scanner |

### App Flow

```
App Launch
  ├── First run → Setup Screen (create master password + optional PIN/biometric)
  └── Returning user → Lock Screen (unlock with password / PIN / biometric)
       └── Unlocked → Home Screen (view & manage tokens)
            └── App backgrounded → Auto-lock after timeout
```

## Security Model

- The master password is never stored — only a derived key is used at runtime
- All token secrets are encrypted at rest using AES-256-GCM
- Key derivation uses Argon2id with memory-hard parameters to resist brute force
- The database file is encrypted via SQLCipher
- Sensitive keys are stored in platform keystores (Android Keystore / iOS Keychain)
- No network requests, no analytics, no telemetry

## Contributing

Contributions are welcome. Please open an issue first to discuss what you'd like to change.

## License

All rights reserved. See LICENSE file for details.

---

Built by [Energma](https://energma.com)
