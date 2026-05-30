# DAKKHO Instructor

<p align="center">
  <strong>Instructor App for DAKKHO Platform</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android" alt="Android" />
  <img src="https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge" alt="License" />
</p>

---

## Overview

DAKKHO Instructor is the companion app for instructors on the DAKKHO educational platform. It enables instructors to manage their courses, upload and organize video content, host live classes, create quizzes, track student progress, resolve doubts, and monitor payout earnings — all from a mobile-first Flutter application designed for Bangladeshi BTEB Diploma Engineering educators.

**Package:** `com.grayrat.dakkho.instructor.pro.bd`

---

## Features

| Category | Features |
|----------|----------|
| **Course Management** | View assigned courses, add/edit chapters, reorder content, publish drafts |
| **Video Upload** | Record or upload video content, track encoding progress, manage Cloudflare R2 uploads |
| **Live Class Hosting** | Start/schedule live classes via LiveKit, screen share, whiteboard, participant management |
| **Quiz Creation** | Create quiz questions manually, review AI-generated questions, set difficulty and marks, configure negative marking |
| **Student Analytics** | View enrollment stats, watch progress per video, quiz score distributions, dropout indicators |
| **Doubt Resolution** | View "বুঝি নাই" (didn't understand) timestamps, respond to student questions, mark as resolved |
| **Payout Tracking** | View earnings by course/period, payout history, pending amounts, revenue share breakdown |
| **Announcements** | Post course-specific announcements, schedule posts, view read receipts |
| **Content Moderation** | Moderate course community chat, respond to student reports |
| **Profile Management** | Edit instructor profile, add qualifications, set availability |

---

## Tech Stack

| Technology | Version | Purpose |
|-----------|---------|---------|
| Flutter | 3.24+ | Cross-platform UI framework |
| Dart | 3.5+ | Programming language |
| Riverpod | 2.0+ | State management |
| Appwrite Cloud | Latest | Backend (Auth, DB, Storage, Functions, Realtime) |
| LiveKit Cloud | Latest | Live video/audio class hosting |
| Cloudflare R2 | Latest | Video upload & storage |
| media_kit | Latest | Video preview and playback |
| flutter_animate | Latest | UI animations |
| Lottie | Latest | Loading and status animations |
| GoRouter | Latest | Declarative routing |
| freezed / json_serializable | Latest | Data class generation |
| file_picker | Latest | Video file selection |
| image_picker | Latest | Thumbnail selection |
| connectivity_plus | Latest | Network awareness |
| fl_chart | Latest | Analytics charts |
| intl | Latest | Bengali (bn_BD) localization |
| cached_network_image | Latest | Image caching |
| share_plus | Latest | Share content |
| url_launcher | Latest | Open external links |
| permission_handler | Latest | Runtime permissions |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      DAKKHO Instructor App                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │ Courses  │ │  Video   │ │Live Class│ │  Quizzes │ │Students │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬────┘ │
│       │            │            │            │            │        │
│  ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌────┴────┐ │
│  │  Doubts  │ │ Payouts  │ │ Announce │ │ Profile  │ │Community│ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬────┘ │
│       │            │            │            │            │        │
│  ═════╪════════════╪════════════╪════════════╪════════════╪══════  │
│       │         PRESENTATION LAYER          │            │        │
│  ═════╪════════════╪════════════╪════════════╪════════════╪══════  │
│       │            │            │            │            │        │
│  ┌────┴────────────┴────────────┴────────────┴────────────┴─────┐ │
│  │                    RIVERPOD PROVIDERS                         │ │
│  │  course_provider │ video_provider │ livekit_provider │ ...    │ │
│  └──────────────────────────┬───────────────────────────────────┘ │
│                             │                                      │
│  ┌──────────────────────────┴───────────────────────────────────┐ │
│  │                    REPOSITORIES                               │ │
│  │  course_repo │ video_repo │ quiz_repo │ payout_repo │ ...    │ │
│  └───────────────┬──────────────────────────────┬───────────────┘ │
│                  │                              │                  │
│  ┌───────────────┴──────────┐   ┌──────────────┴───────────────┐ │
│  │    CLOUD DATA LAYER      │   │     EXTERNAL SERVICES        │ │
│  │                          │   │                              │ │
│  │  Appwrite Cloud SDK      │   │  LiveKit Cloud               │ │
│  │  ├── Auth Service        │   │  ├── Room Management         │ │
│  │  ├── Database Service    │   │  ├── Token Generation        │ │
│  │  ├── Storage Service     │   │  └── Participant Control     │ │
│  │  └── Function Service    │   │                              │ │
│  │                          │   │  Cloudflare R2               │ │
│  └──────────────────────────┘   │  ├── Video Upload            │ │
│                                 │  └── Presigned URLs          │ │
│                                 └──────────────────────────────┘ │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                    CORE SERVICES                              │ │
│  │  Animations │ Upload Manager │ Notifications │ Theme │ Utils │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.24.0 or later
- Dart SDK 3.5.0 or later
- Android Studio / VS Code
- JDK 17
- Instructor Appwrite account with `instructor` team membership

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/OWNER/dakkho-instructor.git
cd dakkho-instructor

# 2. Install dependencies
flutter pub get

# 3. Generate code
dart run build_runner build --delete-conflicting-outputs

# 4. Configure environment
cp .env.example .env
# Edit .env with your actual values

# 5. Configure Android signing
cp android/key.properties.example android/key.properties

# 6. Run the app
flutter run
```

---

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `APPWRITE_ENDPOINT` | Appwrite Cloud API endpoint | `https://cloud.appwrite.io/v1` |
| `APPWRITE_PROJECT_ID` | Appwrite project ID | `your-project-id` |
| `APPWRITE_DATABASE_ID` | Appwrite database ID | `dakkho-main` |
| `INSTRUCTOR_TEAM_ID` | Appwrite instructor team ID | `your-instructor-team-id` |
| `LIVEKIT_URL` | LiveKit Cloud server URL | `wss://dakkho.livekit.cloud` |
| `LIVEKIT_API_KEY` | LiveKit API key | `your-livekit-api-key` |
| `LIVEKIT_API_SECRET` | LiveKit API secret | `your-livekit-api-secret` |
| `R2_BUCKET_NAME` | Cloudflare R2 bucket for video uploads | `dakkho-videos-raw` |
| `R2_ACCESS_KEY_ID` | Cloudflare R2 access key | `your-r2-access-key` |
| `R2_SECRET_ACCESS_KEY` | Cloudflare R2 secret key | `your-r2-secret-key` |
| `R2_ACCOUNT_ID` | Cloudflare account ID | `your-account-id` |
| `ONESIGNAL_APP_ID` | OneSignal app ID | `your-onesignal-app-id` |
| `BUNNY_CDN_API_KEY` | Bunny.net CDN API key | `your-bunny-api-key` |
| `BUNNY_LIBRARY_ID` | Bunny.net video library ID | `your-library-id` |

> **Important:** Never commit `.env` files. They are included in `.gitignore`.

---

## Directory Structure

```
dakkho-instructor/
├── android/
├── assets/
│   ├── animations/
│   ├── images/
│   └── fonts/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── animations/
│   │   │   ├── animation_presets.dart
│   │   │   └── dakkho_durations.dart
│   │   ├── appwrite/
│   │   │   ├── appwrite_client.dart
│   │   │   ├── auth_service.dart
│   │   │   ├── database_service.dart
│   │   │   ├── storage_service.dart
│   │   │   └── function_service.dart
│   │   ├── livekit/
│   │   │   ├── livekit_service.dart
│   │   │   ├── token_generator.dart
│   │   │   └── room_manager.dart
│   │   ├── upload/
│   │   │   ├── r2_upload_service.dart
│   │   │   ├── upload_manager.dart
│   │   │   └── upload_task.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_typography.dart
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       ├── constants.dart
│   │       ├── extensions.dart
│   │       ├── validators.dart
│   │       └── formatters.dart
│   ├── data/
│   │   ├── models/
│   │   │   ├── course_model.dart
│   │   │   ├── chapter_model.dart
│   │   │   ├── video_model.dart
│   │   │   ├── quiz_model.dart
│   │   │   ├── student_analytics_model.dart
│   │   │   ├── doubt_model.dart
│   │   │   ├── payout_model.dart
│   │   │   ├── live_class_model.dart
│   │   │   └── announcement_model.dart
│   │   ├── providers/
│   │   │   ├── course_provider.dart
│   │   │   ├── video_provider.dart
│   │   │   ├── livekit_provider.dart
│   │   │   ├── quiz_provider.dart
│   │   │   ├── student_provider.dart
│   │   │   ├── doubt_provider.dart
│   │   │   ├── payout_provider.dart
│   │   │   ├── upload_provider.dart
│   │   │   └── announcement_provider.dart
│   │   └── repositories/
│   │       ├── course_repository.dart
│   │       ├── video_repository.dart
│   │       ├── quiz_repository.dart
│   │       ├── student_repository.dart
│   │       ├── doubt_repository.dart
│   │       ├── payout_repository.dart
│   │       ├── livekit_repository.dart
│   │       └── announcement_repository.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── login_page.dart
│   │   │   └── widgets/
│   │   ├── courses/
│   │   │   ├── course_list_page.dart
│   │   │   ├── course_detail_page.dart
│   │   │   ├── chapter_form_page.dart
│   │   │   └── widgets/
│   │   ├── videos/
│   │   │   ├── video_upload_page.dart
│   │   │   ├── video_preview_page.dart
│   │   │   ├── encoding_status_page.dart
│   │   │   └── widgets/
│   │   ├── live_classes/
│   │   │   ├── live_class_list_page.dart
│   │   │   ├── live_class_host_page.dart
│   │   │   ├── schedule_class_page.dart
│   │   │   └── widgets/
│   │   ├── quizzes/
│   │   │   ├── quiz_list_page.dart
│   │   │   ├── quiz_create_page.dart
│   │   │   ├── question_form_page.dart
│   │   │   ├── ai_question_review_page.dart
│   │   │   └── widgets/
│   │   ├── students/
│   │   │   ├── student_analytics_page.dart
│   │   │   ├── student_detail_page.dart
│   │   │   └── widgets/
│   │   ├── doubts/
│   │   │   ├── doubt_list_page.dart
│   │   │   ├── doubt_detail_page.dart
│   │   │   └── widgets/
│   │   ├── payouts/
│   │   │   ├── payout_dashboard_page.dart
│   │   │   ├── payout_detail_page.dart
│   │   │   └── widgets/
│   │   ├── announcements/
│   │   │   ├── announcement_list_page.dart
│   │   │   ├── announcement_form_page.dart
│   │   │   └── widgets/
│   │   ├── community/
│   │   │   ├── community_page.dart
│   │   │   └── widgets/
│   │   └── profile/
│   │       ├── profile_page.dart
│   │       ├── profile_edit_page.dart
│   │       └── widgets/
│   ├── routes/
│   │   ├── app_router.dart
│   │   └── route_guards.dart    # Instructor-only guard
│   └── shared/
│       └── widgets/
│           ├── instructor_scaffold.dart
│           ├── upload_progress_card.dart
│           ├── stat_card.dart
│           ├── live_indicator.dart
│           └── confirmation_dialog.dart
├── test/
├── .env.example
├── .gitignore
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

---

## Build & Release

```bash
# Debug
flutter build apk --debug

# Release
flutter build apk --release

# Play Store
flutter build appbundle --release
```

---

## CI/CD

See `.github/workflows/build-instructor.yml` for automated build pipeline.

---

## License

**Proprietary** — All rights reserved. This source code is confidential and proprietary to GrayRat. Unauthorized copying, distribution, or use is strictly prohibited.

---

<p align="center">
  Empowering BTEB Instructors to Teach Better
</p>
