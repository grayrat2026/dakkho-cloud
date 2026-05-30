#!/usr/bin/env bash
# ==============================================================================
# DAKKHO — Resend Email Service Setup Script
# Configures domain, creates API key, tests email sending
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
TEMPLATES_DIR="${SCRIPT_DIR}/templates"

# Load from .env if available, otherwise prompt
DEFAULT_API_KEY=""
if [[ -f "$ENV_FILE" ]]; then
    DEFAULT_API_KEY=$(rg "RESEND_API_KEY=" "$ENV_FILE" 2>/dev/null | head -1 | sed 's/.*=//' || true)
fi

log()  { echo -e "${CYAN}[Resend]${NC} $1"; }
ok()   { echo -e "${GREEN}[Resend ✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[Resend ⚠]${NC} $1"; }
fail() { echo -e "${RED}[Resend ✗]${NC} $1"; exit 1; }

# ── Pre-flight checks ────────────────────────────────────────────────────────
log "Running pre-flight checks..."

if ! command -v curl &> /dev/null; then
    fail "curl is required but not found."
fi

ok "Pre-flight checks passed."

# ── API Key Configuration ────────────────────────────────────────────────────
log "Configuring Resend API key..."

RESEND_API_KEY=""

# Check for existing key in .env
if [[ -f "$ENV_FILE" ]]; then
    RESEND_API_KEY=$(rg "RESEND_API_KEY=" "$ENV_FILE" 2>/dev/null | head -1 | sed 's/.*=//' || true)
fi

# Use provided key if none found
if [[ -z "$RESEND_API_KEY" || "$RESEND_API_KEY" == "your_resend_api_key" ]]; then
    RESEND_API_KEY="$DEFAULT_API_KEY"
    ok "Using provided Resend API key: ${RESEND_API_KEY:0:10}..."
else
    ok "Found existing Resend API key: ${RESEND_API_KEY:0:10}..."
    read -rp "Use this key? (Y/n): " USE_EXISTING
    if [[ "${USE_EXISTING,,}" == "n" ]]; then
        read -rp "Enter new Resend API key: " RESEND_API_KEY
    fi
fi

# ── Validate API Key ────────────────────────────────────────────────────────
log "Validating Resend API key..."

DOMAIN_RESPONSE=$(curl -s \
    "https://api.resend.com/domains" \
    -H "Authorization: Bearer ${RESEND_API_KEY}" 2>/dev/null || echo "{}")

HTTP_STATUS=$(echo "$DOMAIN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print('valid')" 2>/dev/null || echo "invalid")

if [[ "$HTTP_STATUS" == "valid" ]]; then
    ok "Resend API key is valid."
else
    # Try another validation method
    VALIDATE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://api.resend.com/domains" \
        -H "Authorization: Bearer ${RESEND_API_KEY}")
    
    if [[ "$VALIDATE_STATUS" == "200" ]]; then
        ok "Resend API key is valid."
    elif [[ "$VALIDATE_STATUS" == "401" ]]; then
        warn "API key validation returned 401. The key may be invalid or expired."
        read -rp "Continue anyway? (y/N): " CONTINUE_ANYWAY
        [[ "${CONTINUE_ANYWAY,,}" != "y" ]] && fail "Aborted. Please provide a valid Resend API key."
    else
        warn "Could not validate API key (HTTP ${VALIDATE_STATUS}). Continuing..."
    fi
fi

# ── Domain Verification ─────────────────────────────────────────────────────
log "Checking domain configuration..."

DOMAINS=$(curl -s \
    "https://api.resend.com/domains" \
    -H "Authorization: Bearer ${RESEND_API_KEY}" 2>/dev/null || echo '{"data":[]}')

DOMAIN_COUNT=$(echo "$DOMAINS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',[])))" 2>/dev/null || echo "0")
DOMAIN_NAME=$(echo "$DOMAINS" | python3 -c "import sys,json; d=json.load(sys.stdin); data=d.get('data',[]); print(data[0]['name'] if data else '')" 2>/dev/null || echo "")

if [[ "$DOMAIN_COUNT" == "0" || -z "$DOMAIN_NAME" ]]; then
    log "No verified domains found. Domain setup required."
    echo ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "  Domain Verification Steps (required for custom sender):"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log "Step 1: Add domain in Resend Dashboard"
    log "  → Open: https://resend.com/domains"
    log "  → Click 'Add Domain'"
    log "  → Enter: dakkho.com.bd"
    log "  → Select region: US (default)"
    echo ""
    log "Step 2: Add DNS records (shown in Resend dashboard) to your domain:"
    log "  → SPF record (TXT)   — authorizes Resend to send emails"
    log "  → DKIM record (CNAME)— signs emails for deliverability"
    log "  → DMARC record (TXT) — email authentication policy"
    log "  → MX record          — (optional) for receiving replies"
    echo ""
    log "Step 3: Wait for DNS propagation (5-30 minutes)"
    log "  → Click 'Verify' in Resend dashboard"
    echo ""
    log "Until domain is verified, you can send test emails to your own email"
    log "using the onboarding route: noreply@resend.dev"
    echo ""
    
    read -rp "Enter your domain (or press Enter to use resend.dev for testing): " USER_DOMAIN
    DOMAIN_NAME="${USER_DOMAIN:-dakkho.com.bd}"
    
    # Try to create domain via API
    CREATE_DOMAIN_RESPONSE=$(curl -s \
        "https://api.resend.com/domains" \
        -H "Authorization: Bearer ${RESEND_API_KEY}" \
        -H "Content-Type: application/json" \
        --data "{\"name\": \"${DOMAIN_NAME}\"}" 2>/dev/null || echo "{}")
    
    DOMAIN_ID=$(echo "$CREATE_DOMAIN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
    
    if [[ -n "$DOMAIN_ID" ]]; then
        ok "Domain '${DOMAIN_NAME}' created in Resend (ID: ${DOMAIN_ID})."
        log "Complete DNS verification at: https://resend.com/domains/${DOMAIN_ID}"
        
        # Show DNS records
        DNS_RECORDS=$(curl -s \
            "https://api.resend.com/domains/${DOMAIN_ID}" \
            -H "Authorization: Bearer ${RESEND_API_KEY}" 2>/dev/null || echo "{}")
        
        echo ""
        log "Required DNS records:"
        echo "$DNS_RECORDS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for record in d.get('records', []):
    print(f\"  Type: {record.get('record','?')} | Host: {record.get('value','?')} | Priority: {record.get('priority','')}\")
" 2>/dev/null || log "  (View records at https://resend.com/domains/${DOMAIN_ID})"
    else
        warn "Could not auto-create domain. Create manually at https://resend.com/domains"
    fi
else
    ok "Domain found: ${DOMAIN_NAME}"
    
    # Check verification status
    DOMAIN_STATUS=$(echo "$DOMAINS" | python3 -c "import sys,json; d=json.load(sys.stdin); data=d.get('data',[]); print(data[0].get('status','unknown') if data else 'unknown')" 2>/dev/null || echo "unknown")
    
    if [[ "$DOMAIN_STATUS" == "verified" ]]; then
        ok "Domain is verified and ready for sending."
    else
        warn "Domain status: ${DOMAIN_STATUS}. Complete verification at https://resend.com/domains"
    fi
fi

# ── Send Test Email ──────────────────────────────────────────────────────────
log "Testing email delivery..."

SENDER_EMAIL="onboarding@resend.dev"  # Default sender for unverified domains
if [[ "$DOMAIN_NAME" != "dakkho.com.bd" ]] || [[ "$DOMAIN_STATUS" == "verified" ]]; then
    SENDER_EMAIL="noreply@${DOMAIN_NAME}"
fi

read -rp "Enter email address for test delivery (or press Enter to skip): " TEST_EMAIL

if [[ -n "$TEST_EMAIL" ]]; then
    log "Sending test email to ${TEST_EMAIL}..."
    
    # Check if welcome template exists
    WELCOME_TEMPLATE="${TEMPLATES_DIR}/welcome.html"
    if [[ -f "$WELCOME_TEMPLATE" ]]; then
        HTML_BODY=$(cat "$WELCOME_TEMPLATE" | python3 -c "
import sys
html = sys.stdin.read()
# Replace template variables with test values
html = html.replace('{{userName}}', 'পরীক্ষা ব্যবহারকারী')
html = html.replace('{{userEmail}}', '${TEST_EMAIL}')
html = html.replace('{{currentYear}}', '2026')
print(html)
" 2>/dev/null || echo "<h1>DAKKHO Test Email</h1><p>আপনার ইমেইল সার্ভিস সঠিকভাবে কাজ করছে!</p>")
    else
        HTML_BODY="<h1>DAKKHO Test Email</h1><p>আপনার ইমেইল সার্ভিস সঠিকভাবে কাজ করছে!</p>"
    fi

    # Escape HTML for JSON
    HTML_JSON=$(echo "$HTML_BODY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '"<h1>Test</h1>"')

    TEST_RESPONSE=$(curl -s \
        "https://api.resend.com/email" \
        -H "Authorization: Bearer ${RESEND_API_KEY}" \
        -H "Content-Type: application/json" \
        --data "{
            \"from\": \"DAKKHO <${SENDER_EMAIL}>\",
            \"to\": [\"${TEST_EMAIL}\"],
            \"subject\": \"ডাকো ইমেইল সার্ভিস পরীক্ষা ✅\",
            \"html\": ${HTML_JSON}
        }" 2>/dev/null || echo "{}")

    EMAIL_ID=$(echo "$TEST_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
    EMAIL_ERROR=$(echo "$TEST_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',''))" 2>/dev/null || echo "")

    if [[ -n "$EMAIL_ID" ]]; then
        ok "Test email sent! ID: ${EMAIL_ID}"
        log "Check ${TEST_EMAIL} inbox (and spam folder)."
    else
        warn "Test email may have failed: ${EMAIL_ERROR}"
        log "This is expected if domain is not yet verified."
        log "Use resend.dev sender for testing until domain is verified."
    fi
else
    log "Skipping test email."
fi

# ── List Email Templates ────────────────────────────────────────────────────
log "Checking email templates..."

TEMPLATE_COUNT=0
if [[ -d "$TEMPLATES_DIR" ]]; then
    for template in "$TEMPLATES_DIR"/*.html; do
        if [[ -f "$template" ]]; then
            TEMPLATE_NAME=$(basename "$template" .html)
            log "  → Template: ${TEMPLATE_NAME}"
            ((TEMPLATE_COUNT++)) || true
        fi
    done
fi

ok "Found ${TEMPLATE_COUNT} email templates."

# ── Write credentials to .env ────────────────────────────────────────────────
log "Writing credentials to .env file..."

{
    echo "# ── Resend Email ─────────────────────────────────────────────"
    echo "RESEND_API_KEY=${RESEND_API_KEY}"
    echo "RESEND_DOMAIN=${DOMAIN_NAME}"
    echo "RESEND_SENDER_EMAIL=noreply@${DOMAIN_NAME}"
    echo "RESEND_SENDER_NAME=DAKKHO"
    echo ""
} >> "$ENV_FILE"

ok "Credentials appended to ${ENV_FILE}"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  DAKKHO — Resend Email Setup Complete${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  API Key:           ${GREEN}${RESEND_API_KEY:0:10}...${NC}"
echo -e "  Domain:            ${GREEN}${DOMAIN_NAME}${NC}"
echo -e "  Sender:            ${GREEN}noreply@${DOMAIN_NAME}${NC}"
echo -e "  Templates:         ${GREEN}${TEMPLATE_COUNT} (welcome, subscription_confirmation, payment_receipt, device_swap_alert)${NC}"
echo -e "  Test Sender:       ${GREEN}onboarding@resend.dev${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
log "Dashboard: https://resend.com/overview"
log "Free tier: 100 emails/day, 3,000 emails/month"
log "Templates directory: ${TEMPLATES_DIR}/"
log "Next: Verify domain DNS records for production sending"
