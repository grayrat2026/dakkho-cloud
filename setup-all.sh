#!/usr/bin/env bash
# ==============================================================================
# DAKKHO — Master Cloud Services Setup Script
# Orchestrates setup of all cloud services: R2, LiveKit, OneSignal, Resend
# ==============================================================================
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

log()  { echo -e "${CYAN}[DAKKHO]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[⚠]${NC} $1"; }
fail() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                                                               ${NC}"
echo -e "${CYAN}   ██████╗  █████╗  ██╗  ██╗██╗   ██╗ ██████╗ ██╗   ██╗███████╗${NC}"
echo -e "${CYAN}   ██╔══██╗██╔══██╗╚██╗██╔╝██║   ██║██╔═══██╗██║   ██║██╔════╝${NC}"
echo -e "${CYAN}   ██║  ██║███████║ ╚███╔╝ ██║   ██║██║   ██║██║   ██║███████╗${NC}"
echo -e "${CYAN}   ██║  ██║██╔══██║ ██╔██╗ ██║   ██║██║   ██║██║   ██║╚════██║${NC}"
echo -e "${CYAN}   ██████╔╝██║  ██║██╔╝ ██╗╚██████╔╝╚██████╔╝╚██████╔╝███████║${NC}"
echo -e "${CYAN}   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝${NC}"
echo -e "${CYAN}                                                               ${NC}"
echo -e "${CYAN}   Cloud Services Setup — 100% Free Tier, Zero VPS${NC}"
echo -e "${CYAN}                                                               ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# ── Step 0: Initialize .env file ─────────────────────────────────────────────
log "Initializing .env file..."

if [[ ! -f "$ENV_FILE" ]]; then
    touch "$ENV_FILE"
    echo "# DAKKHO Cloud Services Credentials" > "$ENV_FILE"
    echo "# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$ENV_FILE"
    echo "# WARNING: Never commit this file to version control!" >> "$ENV_FILE"
    echo "" >> "$ENV_FILE"
    ok "Created new .env file."
else
    warn ".env file already exists. Appending new credentials."
    echo "" >> "$ENV_FILE"
    echo "# Updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$ENV_FILE"
    echo "" >> "$ENV_FILE"
fi

# ── Step 1: Check CLI Tools ──────────────────────────────────────────────────
log "Step 1: Checking required CLI tools..."
echo ""

MISSING_TOOLS=()

# Check wrangler (Cloudflare R2)
if command -v wrangler &> /dev/null; then
    WRANGLER_VERSION=$(wrangler --version 2>/dev/null | head -1 || echo "unknown")
    ok "wrangler: ${WRANGLER_VERSION}"
else
    warn "wrangler: NOT FOUND (required for R2 setup)"
    MISSING_TOOLS+=("wrangler")
fi

# Check lk (LiveKit CLI)
if command -v lk &> /dev/null; then
    LK_VERSION=$(lk version 2>/dev/null || echo "unknown")
    ok "lk (LiveKit CLI): ${LK_VERSION}"
else
    warn "lk (LiveKit CLI): NOT FOUND (optional, LiveKit setup is dashboard-based)"
fi

# Check curl
if command -v curl &> /dev/null; then
    CURL_VERSION=$(curl --version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
    ok "curl: ${CURL_VERSION}"
else
    fail "curl: NOT FOUND (required for API calls)"
fi

# Check python3
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>/dev/null || echo "unknown")
    ok "python3: ${PYTHON_VERSION}"
else
    warn "python3: NOT FOUND (used for JSON processing)"
    MISSING_TOOLS+=("python3")
fi

# Check jq (optional but nice)
if command -v jq &> /dev/null; then
    ok "jq: $(jq --version 2>/dev/null || echo "available")"
else
    log "jq: NOT FOUND (optional, python3 will be used for JSON)"
fi

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    echo ""
    warn "Missing tools: ${MISSING_TOOLS[*]}"
    log "Install missing tools before continuing:"
    
    for tool in "${MISSING_TOOLS[@]}"; do
        case $tool in
            wrangler)
                log "  npm install -g wrangler"
                ;;
            python3)
                log "  sudo apt install python3  # or: brew install python3"
                ;;
        esac
    done
    
    echo ""
    read -rp "Continue with available tools? (y/N): " CONTINUE
    [[ "${CONTINUE,,}" != "y" ]] && fail "Aborted. Install missing tools and re-run."
fi

echo ""
ok "CLI tools check complete."

# ── Step 2: Cloudflare R2 Setup ──────────────────────────────────────────────
log "Step 2: Cloudflare R2 Setup"
echo ""

R2_SCRIPT="${SCRIPT_DIR}/r2/setup.sh"
if [[ -f "$R2_SCRIPT" ]]; then
    log "Running R2 setup script..."
    chmod +x "$R2_SCRIPT"
    bash "$R2_SCRIPT" || warn "R2 setup encountered errors. Check output above."
else
    warn "R2 setup script not found: ${R2_SCRIPT}"
fi

echo ""
ok "R2 setup step complete."

# ── Step 3: LiveKit Cloud Setup ──────────────────────────────────────────────
log "Step 3: LiveKit Cloud Setup"
echo ""

LK_SCRIPT="${SCRIPT_DIR}/livekit/setup.sh"
if [[ -f "$LK_SCRIPT" ]]; then
    log "Running LiveKit setup script..."
    chmod +x "$LK_SCRIPT"
    bash "$LK_SCRIPT" || warn "LiveKit setup encountered errors. Check output above."
else
    warn "LiveKit setup script not found: ${LK_SCRIPT}"
fi

echo ""
ok "LiveKit setup step complete."

# ── Step 4: OneSignal Setup ─────────────────────────────────────────────────
log "Step 4: OneSignal Push Notification Setup"
echo ""

OS_SCRIPT="${SCRIPT_DIR}/onesignal/setup.sh"
if [[ -f "$OS_SCRIPT" ]]; then
    log "Running OneSignal setup script..."
    chmod +x "$OS_SCRIPT"
    bash "$OS_SCRIPT" || warn "OneSignal setup encountered errors. Check output above."
else
    warn "OneSignal setup script not found: ${OS_SCRIPT}"
fi

echo ""
ok "OneSignal setup step complete."

# ── Step 5: Resend Email Setup ──────────────────────────────────────────────
log "Step 5: Resend Email Setup"
echo ""

RESEND_SCRIPT="${SCRIPT_DIR}/resend/setup.sh"
if [[ -f "$RESEND_SCRIPT" ]]; then
    log "Running Resend setup script..."
    chmod +x "$RESEND_SCRIPT"
    bash "$RESEND_SCRIPT" || warn "Resend setup encountered errors. Check output above."
else
    warn "Resend setup script not found: ${RESEND_SCRIPT}"
fi

echo ""
ok "Resend setup step complete."

# ── Step 5.5: Supabase Complementary Setup ───────────────────────────────────
log "Step 5.5: Supabase Complementary Setup (Analytics, AI/ML, Realtime, Cron)"
echo ""

SB_SCRIPT="${SCRIPT_DIR}/supabase/setup.sh"
if [[ -f "$SB_SCRIPT" ]]; then
    log "Running Supabase setup script..."
    chmod +x "$SB_SCRIPT"
    bash "$SB_SCRIPT" || warn "Supabase setup encountered errors. Check output above."
else
    warn "Supabase setup script not found: ${SB_SCRIPT}"
fi

echo ""
ok "Supabase setup step complete."

# ── Step 6: Validate All Services ───────────────────────────────────────────
log "Step 6: Validating all services..."
echo ""

# Source the .env file for validation
if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE" 2>/dev/null || true
    set +a
fi

SERVICES_OK=0
SERVICES_TOTAL=5

# Validate R2
if [[ -n "${R2_ACCESS_KEY_ID:-}" && "${R2_ACCESS_KEY_ID}" != "your_r2_access_key_id" ]]; then
    ok "R2: Credentials configured"
    ((SERVICES_OK++)) || true
else
    warn "R2: Credentials not configured"
fi

# Validate LiveKit
if [[ -n "${LIVEKIT_API_KEY:-}" && "${LIVEKIT_API_KEY}" != "your_livekit_api_key" ]]; then
    ok "LiveKit: Credentials configured"
    ((SERVICES_OK++)) || true
else
    warn "LiveKit: Credentials not configured"
fi

# Validate OneSignal
if [[ -n "${ONESIGNAL_APP_ID:-}" && "${ONESIGNAL_APP_ID}" != "your_onesignal_app_id" ]]; then
    ok "OneSignal: Credentials configured"
    ((SERVICES_OK++)) || true
else
    warn "OneSignal: Credentials not configured"
fi

# Validate Resend
if [[ -n "${RESEND_API_KEY:-}" && "${RESEND_API_KEY}" != "your_resend_api_key" ]]; then
    ok "Resend: API key configured"
    ((SERVICES_OK++)) || true
else
    warn "Resend: API key not configured"
fi

# Validate Supabase
if [[ -n "${SUPABASE_URL:-}" && "${SUPABASE_URL}" != "your_supabase_url" ]]; then
    ok "Supabase: Credentials configured"
    ((SERVICES_OK++)) || true
else
    warn "Supabase: Credentials not configured"
fi

echo ""

# ── Step 7: Print Summary ───────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  DAKKHO — Cloud Services Setup Summary${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Service status table
echo -e "  ${BOLD}Service Status:${NC}"
echo -e "  ┌─────────────────────┬──────────────────────────────┬──────────┐"
echo -e "  │ Service             │ Endpoint                     │ Status   │"
echo -e "  ├─────────────────────┼──────────────────────────────┼──────────┤"

# R2
R2_STATUS="⚠ SETUP"
if [[ -n "${R2_ACCESS_KEY_ID:-}" && "${R2_ACCESS_KEY_ID}" != "your_r2_access_key_id" ]]; then
    R2_STATUS="✓ ACTIVE"
fi
printf "  │ %-19s │ %-28s │ %-8s │\n" "Cloudflare R2" "${R2_ENDPOINT:-not configured}" "$R2_STATUS"

# LiveKit
LK_STATUS="⚠ SETUP"
if [[ -n "${LIVEKIT_API_KEY:-}" && "${LIVEKIT_API_KEY}" != "your_livekit_api_key" ]]; then
    LK_STATUS="✓ ACTIVE"
fi
printf "  │ %-19s │ %-28s │ %-8s │\n" "LiveKit Cloud" "${LIVEKIT_WS_URL:-not configured}" "$LK_STATUS"

# OneSignal
OS_STATUS="⚠ SETUP"
if [[ -n "${ONESIGNAL_APP_ID:-}" && "${ONESIGNAL_APP_ID}" != "your_onesignal_app_id" ]]; then
    OS_STATUS="✓ ACTIVE"
fi
printf "  │ %-19s │ %-28s │ %-8s │\n" "OneSignal" "App: ${ONESIGNAL_APP_ID:-not set}" "$OS_STATUS"

# Resend
RE_STATUS="⚠ SETUP"
if [[ -n "${RESEND_API_KEY:-}" && "${RESEND_API_KEY}" != "your_resend_api_key" ]]; then
    RE_STATUS="✓ ACTIVE"
fi
printf "  │ %-19s │ %-28s │ %-8s │\n" "Resend" "${RESEND_DOMAIN:-not configured}" "$RE_STATUS"

# Supabase
SB_STATUS="⚠ SETUP"
if [[ -n "${SUPABASE_URL:-}" && "${SUPABASE_URL}" != "your_supabase_url" ]]; then
    SB_STATUS="✓ ACTIVE"
fi
printf "  │ %-19s │ %-28s │ %-8s │\n" "Supabase" "${SUPABASE_URL:-not configured}" "$SB_STATUS"

echo -e "  └─────────────────────┴──────────────────────────────┴──────────┘"
echo ""

# Credentials summary
echo -e "  ${BOLD}Credentials saved to:${NC} ${ENV_FILE}"
echo ""

# Free tier limits
echo -e "  ${BOLD}Free Tier Limits:${NC}"
echo -e "  ┌─────────────────────┬──────────────────────────────────────────┐"
echo -e "  │ Service             │ Free Tier                                │"
echo -e "  ├─────────────────────┼──────────────────────────────────────────┤"
echo -e "  │ Cloudflare R2       │ 10 GB storage, ZERO egress              │"
echo -e "  │ LiveKit Cloud       │ 5 rooms, 100 users, 10K min/mo          │"
echo -e "  │ OneSignal           │ Unlimited subscribers & notifications    │"
echo -e "  │ Resend              │ 100 emails/day, 3K emails/month         │"
echo -e "  │ Supabase            │ 500MB DB, 50K MAU, 1GB storage, pgvector│"
echo -e "  └─────────────────────┴──────────────────────────────────────────┘"
echo ""

# Next steps
echo -e "  ${BOLD}Next Steps:${NC}"
echo -e "  1. Verify R2 CORS and lifecycle rules in Cloudflare Dashboard"
echo -e "  2. Configure OneSignal FCM server key for Android delivery"
echo -e "  3. Verify Resend domain DNS records for production sending"
echo -e "  4. Deploy Appwrite Functions (livekit-token, email-sender, etc.)"
echo -e "  5. Update Flutter app environment variables with credentials"
echo -e "  6. Test all services end-to-end from Flutter app"
echo ""

# Overall result
if [[ $SERVICES_OK -eq $SERVICES_TOTAL ]]; then
    echo -e "  ${GREEN}${BOLD}All ${SERVICES_TOTAL}/${SERVICES_TOTAL} services configured! 🎉${NC}"
else
    echo -e "  ${YELLOW}${BOLD}${SERVICES_OK}/${SERVICES_TOTAL} services configured.${NC} Complete remaining setup manually."
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  Credentials file: ${ENV_FILE} (gitignored)"
echo -e "  Dashboard: Update STATUS.md with service statuses"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
