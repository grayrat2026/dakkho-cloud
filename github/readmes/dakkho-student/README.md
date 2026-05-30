# DAKKHO Student

<p align="center">
  <strong>BTEB Diploma Engineering Education Platform - Student App</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android" alt="Android" />
  <img src="https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge" alt="License" />
</p>

---

## Overview

DAKKHO Student is the primary mobile application for students of Bangladesh Technical Education Board (BTEB) Diploma Engineering programs. It provides a comprehensive, offline-first learning experience with DRM-protected video streaming, live interactive classes, assessments, community features, and flexible subscription payment options — all tailored for the unique needs of Bangladeshi technical education students.

**Package:** `com.grayrat.dakkho.student.pro.bd`

---

## Features

| Category | Features |
|----------|----------|
| **Offline-First** | Local SQLite via Drift, background sync queue, conflict resolution, data-saver mode |
| **1 Device Limit** | Hardware fingerprinting, anti-sharing detection, device swap audit trail |
| **Video Streaming** | HLS adaptive streaming, Widevine DRM, quality selector (240p-1080p), watermark overlay, "বুঝি নাই" (didn't understand) timestamp button |
| **Live Classes** | LiveKit Cloud integration, real-time audio/video, hand raise, chat, screen share |
| **Quizzes & Assessments** | Timed quizzes, negative marking, tab-switch detection, question palette, mock exams, AI-generated questions |
| **Community Chat** | Study rooms, department groups, voice notes, media sharing, threaded discussions |
| **Subscriptions** | Trial / Basic / Premium tiers, bKash, Nagad, SSLCommerz payment gateways, coupon system |
| **Push Notifications** | OneSignal integration, study reminders, live class alerts, payment notifications |
| **Animations** | 80+ micro-animations via Lottie, Rive, flutter_animate; Performance Mode toggle for low-end devices |
| **Gamification** | Streaks, XP, badges, leaderboard, progress dashboard |
| **Security** | Root/jailbreak detection, screenshot guard, screen recording detector, watermark overlay |
| **Downloads** | Offline video downloads with DRM license management, storage dashboard |

---

## Tech Stack

| Technology | Version | Purpose |
|-----------|---------|---------|
| Flutter | 3.24+ | Cross-platform UI framework |
| Dart | 3.5+ | Programming language |
| Riverpod | 2.0+ | State management |
| Drift (SQLite) | 2.x | Offline-first local database |
| Appwrite Cloud | Latest | Backend (Auth, DB, Storage, Functions, Realtime) |
| LiveKit Cloud | Latest | Live video/audio classes |
| Cloudflare R2 | Latest | Video & asset storage (zero egress) |
| OneSignal | Latest | Push notifications |
| media_kit | Latest | Video playback (HLS/DRM) |
| Lottie | Latest | JSON animations |
| Rive | Latest | Interactive animations |
| flutter_animate | Latest | Declarative animations |
| GoRouter | Latest | Declarative routing |
| freezed / json_serializable | Latest | Data class generation |
| connectivity_plus | Latest | Network awareness |
| dio | Latest | HTTP client |
| url_launcher | Latest | Deep linking |
| share_plus | Latest | Content sharing |
| path_provider | Latest | File system access |
| permission_handler | Latest | Runtime permissions |
| intl | Latest | Bengali (bn_BD) localization |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DAKKHO Student App                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │  Feature  │  │  Feature  │  │  Feature  │  │    Feature       │   │
│  │   Auth    │  │   Home    │  │   Video   │  │   Assessment     │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───────┬──────────┘   │
│       │              │              │                 │              │
│  ┌────┴─────┐  ┌────┴─────┐  ┌────┴─────┐  ┌───────┴──────────┐   │
│  │  Feature  │  │  Feature  │  │  Feature  │  │    Feature       │   │
│  │Community  │  │ Subscribe │  │  Profile  │  │   Notifications  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───────┬──────────┘   │
│       │              │              │                 │              │
│  ═════╪══════════════╪══════════════╪═════════════════╪═══════════   │
│       │         PRESENTATION LAYER  │                 │              │
│  ═════╪══════════════╪══════════════╪═════════════════╪═══════════   │
│       │              │              │                 │              │
│  ┌────┴──────────────┴──────────────┴─────────────────┴──────────┐  │
│  │                    RIVERPOD PROVIDERS                          │  │
│  │  auth_provider │ course_provider │ video_provider │ ...        │  │
│  └──────────────────────────┬────────────────────────────────────┘  │
│                             │                                       │
│  ┌──────────────────────────┴────────────────────────────────────┐  │
│  │                    REPOSITORIES                                │  │
│  │  auth_repository │ course_repository │ video_repository │ ...  │  │
│  └───────────┬──────────────────────────────────┬────────────────┘  │
│              │                                  │                    │
│  ┌───────────┴──────────┐         ┌────────────┴────────────────┐  │
│  │   LOCAL DATA LAYER   │         │      REMOTE DATA LAYER      │  │
│  │                      │         │                             │  │
│  │  Drift (SQLite)      │         │  Appwrite Cloud SDK         │  │
│  │  ├── DAOs            │         │  ├── Auth Service           │  │
│  │  ├── Tables          │         │  ├── Database Service       │  │
│  │  └── AppDatabase     │         │  ├── Storage Service        │  │
│  │                      │         │  └── Function Service       │  │
│  └───────────┬──────────┘         └────────────┬────────────────┘  │
│              │                                  │                    │
│  ┌───────────┴──────────────────────────────────┴────────────────┐  │
│  │                    SYNC ENGINE                                 │  │
│  │  Sync Queue Processor │ Conflict Resolver │ Network Awareness │  │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    CORE SERVICES                              │  │
│  │  Animations │ Security │ Notifications │ Theme │ Utils       │  │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
          ┌───────────────────────────────────┐
          │         CLOUD SERVICES            │
          │  Appwrite │ LiveKit │ R2 │ OneSig │
          └───────────────────────────────────┘
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.24.0 or later
- Dart SDK 3.5.0 or later
- Android Studio / VS Code with Flutter extensions
- Android SDK (API 24+)
- JDK 17
- Git

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/OWNER/dakkho-student.git
cd dakkho-student

# 2. Install dependencies
flutter pub get

# 3. Generate code (freezed, json_serializable, drift)
dart run build_runner build --delete-conflicting-outputs

# 4. Configure environment variables
cp .env.example .env
# Edit .env with your actual values (see Environment Variables below)

# 5. Configure Android signing
cp android/key.properties.example android/key.properties
# Edit key.properties with your keystore details

# 6. Run the app
flutter run
```

---

## Environment Variables

Create a `.env` file in the project root (use `.env.example` as template):

| Variable | Description | Example |
|----------|-------------|---------|
| `APPWRITE_ENDPOINT` | Appwrite Cloud API endpoint | `https://cloud.appwrite.io/v1` |
| `APPWRITE_PROJECT_ID` | Appwrite project ID | `your-project-id` |
| `APPWRITE_DATABASE_ID` | Appwrite database ID | `dakkho-main` |
| `LIVEKIT_URL` | LiveKit Cloud server URL | `wss://dakkho.livekit.cloud` |
| `LIVEKIT_API_KEY` | LiveKit API key | `your-livekit-api-key` |
| `LIVEKIT_API_SECRET` | LiveKit API secret | `your-livekit-api-secret` |
| `ONESIGNAL_APP_ID` | OneSignal app ID | `your-onesignal-app-id` |
| `R2_BUCKET_NAME` | Cloudflare R2 bucket name | `dakkho-videos` |
| `R2_PUBLIC_URL` | Cloudflare R2 public access URL | `https://cdn.dakkho.com` |
| `BUNNY_CDN_API_KEY` | Bunny.net CDN API key | `your-bunny-api-key` |
| `BUNNY_LIBRARY_ID` | Bunny.net video library ID | `your-library-id` |
| `SSLCOMMERZ_STORE_ID` | SSLCommerz store ID | `your-store-id` |
| `SSLCOMMERZ_STORE_PASSWORD` | SSLCommerz store password | `your-store-password` |
| `BKASH_USERNAME` | bKash API username | `your-bkash-username` |
| `BKASH_PASSWORD` | bKash API password | `your-bkash-password` |
| `BKASH_APP_KEY` | bKash app key | `your-bkash-app-key` |
| `BKASH_APP_SECRET` | bKash app secret | `your-bkash-app-secret` |
| `NAGAD_MERCHANT_ID` | Nagad merchant ID | `your-nagad-merchant-id` |
| `NAGAD_PUBLIC_KEY` | Nagad RSA public key (PEM) | `-----BEGIN PUBLIC KEY-----...` |
| `GOOGLE_OAUTH_CLIENT_ID` | Google OAuth client ID | `your-google-client-id` |
| `SENTRY_DSN` | Sentry error tracking DSN (optional) | `https://xxx@sentry.io/xxx` |

> **Important:** Never commit `.env` files. They are included in `.gitignore`.

---

## Directory Structure

```
dakkho-student/
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── kotlin/com/grayrat/dakkho/student/pro/bd/
│   │   │   │   └── MainActivity.kt
│   │   │   └── AndroidManifest.xml
│   │   └── build.gradle
│   └── key.properties.example      # Keystore config template
├── assets/
│   ├── animations/
│   │   ├── lottie/                  # Lottie JSON animations
│   │   │   ├── success.json
│   │   │   ├── error.json
│   │   │   ├── loading.json
│   │   │   ├── empty_state.json
│   │   │   └── confetti.json
│   │   └── rive/                    # Rive animation files
│   ├── images/                      # Static images
│   └── fonts/                       # Custom fonts
├── ios/                             # iOS (future)
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app.dart                     # MaterialApp configuration
│   ├── core/
│   │   ├── animations/
│   │   │   ├── dakkho_animations.dart    # Animation enum (80+ IDs)
│   │   │   ├── animation_presets.dart    # Preset animation methods
│   │   │   ├── dakkho_durations.dart     # Duration constants
│   │   │   ├── dakkho_curves.dart        # Custom easing curves
│   │   │   └── performance_mode.dart     # Performance toggle
│   │   ├── appwrite/
│   │   │   ├── appwrite_client.dart      # SDK initialization
│   │   │   ├── auth_service.dart         # Authentication
│   │   │   ├── database_service.dart     # Database operations
│   │   │   ├── storage_service.dart      # File storage
│   │   │   └── function_service.dart     # Cloud functions
│   │   ├── database/
│   │   │   ├── app_database.dart         # Drift database
│   │   │   ├── tables/                   # Table definitions
│   │   │   └── dao/                      # Data access objects
│   │   ├── network/
│   │   │   ├── connectivity_provider.dart
│   │   │   └── network_aware_config.dart
│   │   ├── notifications/
│   │   │   ├── onesignal_service.dart
│   │   │   └── reminder_engine.dart
│   │   ├── security/
│   │   │   ├── root_detector.dart
│   │   │   ├── device_limit_service.dart
│   │   │   ├── screen_recording_detector.dart
│   │   │   └── watermark_overlay.dart
│   │   ├── sync/
│   │   │   ├── sync_engine.dart
│   │   │   ├── sync_queue_processor.dart
│   │   │   └── conflict_resolver.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_typography.dart
│   │   │   ├── app_theme.dart
│   │   │   ├── glassmorphism.dart
│   │   │   └── aurora_background.dart
│   │   └── utils/
│   │       ├── constants.dart
│   │       ├── extensions.dart
│   │       ├── validators.dart
│   │       └── formatters.dart
│   ├── data/
│   │   ├── models/                  # Data models (freezed)
│   │   │   ├── user_model.dart
│   │   │   ├── course_model.dart
│   │   │   ├── video_model.dart
│   │   │   ├── quiz_model.dart
│   │   │   ├── subscription_model.dart
│   │   │   ├── chat_message_model.dart
│   │   │   └── app_config_model.dart
│   │   ├── providers/               # Riverpod providers
│   │   │   ├── auth_provider.dart
│   │   │   ├── course_provider.dart
│   │   │   ├── video_provider.dart
│   │   │   ├── quiz_provider.dart
│   │   │   ├── subscription_provider.dart
│   │   │   ├── community_provider.dart
│   │   │   ├── device_provider.dart
│   │   │   ├── config_provider.dart
│   │   │   └── network_provider.dart
│   │   └── repositories/            # Data layer
│   │       ├── auth_repository.dart
│   │       ├── course_repository.dart
│   │       ├── video_repository.dart
│   │       ├── quiz_repository.dart
│   │       ├── subscription_repository.dart
│   │       └── chat_repository.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── login_page.dart
│   │   │   ├── otp_verification_page.dart
│   │   │   ├── profile_setup_page.dart
│   │   │   └── widgets/
│   │   ├── home/
│   │   │   ├── home_page.dart
│   │   │   └── widgets/
│   │   ├── video/
│   │   │   ├── course_detail_page.dart
│   │   │   ├── video_player_page.dart
│   │   │   └── widgets/
│   │   ├── assessment/
│   │   │   ├── quiz_page.dart
│   │   │   ├── mock_exam_page.dart
│   │   │   ├── quiz_result_page.dart
│   │   │   └── widgets/
│   │   ├── community/
│   │   │   ├── study_rooms_page.dart
│   │   │   ├── chat_room_page.dart
│   │   │   └── widgets/
│   │   ├── subscription/
│   │   │   ├── subscription_page.dart
│   │   │   ├── payment_page.dart
│   │   │   └── widgets/
│   │   ├── offline/
│   │   │   ├── downloads_page.dart
│   │   │   └── storage_dashboard.dart
│   │   ├── notifications/
│   │   │   └── notifications_page.dart
│   │   └── profile/
│   │       ├── profile_page.dart
│   │       ├── settings_page.dart
│   │       └── widgets/
│   ├── routes/
│   │   ├── app_router.dart
│   │   └── route_guards.dart
│   └── shared/
│       └── widgets/
│           ├── dakkho_scaffold.dart
│           ├── dakkho_button.dart
│           ├── dakkho_card.dart
│           ├── dakkho_text_field.dart
│           ├── glass_card.dart
│           ├── bottom_nav_bar.dart
│           ├── loading_widget.dart
│           ├── error_widget.dart
│           └── empty_state.dart
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
├── .env.example
├── .gitignore
├── analysis_options.yaml
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

---

## Build & Release

### Debug Build

```bash
# Debug APK
flutter build apk --debug

# Run on connected device
flutter run
```

### Release Build

```bash
# Generate code first
dart run build_runner build --delete-conflicting-outputs

# Build release APK
flutter build apk --release

# Build Android App Bundle (for Play Store)
flutter build appbundle --release
```

### Signing Configuration

Create `android/key.properties`:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/path/to/upload-keystore.jks
```

---

## Play Store Compliance Notes

- **Content Rating:** Educational content — target PEGI 3 / Everyone
- **Data Safety:** Declare collected data (device ID for 1-device limit, phone number for OTP, payment info)
- **Target API:** Android 14 (API 34) or latest required
- **Permissions:** Minimize permissions — only INTERNET, READ_PHONE_STATE (device fingerprint), POST_NOTIFICATIONS, CAMERA (profile), RECORD_AUDIO (voice notes)
- **Billing:** Use approved payment methods per Play Store policy (in-app purchases via Google Play Billing for digital goods)
- **Privacy Policy:** Required — must be linked in Play Store listing
- **Accessibility:** Support Bengali (bn_BD) as primary language, English as secondary
- **Performance:** Target 60fps on mid-range devices, provide Performance Mode for low-end

---

## CI/CD

See `.github/workflows/build-student.yml` for automated build pipeline.

Required GitHub Secrets:
- `KEYSTORE_BASE64` — Base64-encoded Android keystore
- `KEYSTORE_PASSWORD` — Keystore password
- `KEY_ALIAS` — Key alias
- `KEY_PASSWORD` — Key password
- `ENV_FILE` — Base64-encoded .env file

---

## License

**Proprietary** — All rights reserved. This source code is confidential and proprietary to GrayRat. Unauthorized copying, distribution, or use is strictly prohibited.

---

<p align="center">
  Built with ❤️ for BTEB Diploma Engineering Students of Bangladesh
</p>
