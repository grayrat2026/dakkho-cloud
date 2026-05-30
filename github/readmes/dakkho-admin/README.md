# DAKKHO Admin

<p align="center">
  <strong>Admin Panel for DAKKHO Platform</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android" alt="Android" />
  <img src="https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge" alt="License" />
</p>

---

## Overview

DAKKHO Admin is the management and control center for the entire DAKKHO educational platform. It provides administrators with full oversight and control over courses, users, payments, content, analytics, and platform configuration — all from a mobile-first Flutter application.

**Package:** `com.grayrat.dakkho.admin.pro.bd`

---

## Features

| Category | Features |
|----------|----------|
| **Dashboard** | Real-time analytics, revenue charts, user growth, active sessions, live class monitor |
| **App Config** | Remote configuration (74+ keys), feature flags, A/B testing, maintenance mode, force update |
| **Course Management** | Full CRUD for courses, chapters, videos; bulk operations; drag-and-drop ordering; publish/draft/unpublish |
| **User Management** | Student/instructor listings, role assignment, account suspension, device audit trail, impersonation (debug) |
| **Payment Monitoring** | Transaction logs, bKash/Nagad/SSLCommerz verification, refund processing, revenue breakdown |
| **Analytics** | Course enrollment stats, video watch time, quiz performance, dropout analysis, revenue trends |
| **Content Moderation** | Community chat moderation, report handling, auto-flag system, ban/suspend users |
| **Instructor Payouts** | Revenue sharing calculator, payout scheduling, payment history, export to CSV |
| **Coupon Management** | Create/edit/deactivate coupons, usage limits, expiry dates, course-specific coupons |
| **Announcements** | Broadcast to all users / specific departments / individual courses; rich text; schedule for later |
| **Live Class Oversight** | View all active classes, participant counts, force-end classes, view recordings |
| **Quiz Oversight** | Review AI-generated questions, edit/approve, negative marking config, difficulty calibration |
| **Notification Management** | Template management, send targeted notifications, schedule campaigns, delivery analytics |
| **Audit Log** | Immutable log of all admin actions, severity levels, filterable by admin/action/date |
| **Subscription Plans** | Create/modify plans, pricing in BDT, trial period config, feature gating rules |

---

## Tech Stack

| Technology | Version | Purpose |
|-----------|---------|---------|
| Flutter | 3.24+ | Cross-platform UI framework |
| Dart | 3.5+ | Programming language |
| Riverpod | 2.0+ | State management |
| Appwrite Cloud | Latest | Backend (Auth, DB, Storage, Functions, Realtime) |
| fl_chart | Latest | Charts and data visualization |
| DataTable2 | Latest | Advanced data tables with sorting/filtering |
| flutter_animate | Latest | UI animations |
| GoRouter | Latest | Declarative routing |
| freezed / json_serializable | Latest | Data class generation |
| intl | Latest | Bengali (bn_BD) localization |
| csv | Latest | Export data to CSV |
| pdf | Latest | Generate PDF reports |
| printing | Latest | Print / share PDF reports |
| share_plus | Latest | Share reports and data |
| url_launcher | Latest | Open external links |
| cached_network_image | Latest | Image caching |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DAKKHO Admin App                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐ │
│  │Dashboard │ │ Courses  │ │  Users   │ │ Payments │ │ Content │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬────┘ │
│       │            │            │            │            │        │
│  ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌────┴────┐ │
│  │Analytics │ │ Payouts  │ │ Coupons  │ │ Announce │ │  Audit  │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬────┘ │
│       │            │            │            │            │        │
│  ═════╪════════════╪════════════╪════════════╪════════════╪══════  │
│       │         PRESENTATION LAYER          │            │        │
│  ═════╪════════════╪════════════╪════════════╪════════════╪══════  │
│       │            │            │            │            │        │
│  ┌────┴────────────┴────────────┴────────────┴────────────┴─────┐ │
│  │                    RIVERPOD PROVIDERS                         │ │
│  │  dashboard_provider │ course_provider │ user_provider │ ...   │ │
│  └──────────────────────────┬───────────────────────────────────┘ │
│                             │                                      │
│  ┌──────────────────────────┴───────────────────────────────────┐ │
│  │                    REPOSITORIES                               │ │
│  │  dashboard_repo │ course_repo │ user_repo │ payment_repo │..│ │
│  └──────────────────────────┬───────────────────────────────────┘ │
│                             │                                      │
│  ┌──────────────────────────┴───────────────────────────────────┐ │
│  │                 APPWRITE CLOUD SDK                            │ │
│  │  Auth │ Database │ Storage │ Functions │ Realtime             │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.24.0 or later
- Dart SDK 3.5.0 or later
- Android Studio / VS Code
- JDK 17
- Admin Appwrite account with `admin` team membership

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/OWNER/dakkho-admin.git
cd dakkho-admin

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
| `ADMIN_TEAM_ID` | Appwrite admin team ID | `your-admin-team-id` |
| `ONESIGNAL_APP_ID` | OneSignal app ID | `your-onesignal-app-id` |
| `RESEND_API_KEY` | Resend email API key | `re_xxxxxxxxxxxx` |

---

## Directory Structure

```
dakkho-admin/
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
│   │   ├── appwrite/
│   │   │   ├── appwrite_client.dart
│   │   │   ├── auth_service.dart
│   │   │   ├── database_service.dart
│   │   │   ├── storage_service.dart
│   │   │   └── function_service.dart
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
│   │   │   ├── dashboard_stats_model.dart
│   │   │   ├── course_model.dart
│   │   │   ├── user_model.dart
│   │   │   ├── payment_model.dart
│   │   │   ├── payout_model.dart
│   │   │   ├── coupon_model.dart
│   │   │   ├── announcement_model.dart
│   │   │   ├── audit_log_model.dart
│   │   │   └── app_config_model.dart
│   │   ├── providers/
│   │   │   ├── dashboard_provider.dart
│   │   │   ├── course_provider.dart
│   │   │   ├── user_provider.dart
│   │   │   ├── payment_provider.dart
│   │   │   ├── payout_provider.dart
│   │   │   ├── coupon_provider.dart
│   │   │   ├── announcement_provider.dart
│   │   │   ├── audit_provider.dart
│   │   │   └── config_provider.dart
│   │   └── repositories/
│   │       ├── dashboard_repository.dart
│   │       ├── course_repository.dart
│   │       ├── user_repository.dart
│   │       ├── payment_repository.dart
│   │       ├── payout_repository.dart
│   │       ├── coupon_repository.dart
│   │       ├── announcement_repository.dart
│   │       ├── audit_repository.dart
│   │       └── config_repository.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── login_page.dart
│   │   │   └── widgets/
│   │   ├── dashboard/
│   │   │   ├── dashboard_page.dart
│   │   │   └── widgets/
│   │   ├── courses/
│   │   │   ├── course_list_page.dart
│   │   │   ├── course_detail_page.dart
│   │   │   ├── course_form_page.dart
│   │   │   └── widgets/
│   │   ├── users/
│   │   │   ├── user_list_page.dart
│   │   │   ├── user_detail_page.dart
│   │   │   └── widgets/
│   │   ├── payments/
│   │   │   ├── payment_list_page.dart
│   │   │   ├── payment_detail_page.dart
│   │   │   └── widgets/
│   │   ├── payouts/
│   │   │   ├── payout_list_page.dart
│   │   │   ├── payout_detail_page.dart
│   │   │   └── widgets/
│   │   ├── coupons/
│   │   │   ├── coupon_list_page.dart
│   │   │   ├── coupon_form_page.dart
│   │   │   └── widgets/
│   │   ├── announcements/
│   │   │   ├── announcement_list_page.dart
│   │   │   ├── announcement_form_page.dart
│   │   │   └── widgets/
│   │   ├── moderation/
│   │   │   ├── moderation_page.dart
│   │   │   ├── report_detail_page.dart
│   │   │   └── widgets/
│   │   ├── analytics/
│   │   │   ├── analytics_page.dart
│   │   │   └── widgets/
│   │   ├── config/
│   │   │   ├── config_page.dart
│   │   │   └── widgets/
│   │   ├── audit/
│   │   │   ├── audit_log_page.dart
│   │   │   └── widgets/
│   │   └── subscriptions/
│   │       ├── plan_list_page.dart
│   │       ├── plan_form_page.dart
│   │       └── widgets/
│   ├── routes/
│   │   ├── app_router.dart
│   │   └── route_guards.dart    # Admin-only guard
│   └── shared/
│       └── widgets/
│           ├── admin_scaffold.dart
│           ├── stat_card.dart
│           ├── data_table.dart
│           ├── action_button.dart
│           └── confirmation_dialog.dart
├── test/
├── .env.example
├── .gitignore
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

---

## Admin Capabilities

| # | Capability | Description |
|---|-----------|-------------|
| 1 | **Dashboard Analytics** | View real-time platform metrics, revenue, user growth, active sessions |
| 2 | **App Configuration** | Manage 74+ remote config keys, feature flags, maintenance mode |
| 3 | **Course CRUD** | Create, read, update, delete courses, chapters, and videos |
| 4 | **Course Publishing** | Publish/unpublish courses, control visibility and access |
| 5 | **User Management** | View all users, assign roles, suspend/activate accounts |
| 6 | **Device Audit** | View device registrations, swap logs, anti-sharing alerts |
| 7 | **Payment Monitoring** | Track all transactions, verify payments, process refunds |
| 8 | **Revenue Analytics** | Revenue by period, payment method, course, department |
| 9 | **Instructor Payouts** | Calculate revenue shares, schedule payouts, track history |
| 10 | **Coupon Management** | Create coupons with usage limits, expiry, course restrictions |
| 11 | **Announcement Broadcast** | Send targeted or global announcements with rich text |
| 12 | **Content Moderation** | Review community reports, ban/suspend users, auto-flag system |
| 13 | **Live Class Oversight** | Monitor active classes, view participants, force-end sessions |
| 14 | **Quiz Review** | Approve AI-generated questions, configure negative marking |
| 15 | **Subscription Plans** | Create/modify pricing tiers, trial periods, feature gates |
| 16 | **Notification Templates** | Create and manage notification templates, schedule campaigns |
| 17 | **Audit Log** | Immutable record of all admin actions with severity levels |
| 18 | **Export Data** | Export reports to CSV/PDF (payments, users, analytics) |
| 19 | **Force Update** | Trigger mandatory app updates via app_config |
| 20 | **Maintenance Mode** | Enable platform-wide maintenance mode with custom message |

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

See `.github/workflows/build-admin.yml` for automated build pipeline.

---

## License

**Proprietary** — All rights reserved. This source code is confidential and proprietary to GrayRat. Unauthorized copying, distribution, or use is strictly prohibited.

---

<p align="center">
  DAKKHO Platform Administration
</p>
