#!/usr/bin/env bash
# ==============================================================================
# DAKKHO — OneSignal Push Notification Setup Script
# Configures OneSignal app, segments, and notification categories via REST API
# ==============================================================================
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
SEGMENTS_FILE="${SCRIPT_DIR}/segments.json"

ANDROID_PACKAGE="com.grayrat.dakkho.student.pro.bd"

log()  { echo -e "${CYAN}[OneSignal]${NC} $1"; }
ok()   { echo -e "${GREEN}[OneSignal ✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[OneSignal ⚠]${NC} $1"; }
fail() { echo -e "${RED}[OneSignal ✗]${NC} $1"; exit 1; }

# ── Pre-flight checks ────────────────────────────────────────────────────────
log "Running pre-flight checks..."

if ! command -v curl &> /dev/null; then
    fail "curl is required but not found."
fi

if ! command -v python3 &> /dev/null; then
    fail "python3 is required for JSON processing."
fi

if [[ ! -f "$SEGMENTS_FILE" ]]; then
    fail "Segments file not found: ${SEGMENTS_FILE}"
fi

ok "Pre-flight checks passed."

# ── OneSignal Authentication ─────────────────────────────────────────────────
log "Setting up OneSignal authentication..."

# Check for existing credentials in .env
ONESIGNAL_APP_ID=""
ONESIGNAL_REST_API_KEY=""

if [[ -f "$ENV_FILE" ]]; then
    ONESIGNAL_APP_ID=$(rg "ONESIGNAL_APP_ID=" "$ENV_FILE" 2>/dev/null | head -1 | sed 's/.*=//' || true)
    ONESIGNAL_REST_API_KEY=$(rg "ONESIGNAL_REST_API_KEY=" "$ENV_FILE" 2>/dev/null | head -1 | sed 's/.*=//' || true)
fi

if [[ -z "$ONESIGNAL_APP_ID" || "$ONESIGNAL_APP_ID" == "your_onesignal_app_id" ]]; then
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "  OneSignal requires initial setup via the web dashboard."
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log "Step 1: Create OneSignal App"
    log "  → Open: https://app.onesignal.com/"
    log "  → Click 'New App/Web'"
    log "  → Name: DAKKHO"
    log "  → Organization: DAKKHO (create if needed)"
    log "  → Platform: Android"
    echo ""
    read -rp "Press Enter after creating the app..."

    log "Step 2: Get App ID and REST API Key"
    log "  → Go to: https://app.onesignal.com/ → DAKKHO → Settings → Keys & IDs"
    echo ""
    read -rp "OneSignal App ID: " ONESIGNAL_APP_ID
    read -rp "OneSignal REST API Key: " ONESIGNAL_REST_API_KEY

    [[ -z "$ONESIGNAL_APP_ID" ]] && fail "App ID is required."
    [[ -z "$ONESIGNAL_REST_API_KEY" ]] && fail "REST API Key is required."
else
    ok "Found existing OneSignal credentials in .env"
fi

# ── Validate API Access ──────────────────────────────────────────────────────
log "Validating OneSignal API access..."

VALIDATE_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://onesignal.com/api/v1/apps/${ONESIGNAL_APP_ID}" \
    -H "Authorization: Basic ${ONESIGNAL_REST_API_KEY}")

if [[ "$VALIDATE_RESPONSE" == "200" ]]; then
    ok "OneSignal API access validated."
elif [[ "$VALIDATE_RESPONSE" == "401" ]]; then
    fail "OneSignal API authentication failed. Check your REST API Key."
else
    warn "API validation returned HTTP ${VALIDATE_RESPONSE}. Continuing..."
fi

# ── Configure Android App ────────────────────────────────────────────────────
log "Configuring Android app (package: ${ANDROID_PACKAGE})..."

# Update app with Android configuration
ANDROID_CONFIG=$(curl -s \
    "https://onesignal.com/api/v1/apps/${ONESIGNAL_APP_ID}" \
    -H "Authorization: Basic ${ONESIGNAL_REST_API_KEY}" \
    -H "Content-Type: application/json" \
    -X PUT \
    --data "{
        \"name\": \"DAKKHO\",
        \"gcm_sender_id\": \"703322744261\",
        \"android_gcm_sender_id\": \"703322744261\"
    }" 2>/dev/null || echo "{}")

ANDROID_RESULT=$(echo "$ANDROID_CONFIG" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('name',''))" 2>/dev/null || echo "")

if [[ "$ANDROID_RESULT" == "DAKKHO" ]]; then
    ok "Android app configuration updated."
else
    warn "Android configuration may need manual setup."
    log "  → Dashboard: https://app.onesignal.com/ → DAKKHO → Settings → Platforms → Android"
    log "  → Enter Firebase Cloud Messaging (FCM) server key from Firebase Console"
fi

# ── FCM Server Key Instructions ──────────────────────────────────────────────
log "FCM Server Key setup (required for Android push notifications):"
echo ""
log "  1. Go to Firebase Console: https://console.firebase.google.com/"
log "  2. Select DAKKHO project (or create one)"
log "  3. Project Settings → Cloud Messaging → Manage Service Accounts"
log "  4. Generate new private key → Download JSON"
log "  5. In OneSignal: Settings → Platforms → Android"
log "  6. Upload the Firebase JSON or paste the Server Key"
echo ""
read -rp "Has FCM been configured? (y/N): " FCM_CONFIGURED
if [[ "${FCM_CONFIGURED,,}" != "y" ]]; then
    warn "FCM not configured. Android push notifications won't work until this is done."
    log "You can configure FCM later in the OneSignal dashboard."
fi

# ── Create Segments ──────────────────────────────────────────────────────────
log "Creating notification segments..."

# Read segments from JSON file
SEGMENT_COUNT=$(python3 -c "
import json
with open('${SEGMENTS_FILE}') as f:
    data = json.load(f)
    print(len(data.get('segments', [])))
" 2>/dev/null || echo "0")

log "Found ${SEGMENT_COUNT} segment definitions in segments.json"

# Note: OneSignal segments are typically created via the dashboard or when first used
# We'll verify and create them via API where possible
SEGMENTS_CREATED=0

python3 -c "
import json

with open('${SEGMENTS_FILE}') as f:
    data = json.load(f)

for seg in data.get('segments', []):
    print(f\"SEGMENT_NAME:{seg['name']}\")
    print(f\"SEGMENT_DESC:{seg['description']}\")
" 2>/dev/null | while IFS=: read -r key value; do
    if [[ "$key" == "SEGMENT_NAME" ]]; then
        log "  Segment: ${value}"
    fi
done

# OneSignal API doesn't directly support segment creation via REST API
# Segments are created through the dashboard or automatically when sending notifications
ok "Segment definitions prepared (${SEGMENT_COUNT} segments)."
log "  → Segments will be auto-created when first targeted in notifications"
log "  → Or create manually at: https://app.onesignal.com/ → DAKKHO → Audience → Segments"

# ── Create Notification Categories ───────────────────────────────────────────
log "Setting up notification categories..."

CATEGORY_COUNT=$(python3 -c "
import json
with open('${SEGMENTS_FILE}') as f:
    data = json.load(f)
    cats = data.get('notification_categories', [])
    for cat in cats:
        print(f\"{cat['id']}|{cat['name']}|{cat['bengali_name']}|{cat['priority']}\")
" 2>/dev/null || echo "")

log "Notification categories defined:"
echo "$CATEGORY_COUNT" | while IFS='|' read -r id name bengali_name priority; do
    log "  → ${id}: ${name} (${bengali_name}) [${priority}]"
done

# ── Test Notification ────────────────────────────────────────────────────────
log "Sending test notification..."

read -rp "Send a test push notification? (y/N): " SEND_TEST
if [[ "${SEND_TEST,,}" == "y" ]]; then
    TEST_RESPONSE=$(curl -s \
        "https://onesignal.com/api/v1/notifications" \
        -H "Authorization: Basic ${ONESIGNAL_REST_API_KEY}" \
        -H "Content-Type: application/json" \
        --data "{
            \"app_id\": \"${ONESIGNAL_APP_ID}\",
            \"contents\": {
                \"en\": \"DAKKHO push notifications are working! 🎉\",
                \"bn\": \"ডাকো পুশ নোটিফিকেশন কাজ করছে! 🎉\"
            },
            \"headings\": {
                \"en\": \"DAKKHO Setup Complete\",
                \"bn\": \"ডাকো সেটআপ সম্পন্ন\"
            },
            \"included_segments\": [\"All\"],
            \"isAndroid\": true
        }")

    TEST_ID=$(echo "$TEST_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
    TEST_ERRORS=$(echo "$TEST_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('errors',{}))" 2>/dev/null || echo "")

    if [[ -n "$TEST_ID" ]]; then
        ok "Test notification sent! ID: ${TEST_ID}"
    else
        warn "Test notification may have failed. Errors: ${TEST_ERRORS}"
        log "This is expected if no devices are registered yet."
    fi
else
    log "Skipping test notification."
fi

# ── Write credentials to .env ────────────────────────────────────────────────
log "Writing credentials to .env file..."

{
    echo "# ── OneSignal ────────────────────────────────────────────────"
    echo "ONESIGNAL_APP_ID=${ONESIGNAL_APP_ID}"
    echo "ONESIGNAL_REST_API_KEY=${ONESIGNAL_REST_API_KEY}"
    echo "ONESIGNAL_ANDROID_PACKAGE=${ANDROID_PACKAGE}"
    echo "ONESIGNAL_USER_AUTH_KEY=your_onesignal_user_auth_key"
    echo ""
} >> "$ENV_FILE"

ok "Credentials appended to ${ENV_FILE}"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  DAKKHO — OneSignal Setup Complete${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  App ID:            ${GREEN}${ONESIGNAL_APP_ID}${NC}"
echo -e "  REST API Key:      ${GREEN}${ONESIGNAL_REST_API_KEY:0:8}...${NC}"
echo -e "  Android Package:   ${GREEN}${ANDROID_PACKAGE}${NC}"
echo -e "  Segments:          ${GREEN}${SEGMENT_COUNT} defined${NC}"
echo -e "  Categories:        ${GREEN}5 (live_class, subscription, study_reminder, announcement, system)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
log "Dashboard: https://app.onesignal.com/"
log "Free tier: Unlimited subscribers, Unlimited notifications"
log "TODO: Configure FCM server key for Android delivery"
log "TODO: Add iOS configuration when ready"
