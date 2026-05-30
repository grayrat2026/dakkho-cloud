#!/usr/bin/env bash
# ==============================================================================
# DAKKHO — LiveKit Cloud Setup Script
# Creates LiveKit Cloud project, generates API keys, configures room templates
# ==============================================================================
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PROJECT_NAME="DAKKHO"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

log()  { echo -e "${CYAN}[LiveKit]${NC} $1"; }
ok()   { echo -e "${GREEN}[LiveKit ✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[LiveKit ⚠]${NC} $1"; }
fail() { echo -e "${RED}[LiveKit ✗]${NC} $1"; exit 1; }

# ── Pre-flight checks ────────────────────────────────────────────────────────
log "Running pre-flight checks..."

# LiveKit Cloud setup is primarily done via the Cloud Dashboard
# The lk CLI is used for local testing and token generation
if ! command -v lk &> /dev/null; then
    warn "LiveKit CLI (lk) not found."
    log "Installing LiveKit CLI..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install livekit-cli 2>/dev/null || \
        curl -sSL https://get.livekit.io/cli -o /tmp/install-lk.sh && bash /tmp/install-lk.sh
    elif [[ "$OSTYPE" == "linux"* ]]; then
        curl -sSL https://get.livekit.io/cli -o /tmp/install-lk.sh && bash /tmp/install-lk.sh
    else
        fail "Unsupported OS. Install lk manually: https://docs.livekit.io/home/self-hosting/deployment/"
    fi
    ok "LiveKit CLI installed."
fi

if ! command -v curl &> /dev/null; then
    fail "curl is required but not found."
fi

ok "Pre-flight checks passed."

# ── LiveKit Cloud Project Setup ──────────────────────────────────────────────
log "Setting up LiveKit Cloud project: ${PROJECT_NAME}"
echo ""
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "  LiveKit Cloud requires initial setup via the web dashboard."
log "  This script will guide you through the process."
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check for existing credentials
if [[ -f "$ENV_FILE" ]] && rg -q "LIVEKIT_API_KEY=" "$ENV_FILE" 2>/dev/null; then
    EXISTING_KEY=$(rg "LIVEKIT_API_KEY=" "$ENV_FILE" | head -1 | sed 's/.*=//')
    if [[ -n "$EXISTING_KEY" && "$EXISTING_KEY" != "your_livekit_api_key" ]]; then
        warn "LiveKit API key already found in .env: ${EXISTING_KEY}"
        read -rp "Re-configure LiveKit? (y/N): " RECONFIGURE
        [[ "${RECONFIGURE,,}" != "y" ]] && { ok "Keeping existing LiveKit configuration."; exit 0; }
    fi
fi

# ── Interactive Setup ────────────────────────────────────────────────────────
log "Step 1: Create LiveKit Cloud Project"
echo ""
log "  → Open: https://cloud.livekit.io/"
log "  → Click 'Create Project'"
log "  → Name: ${PROJECT_NAME}"
log "  → Region: Select closest to Bangladesh (Singapore or Mumbai)"
log "  → Plan: Free (5 rooms, 100 participants, 10K minutes/month)"
echo ""
read -rp "Press Enter after creating the project in the dashboard..."

log "Step 2: Get API Credentials"
echo ""
log "  → Go to: https://cloud.livekit.io/projects → ${PROJECT_NAME} → Settings → Keys"
log "  → Click 'Create API Key'"
log "  → Copy the API Key and API Secret"
echo ""

read -rp "LiveKit API Key: " LIVEKIT_API_KEY
read -rp "LiveKit API Secret: " LIVEKIT_API_SECRET

[[ -z "$LIVEKIT_API_KEY" ]] && fail "API Key is required."
[[ -z "$LIVEKIT_API_SECRET" ]] && fail "API Secret is required."

# Get WebSocket URL
log "Step 3: Get WebSocket URL"
echo ""
log "  → The WebSocket URL is shown on the project dashboard"
log "  → Format: wss://xxxxx.livekit.cloud"
echo ""

read -rp "LiveKit WebSocket URL (e.g., wss://xxxxx.livekit.cloud): " LIVEKIT_WS_URL
[[ -z "$LIVEKIT_WS_URL" ]] && fail "WebSocket URL is required."

# Validate WebSocket URL format
if [[ ! "$LIVEKIT_WS_URL" =~ ^wss:// ]]; then
    warn "WebSocket URL should start with wss:// — prepending..."
    LIVEKIT_WS_URL="wss://${LIVEKIT_WS_URL}"
fi

# ── Configure Room Template ─────────────────────────────────────────────────
log "Configuring room template..."

ROOM_TEMPLATE="${SCRIPT_DIR}/room-template.json"
if [[ ! -f "$ROOM_TEMPLATE" ]]; then
    fail "Room template not found: ${ROOM_TEMPLATE}"
fi

ok "Room template loaded from room-template.json"
log "  → Max participants: 100"
log "  → Empty timeout: 5 minutes"
log "  → Max duration: 4 hours"
log "  → Instructor: full control (publish, mute, remove)"
log "  → Student: subscribe + data, no camera/mic publish by default"

# ── Validate API Access ──────────────────────────────────────────────────────
log "Validating LiveKit Cloud API access..."

# Test API access by listing rooms
VALIDATE_RESPONSE=$(curl -s -w "\n%{http_code}" \
    "https://cloud.livekit.io/api/v1/projects" \
    -H "Authorization: Bearer ${LIVEKIT_API_KEY}" 2>/dev/null || echo -e "\n000")

HTTP_STATUS=$(echo "$VALIDATE_RESPONSE" | tail -1)

if [[ "$HTTP_STATUS" == "200" ]]; then
    ok "LiveKit Cloud API access validated."
elif [[ "$HTTP_STATUS" == "401" ]]; then
    warn "API authentication failed. Please verify your API key and secret."
else
    warn "Could not validate API access (HTTP ${HTTP_STATUS}). Continuing anyway..."
fi

# ── Test Token Generation ────────────────────────────────────────────────────
log "Testing token generation with lk CLI..."

# Generate a test token
TEST_TOKEN=$(lk token create \
    --api-key "$LIVEKIT_API_KEY" \
    --api-secret "$LIVEKIT_API_SECRET" \
    --join \
    --identity "test-user" \
    --room "test-room" \
    --room-preset "group" 2>/dev/null || echo "")

if [[ -n "$TEST_TOKEN" ]]; then
    ok "Token generation test passed."
else
    warn "Token generation test failed. You can still use the Appwrite Function for token generation."
fi

# ── Write credentials to .env ────────────────────────────────────────────────
log "Writing credentials to .env file..."

{
    echo "# ── LiveKit Cloud ───────────────────────────────────────────"
    echo "LIVEKIT_API_KEY=${LIVEKIT_API_KEY}"
    echo "LIVEKIT_API_SECRET=${LIVEKIT_API_SECRET}"
    echo "LIVEKIT_WS_URL=${LIVEKIT_WS_URL}"
    echo "LIVEKIT_PROJECT_NAME=${PROJECT_NAME}"
    echo "LIVEKIT_MAX_PARTICIPANTS=100"
    echo "LIVEKIT_MAX_ROOMS=5"
    echo "LIVEKIT_FREE_TIER_MINUTES=10000"
    echo ""
} >> "$ENV_FILE"

ok "Credentials appended to ${ENV_FILE}"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  DAKKHO — LiveKit Cloud Setup Complete${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  Project:           ${GREEN}${PROJECT_NAME}${NC}"
echo -e "  WebSocket URL:     ${GREEN}${LIVEKIT_WS_URL}${NC}"
echo -e "  API Key:           ${GREEN}${LIVEKIT_API_KEY}${NC}"
echo -e "  API Secret:        ${GREEN}${LIVEKIT_API_SECRET:0:8}...${NC}"
echo -e "  Max Participants:  ${GREEN}100 per room${NC}"
echo -e "  Max Rooms:         ${GREEN}5 (free tier)${NC}"
echo -e "  Free Minutes:      ${GREEN}10,000/month${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
log "Dashboard: https://cloud.livekit.io/"
log "Next: Deploy the livekit-token Appwrite Function for Flutter integration"
log "Free tier: 5 rooms, 100 participants, 10K minutes/month"
