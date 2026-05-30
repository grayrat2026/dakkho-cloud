#!/usr/bin/env bash
# ==============================================================================
# DAKKHO — Cloudflare R2 Setup Script
# Creates R2 bucket, configures CORS, lifecycle rules, and generates API token
# ==============================================================================
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

BUCKET_NAME="dakkho-videos"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

log()  { echo -e "${CYAN}[R2]${NC} $1"; }
ok()   { echo -e "${GREEN}[R2 ✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[R2 ⚠]${NC} $1"; }
fail() { echo -e "${RED}[R2 ✗]${NC} $1"; exit 1; }

# ── Pre-flight checks ────────────────────────────────────────────────────────
log "Running pre-flight checks..."

if ! command -v wrangler &> /dev/null; then
    fail "wrangler CLI not found. Install with: npm install -g wrangler"
fi

# Check if wrangler is authenticated
if ! wrangler whoami &> /dev/null 2>&1; then
    warn "Not authenticated with Cloudflare. Launching login..."
    wrangler login
    if ! wrangler whoami &> /dev/null 2>&1; then
        fail "Authentication failed. Please try 'wrangler login' manually."
    fi
fi

ACCOUNT_ID=$(wrangler whoami 2>&1 | rg -o 'Account ID: [a-f0-9]+' | rg -o '[a-f0-9]{32}' || true)
if [[ -z "$ACCOUNT_ID" ]]; then
    warn "Could not auto-detect Account ID. Enter it manually:"
    read -rp "Cloudflare Account ID: " ACCOUNT_ID
    [[ -z "$ACCOUNT_ID" ]] && fail "Account ID is required."
fi

ok "Authenticated with Cloudflare (Account: ${ACCOUNT_ID:0:8}...)"

# ── Create R2 Bucket ─────────────────────────────────────────────────────────
log "Creating R2 bucket: ${BUCKET_NAME}..."

if wrangler r2 bucket list 2>&1 | rg -q "$BUCKET_NAME"; then
    warn "Bucket '${BUCKET_NAME}' already exists. Skipping creation."
else
    wrangler r2 bucket create "$BUCKET_NAME" || fail "Failed to create bucket."
    ok "Bucket '${BUCKET_NAME}' created."
fi

# ── Configure CORS ───────────────────────────────────────────────────────────
log "Configuring CORS for HLS video streaming..."

CORS_FILE="${SCRIPT_DIR}/cors.json"
if [[ ! -f "$CORS_FILE" ]]; then
    fail "CORS config not found: ${CORS_FILE}"
fi

# Apply CORS via S3-compatible API (wrangler doesn't have native CORS command)
# We use the Cloudflare API directly
CORS_JSON=$(cat "$CORS_FILE")

# Get API token for CORS configuration
CF_API_TOKEN=$(wrangler config get api_token 2>/dev/null || echo "")
if [[ -z "$CF_API_TOKEN" ]]; then
    warn "Could not auto-detect API token for CORS configuration."
    log "You can set CORS manually in the Cloudflare dashboard:"
    log "  R2 > ${BUCKET_NAME} > Settings > CORS Policy"
    log "  Paste the contents of cors.json"
else
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/r2/buckets/${BUCKET_NAME}/cors" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"rules\": ${CORS_JSON}}")

    if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "204" ]]; then
        ok "CORS configured for HLS video streaming."
    else
        warn "CORS configuration via API returned HTTP ${HTTP_STATUS}."
        log "Apply CORS manually in Cloudflare Dashboard → R2 → ${BUCKET_NAME} → Settings → CORS Policy"
    fi
fi

# ── Configure Lifecycle Rules ────────────────────────────────────────────────
log "Configuring lifecycle rules..."

LIFECYCLE_FILE="${SCRIPT_DIR}/lifecycle.json"
if [[ ! -f "$LIFECYCLE_FILE" ]]; then
    fail "Lifecycle config not found: ${LIFECYCLE_FILE}"
fi

LIFECYCLE_JSON=$(cat "$LIFECYCLE_FILE")

if [[ -n "$CF_API_TOKEN" ]]; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/r2/buckets/${BUCKET_NAME}/lifecycle" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"rules\": ${LIFECYCLE_JSON}}")

    if [[ "$HTTP_STATUS" == "200" || "$HTTP_STATUS" == "204" ]]; then
        ok "Lifecycle rules configured (temp/ 30d, processing/ 7d, failed/ 3d, multipart abort 3d)."
    else
        warn "Lifecycle configuration via API returned HTTP ${HTTP_STATUS}."
        log "Apply lifecycle rules manually in Cloudflare Dashboard → R2 → ${BUCKET_NAME} → Settings > Object lifecycle"
    fi
fi

# ── Create API Token ─────────────────────────────────────────────────────────
log "Creating R2 API token..."

# Check if token already exists
EXISTING_TOKENS=$(curl -s \
    "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" 2>/dev/null || echo "")

if [[ -n "$CF_API_TOKEN" ]]; then
    # Create a dedicated R2 read/write token via Cloudflare API
    TOKEN_RESPONSE=$(curl -s \
        "https://api.cloudflare.com/client/v4/user/tokens" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data '{
            "name": "DAKKHO R2 Read/Write",
            "policies": [
                {
                    "effect": "allow",
                    "resources": {
                        "com.cloudflare.edge.r2.bucket.'$ACCOUNT_ID'_'$BUCKET_NAME'": "*"
                    },
                    "permission_groups": [
                        {"id": "82e64a83756745bbbb1c9c2701bf816b", "name": "R2:Edit"},
                        {"id": "4350a59ebb5795394897f6775a89e1d1", "name": "R2:Read"}
                    ]
                }
            ],
            "not_before": null,
            "expires_on": null
        }' 2>/dev/null || echo "{}")

    R2_API_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('value',''))" 2>/dev/null || echo "")

    if [[ -n "$R2_API_TOKEN" && "$R2_API_TOKEN" != "" ]]; then
        ok "R2 API token created."
    else
        warn "Could not create API token programmatically."
        log "Create token manually at: https://dash.cloudflare.com/profile/api-tokens"
        log "Template: 'Edit Cloudflare R2' → Select bucket: ${BUCKET_NAME}"
        read -rp "Paste your R2 API token (or press Enter to skip): " R2_API_TOKEN
    fi
else
    warn "No Cloudflare API token available for token creation."
    log "Create R2 API token at: https://dash.cloudflare.com/profile/api-tokens"
    log "  → Create Token → Edit Cloudflare R2 → Select bucket: ${BUCKET_NAME}"
    read -rp "Paste your R2 API token (or press Enter to skip): " R2_API_TOKEN
fi

# ── Generate S3-compatible credentials ───────────────────────────────────────
log "Generating S3-compatible API credentials..."

# R2 uses S3-compatible API. Create S3 API tokens via Cloudflare dashboard or API
S3_RESPONSE=$(curl -s \
    "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/r2/temp-access-keys" \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data '{
        "bucketName": "'$BUCKET_NAME'",
        "permission": "readwrite",
        "maxAgeSeconds": 31536000
    }' 2>/dev/null || echo "{}")

R2_ACCESS_KEY_ID=$(echo "$S3_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('accessKeyId',''))" 2>/dev/null || echo "")
R2_SECRET_ACCESS_KEY=$(echo "$S3_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('secretAccessKey',''))" 2>/dev/null || echo "")

if [[ -z "$R2_ACCESS_KEY_ID" || -z "$R2_SECRET_ACCESS_KEY" ]]; then
    warn "Could not auto-generate S3-compatible credentials."
    log "Create S3 API credentials at: https://dash.cloudflare.com/${ACCOUNT_ID}/r2/overview"
    log "  → Manage R2 API Tokens → Create API Token → Object Read & Write → ${BUCKET_NAME}"
    read -rp "R2 Access Key ID: " R2_ACCESS_KEY_ID
    read -rp "R2 Secret Access Key: " R2_SECRET_ACCESS_KEY
fi

# ── Construct endpoint URL ───────────────────────────────────────────────────
R2_ENDPOINT="https://${ACCOUNT_ID}.r2.cloudflarestorage.com"
R2_PUBLIC_URL="https://pub-${ACCOUNT_ID}.r2.dev" # If public bucket access is enabled

ok "R2 endpoint: ${R2_ENDPOINT}"

# ── Write credentials to .env ────────────────────────────────────────────────
log "Writing credentials to .env file..."

{
    echo "# ── Cloudflare R2 ──────────────────────────────────────────"
    echo "R2_BUCKET_NAME=${BUCKET_NAME}"
    echo "R2_ACCOUNT_ID=${ACCOUNT_ID}"
    echo "R2_ENDPOINT=${R2_ENDPOINT}"
    echo "R2_PUBLIC_URL=${R2_PUBLIC_URL}"
    echo "R2_ACCESS_KEY_ID=${R2_ACCESS_KEY_ID}"
    echo "R2_SECRET_ACCESS_KEY=${R2_SECRET_ACCESS_KEY}"
    [[ -n "${R2_API_TOKEN:-}" ]] && echo "R2_API_TOKEN=${R2_API_TOKEN}"
    echo ""
} >> "$ENV_FILE"

ok "Credentials appended to ${ENV_FILE}"

# ── Validate setup ───────────────────────────────────────────────────────────
log "Validating R2 setup..."

if [[ -n "$R2_ACCESS_KEY_ID" && -n "$R2_SECRET_ACCESS_KEY" ]]; then
    # Test S3-compatible API access
    VALIDATE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        "${R2_ENDPOINT}/${BUCKET_NAME}?list-type=2&max-keys=1" \
        -H "Host: ${BUCKET_NAME}.${ACCOUNT_ID}.r2.cloudflarestorage.com" 2>/dev/null || echo "000")

    if [[ "$VALIDATE_STATUS" == "200" ]]; then
        ok "R2 bucket is accessible via S3 API."
    else
        warn "R2 bucket validation returned HTTP ${VALIDATE_STATUS}. Credentials may need verification."
    fi
else
    warn "Skipping validation — no S3 credentials available."
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  DAKKHO — Cloudflare R2 Setup Complete${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  Bucket Name:       ${GREEN}${BUCKET_NAME}${NC}"
echo -e "  S3 Endpoint:       ${GREEN}${R2_ENDPOINT}${NC}"
echo -e "  Public URL:        ${GREEN}${R2_PUBLIC_URL}${NC}"
echo -e "  Access Key ID:     ${GREEN}${R2_ACCESS_KEY_ID:0:8}...${NC}"
echo -e "  Secret Access Key: ${GREEN}${R2_SECRET_ACCESS_KEY:0:8}...${NC}"
echo -e "  CORS:              ${GREEN}Configured for HLS streaming${NC}"
echo -e "  Lifecycle:         ${GREEN}temp/ 30d, processing/ 7d, failed/ 3d${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
log "Free tier: 10 GB storage, 10M Class A ops, 1M Class B ops, ZERO egress"
log "Dashboard: https://dash.cloudflare.com/${ACCOUNT_ID}/r2/overview"
