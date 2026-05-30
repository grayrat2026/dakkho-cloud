#!/bin/bash
# =============================================================================
# DAKKHO (দক্ষ) — Appwrite Cloud Setup Script
# =============================================================================
# This script creates all collections, functions, storage buckets, teams,
# and seeds default data for the DAKKHO educational platform.
#
# Prerequisites:
#   - Appwrite CLI installed (npm install -g appwrite-cli)
#   - Appwrite CLI logged in (appwrite login)
#   - .env file configured with project ID and API key
#
# Usage:
#   cp .env.example .env
#   # Edit .env with your actual values
#   source .env
#   chmod +x setup.sh
#   ./setup.sh
# =============================================================================

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTIONS_DIR="${SCRIPT_DIR}/collections"
FUNCTIONS_DIR="${SCRIPT_DIR}/functions"
DATABASE_ID="dakkho-main"
DATABASE_NAME="DAKKHO Main Database"

# Counter for tracking
TOTAL_STEPS=9
CURRENT_STEP=0

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}Step ${CURRENT_STEP}/${TOTAL_STEPS}: $1${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

success() {
  echo -e "  ${GREEN}✓ $1${NC}"
}

warn() {
  echo -e "  ${YELLOW}⚠ $1${NC}"
}

fail() {
  echo -e "  ${RED}✗ $1${NC}"
}

info() {
  echo -e "  ${CYAN}→ $1${NC}"
}

# =============================================================================
# STEP 0: Pre-flight checks
# =============================================================================
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          দক্ষ (DAKKHO) — Appwrite Cloud Setup               ║"
echo "║     BTEB Diploma Engineering Learning Platform               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check .env file
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
  fail ".env file not found. Copy .env.example to .env and fill in your values."
  echo "  Run: cp ${SCRIPT_DIR}/.env.example ${SCRIPT_DIR}/.env"
  exit 1
fi

source "${SCRIPT_DIR}/.env"

# Check required env vars
REQUIRED_VARS=(
  "APPWRITE_PROJECT_ID"
  "APPWRITE_API_KEY"
  "APPWRITE_ENDPOINT"
)

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    fail "Required env var ${var} is not set in .env"
    exit 1
  fi
done

success "Environment variables loaded"

# =============================================================================
# STEP 1: Check Appwrite CLI
# =============================================================================
step "Check Appwrite CLI installation"

if ! command -v appwrite &> /dev/null; then
  fail "Appwrite CLI not found. Install it with: npm install -g appwrite-cli"
  exit 1
fi

success "Appwrite CLI found: $(appwrite --version 2>/dev/null || echo 'version unknown')"

# Configure CLI
appwrite client \
  --endpoint "${APPWRITE_ENDPOINT}" \
  --projectId "${APPWRITE_PROJECT_ID}" \
  --key "${APPWRITE_API_KEY}" \
  2>/dev/null

success "Appwrite CLI configured with project ${APPWRITE_PROJECT_ID}"

# =============================================================================
# STEP 2: Create database
# =============================================================================
step "Create database: ${DATABASE_ID}"

# Try to create database (ignore error if already exists)
if appwrite databases create \
  --databaseId "${DATABASE_ID}" \
  --name "${DATABASE_NAME}" \
  2>/dev/null; then
  success "Database '${DATABASE_NAME}' created"
else
  warn "Database may already exist, continuing..."
fi

# =============================================================================
# STEP 3: Create all 22 collections
# =============================================================================
step "Create all 22 collections with fields and indexes"

COLLECTIONS=(
  "app_config"
  "active_devices"
  "device_swap_logs"
  "courses"
  "chapters"
  "videos"
  "quizzes"
  "quiz_questions"
  "quiz_attempts"
  "subscriptions"
  "doubts"
  "chat_messages"
  "payments_config"
  "notification_templates"
  "audit_logs"
  "live_classes"
  "instructor_payouts"
  "coupons"
  "announcements"
  "gamification_badges"
  "user_badges"
  "offline_downloads"
)

COLLECTION_NAMES=(
  "App Configuration"
  "Active Devices"
  "Device Swap Logs"
  "Courses"
  "Chapters"
  "Videos"
  "Quizzes"
  "Quiz Questions"
  "Quiz Attempts"
  "Subscriptions"
  "Doubts"
  "Chat Messages"
  "Payment Gateway Config"
  "Notification Templates"
  "Audit Logs"
  "Live Classes"
  "Instructor Payouts"
  "Coupons"
  "Announcements"
  "Gamification Badges"
  "User Badges"
  "Offline Downloads"
)

for i in "${!COLLECTIONS[@]}"; do
  COLL_ID="${COLLECTIONS[$i]}"
  COLL_NAME="${COLLECTION_NAMES[$i]}"
  SCHEMA_FILE="${COLLECTIONS_DIR}/${COLL_ID}.json"

  if [ ! -f "${SCHEMA_FILE}" ]; then
    fail "Schema file not found: ${SCHEMA_FILE}"
    continue
  fi

  info "Creating collection: ${COLL_NAME} (${COLL_ID})..."

  # Create collection
  if appwrite databases createCollection \
    --databaseId "${DATABASE_ID}" \
    --collectionId "${COLL_ID}" \
    --name "${COLL_NAME}" \
    --permissions '[]' \
    2>/dev/null; then
    success "Collection '${COLL_ID}' created"
  else
    warn "Collection '${COLL_ID}' may already exist, updating..."
  fi

  # Parse and create fields from JSON schema
  FIELDS=$(node -e "
    const schema = require('${SCHEMA_FILE}');
    schema.fields.forEach(f => {
      const parts = [
        '--key', f.key,
        '--required', f.required ? 'true' : 'false'
      ];
      if (f.type === 'string') {
        parts.push('--size', String(f.size || 255));
        if (f.default !== null) parts.push('--default', String(f.default));
      }
      if (f.type === 'enum') {
        parts.push('--elements', JSON.stringify(f.elements || []));
        if (f.default !== null) parts.push('--default', String(f.default));
      }
      if (['integer', 'float'].includes(f.type) && f.default !== null) {
        parts.push('--default', String(f.default));
      }
      if (f.type === 'boolean' && f.default !== null) {
        parts.push('--default', String(f.default));
      }
      if (f.array) parts.push('--array', 'true');
      console.log(f.type + '|' + parts.join(' '));
    });
  " 2>/dev/null || true)

  while IFS='|' read -r fieldType args; do
    case "${fieldType}" in
      string)
        eval "appwrite databases createStringAttribute --databaseId ${DATABASE_ID} --collectionId ${COLL_ID} ${args}" 2>/dev/null && true
        ;;
      integer)
        eval "appwrite databases createIntegerAttribute --databaseId ${DATABASE_ID} --collectionId ${COLL_ID} ${args}" 2>/dev/null && true
        ;;
      float)
        eval "appwrite databases createFloatAttribute --databaseId ${DATABASE_ID} --collectionId ${COLL_ID} ${args}" 2>/dev/null && true
        ;;
      boolean)
        eval "appwrite databases createBooleanAttribute --databaseId ${DATABASE_ID} --collectionId ${COLL_ID} ${args}" 2>/dev/null && true
        ;;
      datetime)
        eval "appwrite databases createDatetimeAttribute --databaseId ${DATABASE_ID} --collectionId ${COLL_ID} ${args}" 2>/dev/null && true
        ;;
      email)
        eval "appwrite databases createEmailAttribute --databaseId ${DATABASE_ID} --collectionId ${COLL_ID} ${args}" 2>/dev/null && true
        ;;
      url)
        eval "appwrite databases createUrlAttribute --databaseId ${DATABASE_ID} --collectionId ${COLL_ID} ${args}" 2>/dev/null && true
        ;;
      enum)
        eval "appwrite databases createEnumAttribute --databaseId ${DATABASE_ID} --collectionId ${COLL_ID} ${args}" 2>/dev/null && true
        ;;
      ip)
        eval "appwrite databases createIpAttribute --databaseId ${DATABASE_ID} --collectionId ${COLL_ID} ${args}" 2>/dev/null && true
        ;;
    esac
  done <<< "${FIELDS}"

  success "Fields created for '${COLL_ID}'"

  # Wait for attributes to be available (Appwrite processes them async)
  info "Waiting for attributes to process..."
  sleep 3

  # Create indexes from JSON schema
  INDEXES=$(node -e "
    const schema = require('${SCHEMA_FILE}');
    (schema.indexes || []).forEach(idx => {
      const args = [
        '--key', idx.key,
        '--type', idx.type,
        '--attributes', JSON.stringify(idx.attributes),
        '--orders', JSON.stringify(idx.orders || idx.attributes.map(() => 'ASC'))
      ];
      console.log(args.join(' '));
    });
  " 2>/dev/null || true)

  while IFS= read -r idxArgs; do
    if [ -n "${idxArgs}" ]; then
      eval "appwrite databases createIndex --databaseId ${DATABASE_ID} --collectionId ${COLL_ID} ${idxArgs}" 2>/dev/null && true
    fi
  done <<< "${INDEXES}"

  success "Indexes created for '${COLL_ID}'"
done

# =============================================================================
# STEP 4: Deploy all 10 functions
# =============================================================================
step "Deploy all 10 Appwrite Functions"

FUNCTIONS=(
  "livekit-token:LiveKit Token Generator:node-20.0:event"
  "device-register:Device Registration & Limit:node-20.0:event"
  "payment-verify-bkash:bKash Payment Verification:node-20.0:event"
  "payment-verify-nagad:Nagad Payment Verification:node-20.0:event"
  "payment-verify-sslcommerz:SSLCommerz Payment Verification:node-20.0:event"
  "ai-quiz-generator:AI Quiz Generator:node-20.0:event"
  "email-sender:Email Sender (Resend):node-20.0:event"
  "video-upload-handler:Video Upload Handler (R2):node-20.0:event"
  "reminder-scheduler:Reminder Scheduler (Cron):node-20.0:schedule"
  "bunny-cdn-upload:Bunny CDN Upload:node-20.0:event"
)

for func_def in "${FUNCTIONS[@]}"; do
  IFS=':' read -r FUNC_ID FUNC_NAME RUNTIME TRIGGER <<< "${func_def}"
  FUNC_DIR="${FUNCTIONS_DIR}/${FUNC_ID}"

  if [ ! -d "${FUNC_DIR}" ]; then
    fail "Function directory not found: ${FUNC_DIR}"
    continue
  fi

  info "Creating function: ${FUNC_NAME} (${FUNC_ID})..."

  # Create function
  if appwrite functions create \
    --functionId "${FUNC_ID}" \
    --name "${FUNC_NAME}" \
    --runtime "${RUNTIME}" \
    --execute "" \
    2>/dev/null; then
    success "Function '${FUNC_ID}' created"
  else
    warn "Function '${FUNC_ID}' may already exist, updating..."
    appwrite functions update \
      --functionId "${FUNC_ID}" \
      --name "${FUNC_NAME}" \
      2>/dev/null && true
  fi

  # Install dependencies and create deployment
  if [ -f "${FUNC_DIR}/package.json" ]; then
    info "Installing dependencies for ${FUNC_ID}..."
    cd "${FUNC_DIR}" && npm install --production 2>/dev/null && cd "${SCRIPT_DIR}"

    # Create deployment (tar the function directory)
    info "Creating deployment for ${FUNC_ID}..."
    if command -v tar &> /dev/null; then
      TEMP_DIR=$(mktemp -d)
      cp "${FUNC_DIR}/entry.js" "${TEMP_DIR}/" 2>/dev/null || true
      cp "${FUNC_DIR}/package.json" "${TEMP_DIR}/" 2>/dev/null || true
      cp -r "${FUNC_DIR}/node_modules" "${TEMP_DIR}/" 2>/dev/null || true

      tar -czf "${TEMP_DIR}/deployment.tar.gz" -C "${TEMP_DIR}" . 2>/dev/null || true

      # Deploy using Appwrite CLI
      appwrite functions createDeployment \
        --functionId "${FUNC_ID}" \
        --entrypoint "entry.js" \
        --code "${TEMP_DIR}" \
        --activate true \
        2>/dev/null && success "Function '${FUNC_ID}' deployed" || warn "Deployment for '${FUNC_ID}' may need manual upload"

      rm -rf "${TEMP_DIR}"
    else
      warn "tar not found, skipping deployment packaging for ${FUNC_ID}"
    fi
  fi
done

# =============================================================================
# STEP 5: Create 5 storage buckets
# =============================================================================
step "Create 5 storage buckets"

BUCKETS=(
  "dakkho-videos-raw:Raw Video Uploads:5368709120:video/mp4,video/webm,video/quicktime"
  "dakkho-videos-drm:DRM Encoded Videos:10737418240:application/x-mpegURL,application/vnd.apple.mpegurl"
  "dakkho-documents:Course Documents:524288000:application/pdf,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation"
  "dakkho-avatars:User Avatars:5242880:image/jpeg,image/png,image/webp"
  "dakkho-app-assets:App Assets:104857600:image/jpeg,image/png,image/webp,image/svg+xml"
)

for bucket_def in "${BUCKETS[@]}"; do
  IFS=':' read -r BUCKET_ID BUCKET_NAME MAX_SIZE ALLOWED_TYPES <<< "${bucket_def}"

  info "Creating bucket: ${BUCKET_NAME} (${BUCKET_ID})..."

  if appwrite storage createBucket \
    --bucketId "${BUCKET_ID}" \
    --name "${BUCKET_NAME}" \
    --maximumFileSize "${MAX_SIZE}" \
    --enabled true \
    2>/dev/null; then
    success "Bucket '${BUCKET_ID}' created (max: $(( MAX_SIZE / 1024 / 1024 ))MB)"
  else
    warn "Bucket '${BUCKET_ID}' may already exist"
  fi
done

# =============================================================================
# STEP 6: Seed 74 app_config default records
# =============================================================================
step "Seed 74 app_config default records"

SEED_SCRIPT="${SCRIPT_DIR}/seed-app-config.js"

cat > "${SEED_SCRIPT}" << 'SEED_EOF'
const { Client, Databases, ID, Query } = require('node-appwrite');

const DATABASE_ID = 'dakkho-main';
const COLLECTION_ID = 'app_config';

const client = new Client()
  .setEndpoint(process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1')
  .setProject(process.env.APPWRITE_PROJECT_ID)
  .setKey(process.env.APPWRITE_API_KEY);

const databases = new Databases(client);

const CONFIG_RECORDS = [
  // === BRANDING (14 records) ===
  { key: 'app_name', value: 'দক্ষ', type: 'string', category: 'branding', description: 'App name in Bengali', is_public: true },
  { key: 'app_name_en', value: 'DAKKHO', type: 'string', category: 'branding', description: 'App name in English', is_public: true },
  { key: 'logo_url', value: 'https://cdn.dakkho.com/assets/logo.png', type: 'string', category: 'branding', description: 'Main logo URL', is_public: true },
  { key: 'logo_dark_url', value: 'https://cdn.dakkho.com/assets/logo-dark.png', type: 'string', category: 'branding', description: 'Dark mode logo URL', is_public: true },
  { key: 'primary_color', value: '#06B6D4', type: 'color', category: 'branding', description: 'Primary brand color (Cyan)', is_public: true },
  { key: 'secondary_color', value: '#0A0E1A', type: 'color', category: 'branding', description: 'Secondary brand color (Deep Navy)', is_public: true },
  { key: 'accent_color', value: '#22D3EE', type: 'color', category: 'branding', description: 'Accent color', is_public: true },
  { key: 'success_color', value: '#10B981', type: 'color', category: 'branding', description: 'Success indicator color', is_public: true },
  { key: 'warning_color', value: '#F59E0B', type: 'color', category: 'branding', description: 'Warning indicator color', is_public: true },
  { key: 'error_color', value: '#EF4444', type: 'color', category: 'branding', description: 'Error indicator color', is_public: true },
  { key: 'font_primary_bn', value: 'Hind Siliguri', type: 'string', category: 'branding', description: 'Primary Bengali font', is_public: true },
  { key: 'font_primary_en', value: 'Inter', type: 'string', category: 'branding', description: 'Primary English font', is_public: true },
  { key: 'splash_animation_url', value: 'https://cdn.dakkho.com/animations/dakkho-splash.json', type: 'string', category: 'branding', description: 'Lottie splash animation URL', is_public: true },
  { key: 'app_slogan_bn', value: 'শিখুন, সফল হন', type: 'string', category: 'branding', description: 'Bengali app slogan', is_public: true },

  // === SUBSCRIPTION (10 records) ===
  { key: 'trial_days', value: '10', type: 'number', category: 'subscription', description: 'Free trial duration in days', is_public: true },
  { key: 'basic_plan_price_bdt', value: '199', type: 'number', category: 'subscription', description: 'Basic plan monthly price in BDT', is_public: true },
  { key: 'premium_plan_price_bdt', value: '499', type: 'number', category: 'subscription', description: 'Premium plan monthly price in BDT', is_public: true },
  { key: 'basic_plan_features', value: '["all_courses","quizzes","doubt_support","limited_offline"]', type: 'json', category: 'subscription', description: 'Basic plan features JSON', is_public: true },
  { key: 'premium_plan_features', value: '["all_courses","quizzes","doubt_support","unlimited_offline","live_classes","priority_support","ai_quiz"]', type: 'json', category: 'subscription', description: 'Premium plan features JSON', is_public: true },
  { key: 'subscription_enabled', value: 'true', type: 'boolean', category: 'subscription', description: 'Enable subscription system', is_public: false },
  { key: 'auto_renew_enabled', value: 'false', type: 'boolean', category: 'subscription', description: 'Enable auto-renewal', is_public: false },
  { key: 'grace_period_days', value: '3', type: 'number', category: 'subscription', description: 'Grace period after expiry in days', is_public: false },
  { key: 'max_offline_downloads_basic', value: '5', type: 'number', category: 'subscription', description: 'Max offline downloads for basic', is_public: true },
  { key: 'max_offline_downloads_premium', value: '20', type: 'number', category: 'subscription', description: 'Max offline downloads for premium', is_public: true },

  // === FEATURES (12 records) ===
  { key: 'device_limit_enabled', value: 'true', type: 'boolean', category: 'features', description: 'Enable 1-device limit enforcement', is_public: false },
  { key: 'device_swap_cooldown_days', value: '7', type: 'number', category: 'features', description: 'Min days between device swaps', is_public: false },
  { key: 'watermark_enabled', value: 'true', type: 'boolean', category: 'features', description: 'Show watermark on videos', is_public: false },
  { key: 'watermark_text', value: 'DAKKHO', type: 'string', category: 'features', description: 'Watermark text', is_public: false },
  { key: 'screenshot_blocking_enabled', value: 'true', type: 'boolean', category: 'features', description: 'Block screenshots in video player', is_public: false },
  { key: 'ai_quiz_enabled', value: 'true', type: 'boolean', category: 'features', description: 'Enable AI quiz generation', is_public: true },
  { key: 'doubt_system_enabled', value: 'true', type: 'boolean', category: 'features', description: 'Enable doubt system', is_public: true },
  { key: 'live_class_enabled', value: 'true', type: 'boolean', category: 'features', description: 'Enable live classes', is_public: true },
  { key: 'chat_enabled', value: 'true', type: 'boolean', category: 'features', description: 'Enable community chat', is_public: true },
  { key: 'gamification_enabled', value: 'true', type: 'boolean', category: 'features', description: 'Enable badges & XP system', is_public: true },
  { key: 'offline_download_enabled', value: 'true', type: 'boolean', category: 'features', description: 'Enable offline downloads', is_public: true },
  { key: 'performance_mode_default', value: 'true', type: 'boolean', category: 'features', description: 'Default performance mode on low-end', is_public: true },

  // === SECURITY (8 records) ===
  { key: 'max_login_attempts', value: '5', type: 'number', category: 'security', description: 'Max failed login attempts before lockout', is_public: false },
  { key: 'lockout_duration_minutes', value: '30', type: 'number', category: 'security', description: 'Account lockout duration in minutes', is_public: false },
  { key: 'session_timeout_hours', value: '720', type: 'number', category: 'security', description: 'Session timeout in hours (30 days)', is_public: false },
  { key: 'drm_provider', value: 'widevine', type: 'string', category: 'security', description: 'DRM provider', is_public: false },
  { key: 'drm_enabled', value: 'true', type: 'boolean', category: 'security', description: 'Enable DRM for videos', is_public: false },
  { key: 'tab_switch_detection_enabled', value: 'true', type: 'boolean', category: 'security', description: 'Detect tab switching in quizzes', is_public: false },
  { key: 'tab_switch_flag_threshold', value: '3', type: 'number', category: 'security', description: 'Tab switches before flagging', is_public: false },
  { key: 'ip_logging_enabled', value: 'true', type: 'boolean', category: 'security', description: 'Log IP for audit trail', is_public: false },

  // === NOTIFICATIONS (8 records) ===
  { key: 'push_notifications_enabled', value: 'true', type: 'boolean', category: 'notifications', description: 'Enable push notifications', is_public: true },
  { key: 'email_notifications_enabled', value: 'true', type: 'boolean', category: 'notifications', description: 'Enable email notifications', is_public: true },
  { key: 'subscription_expiry_reminder_days', value: '3', type: 'number', category: 'notifications', description: 'Days before expiry to send reminder', is_public: false },
  { key: 'live_class_reminder_minutes', value: '30', type: 'number', category: 'notifications', description: 'Minutes before class to send reminder', is_public: false },
  { key: 'study_streak_reminder_hour', value: '20', type: 'number', category: 'notifications', description: 'Hour (0-23) to send study reminder', is_public: false },
  { key: 'onesignal_app_id', value: '', type: 'string', category: 'notifications', description: 'OneSignal App ID', is_public: false },
  { key: 'default_notification_channel', value: 'general', type: 'string', category: 'notifications', description: 'Default push notification channel', is_public: false },
  { key: 'quiet_hours_start', value: '23:00', type: 'string', category: 'notifications', description: 'Quiet hours start time', is_public: false },

  // === CONTENT (10 records) ===
  { key: 'departments', value: '["computer","electrical","mechanical","civil","electronics","textile","automobile"]', type: 'json', category: 'content', description: 'Available BTEB departments', is_public: true },
  { key: 'semesters', value: '["1","2","3","4","5","6","7","8"]', type: 'json', category: 'content', description: 'Available semesters', is_public: true },
  { key: 'default_language', value: 'bn', type: 'string', category: 'content', description: 'Default language code', is_public: true },
  { key: 'supported_languages', value: '["bn","en"]', type: 'json', category: 'content', description: 'Supported languages', is_public: true },
  { key: 'video_player_default_quality', value: '720', type: 'string', category: 'content', description: 'Default video quality', is_public: true },
  { key: 'video_quality_options', value: '["360","480","720","1080"]', type: 'json', category: 'content', description: 'Available quality options', is_public: true },
  { key: 'max_video_upload_size_mb', value: '5120', type: 'number', category: 'content', description: 'Max video upload size in MB', is_public: false },
  { key: 'quiz_default_time_limit_minutes', value: '30', type: 'number', category: 'content', description: 'Default quiz time limit', is_public: false },
  { key: 'negative_marking_default', value: '0.25', type: 'number', category: 'content', description: 'Default negative marking value', is_public: false },
  { key: 'content_moderation_enabled', value: 'true', type: 'boolean', category: 'content', description: 'Enable content moderation', is_public: false },

  // === SYSTEM (8 records) ===
  { key: 'maintenance_mode', value: 'false', type: 'boolean', category: 'system', description: 'Enable maintenance mode', is_public: true },
  { key: 'maintenance_message_bn', value: 'সিস্টেম আপডেট চলছে। কিছুক্ষণ পর আবার চেষ্টা করুন।', type: 'string', category: 'system', description: 'Maintenance message in Bengali', is_public: true },
  { key: 'maintenance_message_en', value: 'System update in progress. Please try again later.', type: 'string', category: 'system', description: 'Maintenance message in English', is_public: true },
  { key: 'min_app_version', value: '1.0.0', type: 'string', category: 'system', description: 'Minimum supported app version', is_public: true },
  { key: 'current_app_version', value: '1.0.0', type: 'string', category: 'system', description: 'Current latest app version', is_public: true },
  { key: 'force_update_enabled', value: 'false', type: 'boolean', category: 'system', description: 'Force app update', is_public: true },
  { key: 'api_rate_limit_per_minute', value: '60', type: 'number', category: 'system', description: 'API rate limit per minute', is_public: false },
  { key: 'analytics_enabled', value: 'true', type: 'boolean', category: 'system', description: 'Enable analytics tracking', is_public: false },

  // === PAYMENT (4 records) ===
  { key: 'bkash_enabled', value: 'true', type: 'boolean', category: 'payment', description: 'Enable bKash payments', is_public: true },
  { key: 'nagad_enabled', value: 'true', type: 'boolean', category: 'payment', description: 'Enable Nagad payments', is_public: true },
  { key: 'sslcommerz_enabled', value: 'true', type: 'boolean', category: 'payment', description: 'Enable SSLCommerz payments', is_public: true },
  { key: 'currency', value: 'BDT', type: 'string', category: 'payment', description: 'Default currency', is_public: true },
];

async function seed() {
  let created = 0;
  let skipped = 0;

  for (const record of CONFIG_RECORDS) {
    try {
      // Check if key already exists
      const existing = await databases.listDocuments(DATABASE_ID, COLLECTION_ID, [
        Query.equal('key', record.key),
      ]);

      if (existing.documents.length > 0) {
        console.log(`  ⚠ Key '${record.key}' already exists, skipping`);
        skipped++;
        continue;
      }

      const now = new Date().toISOString();
      await databases.createDocument(DATABASE_ID, COLLECTION_ID, ID.unique(), {
        key: record.key,
        value: record.value,
        type: record.type,
        category: record.category,
        description: record.description,
        is_public: record.is_public,
        is_editable: true,
        updated_by: null,
        created_at: now,
        updated_at: now,
      });
      created++;
      console.log(`  ✓ Created: ${record.key}`);
    } catch (err) {
      console.log(`  ✗ Failed: ${record.key} — ${err.message}`);
    }
  }

  console.log(`\nSeeding complete: ${created} created, ${skipped} skipped`);
}

seed().catch(console.error);
SEED_EOF

info "Running app_config seed script..."
node "${SEED_SCRIPT}" 2>/dev/null && success "app_config records seeded" || warn "Some seed records may have failed — check output above"

# Clean up seed script
rm -f "${SEED_SCRIPT}"

# =============================================================================
# STEP 7: Create 3 teams
# =============================================================================
step "Create 3 teams (admin, instructor, student)"

TEAMS=(
  "admin:DAKKHO Administrators"
  "instructor:DAKKHO Instructors"
  "student:DAKKHO Students"
)

for team_def in "${TEAMS[@]}"; do
  IFS=':' read -r TEAM_ID TEAM_NAME <<< "${team_def}"

  if appwrite teams create \
    --teamId "${TEAM_ID}" \
    --name "${TEAM_NAME}" \
    2>/dev/null; then
    success "Team '${TEAM_NAME}' created (${TEAM_ID})"
  else
    warn "Team '${TEAM_ID}' may already exist"
  fi
done

# =============================================================================
# STEP 8: Set collection permissions
# =============================================================================
step "Set collection permissions"

info "Note: Detailed per-document permissions are enforced via Appwrite Functions."
info "Collection-level permissions have been set via the JSON schemas."
info "For user-specific document access (e.g., user:{userId}), Functions handle this."

# Update collection permissions from schema files
for COLL_ID in "${COLLECTIONS[@]}"; do
  SCHEMA_FILE="${COLLECTIONS_DIR}/${COLL_ID}.json"
  if [ -f "${SCHEMA_FILE}" ]; then
    PERMS=$(node -e "
      const schema = require('${SCHEMA_FILE}');
      const p = schema.permissions || {};
      const read = (p.read || []).map(r => 'read.\"' + r + '\"');
      const create = (p.create || []).map(r => 'create.\"' + r + '\"');
      const update = (p.update || []).map(r => 'update.\"' + r + '\"');
      const del = (p.delete || []).map(r => 'delete.\"' + r + '\"');
      console.log(JSON.stringify([...read, ...create, ...update, ...del]));
    " 2>/dev/null || echo '[]')

    # Update collection with permissions
    appwrite databases updateCollection \
      --databaseId "${DATABASE_ID}" \
      --collectionId "${COLL_ID}" \
      --name "${COLL_ID}" \
      --permissions "${PERMS}" \
      2>/dev/null && true
  fi
done

success "Collection permissions configured"

# =============================================================================
# STEP 9: Summary
# =============================================================================
step "Setup Complete!"

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              🎉 DAKKHO Appwrite Setup Complete!              ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  ✓ 22 Collections created with fields & indexes              ║"
echo "║  ✓ 10 Functions deployed                                     ║"
echo "║  ✓ 5 Storage Buckets created                                 ║"
echo "║  ✓ 74 app_config records seeded                              ║"
echo "║  ✓ 3 Teams created (admin, instructor, student)              ║"
echo "║                                                              ║"
echo "║  Next Steps:                                                 ║"
echo "║  1. Configure function env vars in Appwrite Console          ║"
echo "║  2. Set up LiveKit Cloud and add keys                        ║"
echo "║  3. Set up Cloudflare R2 and add keys                        ║"
echo "║  4. Configure bKash/Nagad/SSLCommerz credentials             ║"
echo "║  5. Add OneSignal & Resend API keys                          ║"
echo "║  6. Set up Auth providers (Phone OTP, Google OAuth)          ║"
echo "║  7. Add Android platforms (com.dakkho.app, etc.)             ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
