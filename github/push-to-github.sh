#!/usr/bin/env bash
# =============================================================================
# DAKKHO Push to GitHub Script
# =============================================================================
# Initializes git, adds remote, and pushes initial commits for each
# DAKKHO repository. Handles existing repos gracefully.
#
# Prerequisites:
#   - GitHub CLI (gh) installed and authenticated
#   - Git configured with name/email
#   - Local project directories exist
#
# Usage:
#   chmod +x push-to-github.sh
#   ./push-to-github.sh [--force]
#
# Options:
#   --force    Force push even if remote already has commits
# =============================================================================

set -euo pipefail

# ---- Configuration -----------------------------------------------------------

GITHUB_EMAIL="himadrient@proton.me"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"  # dakkho-cloud/

# Map repo names to local project directories
declare -A REPO_MAP=(
  ["dakkho-student"]="/home/z/my-project/dakkho-student"
  ["dakkho-admin"]="/home/z/my-project/dakkho-admin"
  ["dakkho-instructor"]="/home/z/my-project/dakkho-instructor"
)

# Map repo names to README directories
declare -A README_MAP=(
  ["dakkho-student"]="${SCRIPT_DIR}/readmes/dakkho-student/README.md"
  ["dakkho-admin"]="${SCRIPT_DIR}/readmes/dakkho-admin/README.md"
  ["dakkho-instructor"]="${SCRIPT_DIR}/readmes/dakkho-instructor/README.md"
)

# Map repo names to workflow files
declare -A WORKFLOW_MAP=(
  ["dakkho-student"]="build-student.yml"
  ["dakkho-admin"]="build-admin.yml"
  ["dakkho-instructor"]="build-instructor.yml"
)

SHARED_GITIGNORE="${SCRIPT_DIR}/gitignore"
SHARED_CONTRIBUTING="${SCRIPT_DIR}/CONTRIBUTING.md"
FORCE_PUSH=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---- Helper Functions --------------------------------------------------------

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

separator() {
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ---- Parse Arguments ---------------------------------------------------------

if [[ "${1:-}" == "--force" ]]; then
  FORCE_PUSH=true
  warn "Force push enabled. Use with caution!"
fi

# ---- Step 1: Check gh CLI Auth -----------------------------------------------

check_auth() {
  info "Checking GitHub CLI authentication..."

  if ! command -v gh &>/dev/null; then
    error "GitHub CLI (gh) is not installed. Install from https://cli.github.com/"
    exit 1
  fi

  if ! gh auth status &>/dev/null; then
    error "GitHub CLI is not authenticated. Run 'gh auth login' first."
    exit 1
  fi

  local gh_user
  gh_user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
  ok "Authenticated as: ${gh_user}"
}

# ---- Step 2: Get repo owner --------------------------------------------------

get_repo_owner() {
  local repo_name="$1"
  local owner
  owner=$(gh repo view "${repo_name}" --json owner --jq '.owner.login' 2>/dev/null || echo "")
  if [[ -z "$owner" ]]; then
    # Try getting the current user
    owner=$(gh api user --jq '.login' 2>/dev/null || echo "")
  fi
  echo "$owner"
}

# ---- Step 3: Push a single repo -----------------------------------------------

push_repo() {
  local repo_name="$1"
  local project_dir="${REPO_MAP[$repo_name]}"
  local readme_file="${README_MAP[$repo_name]}"
  local workflow_file="${WORKFLOW_MAP[$repo_name]}"

  separator
  info "Processing: ${repo_name}"
  info "  Local dir: ${project_dir}"
  info "  README:    ${readme_file}"
  info "  Workflow:  ${workflow_file}"

  # Check if local project directory exists
  if [[ ! -d "$project_dir" ]]; then
    warn "Local directory does not exist: ${project_dir}"
    info "  Creating minimal project structure..."

    mkdir -p "$project_dir"
    mkdir -p "${project_dir}/.github/workflows"
    mkdir -p "${project_dir}/lib"
  fi

  # Check if remote repo exists on GitHub
  local owner
  owner=$(get_repo_owner "$repo_name")
  if [[ -z "$owner" ]]; then
    error "Could not determine owner for repo '${repo_name}'. Does it exist on GitHub?"
    return 1
  fi

  local remote_url="https://github.com/${owner}/${repo_name}.git"
  ok "Remote URL: ${remote_url}"

  # Enter project directory
  cd "$project_dir"

  # Initialize git if not already
  if [[ ! -d ".git" ]]; then
    info "  Initializing git repository..."
    git init
    git checkout -b main
    ok "  Git initialized on 'main' branch."
  else
    ok "  Git already initialized."
  fi

  # Configure git user if not set
  local git_email
  git_email=$(git config user.email 2>/dev/null || echo "")
  if [[ -z "$git_email" ]]; then
    git config user.email "$GITHUB_EMAIL"
    git config user.name "DAKKHO Dev"
    ok "  Git user configured: DAKKHO Dev <${GITHUB_EMAIL}>"
  fi

  # Copy README
  if [[ -f "$readme_file" ]]; then
    cp "$readme_file" README.md
    ok "  README.md copied."
  else
    warn "  README file not found: ${readme_file}"
  fi

  # Copy .gitignore
  if [[ -f "$SHARED_GITIGNORE" ]]; then
    cp "$SHARED_GITIGNORE" .gitignore
    ok "  .gitignore copied."
  else
    warn "  Shared .gitignore not found: ${SHARED_GITIGNORE}"
  fi

  # Copy CONTRIBUTING.md
  if [[ -f "$SHARED_CONTRIBUTING" ]]; then
    cp "$SHARED_CONTRIBUTING" CONTRIBUTING.md
    ok "  CONTRIBUTING.md copied."
  else
    warn "  Shared CONTRIBUTING.md not found."
  fi

  # Copy workflow file
  mkdir -p .github/workflows
  local workflow_src="${SCRIPT_DIR}/workflows/${workflow_file}"
  if [[ -f "$workflow_src" ]]; then
    cp "$workflow_src" ".github/workflows/${workflow_file}"
    ok "  Workflow copied: .github/workflows/${workflow_file}"
  else
    warn "  Workflow file not found: ${workflow_src}"
  fi

  # Create .env.example if it doesn't exist
  if [[ ! -f ".env.example" ]]; then
    cat > .env.example << 'ENVEOF'
# =============================================================================
# DAKKHO Environment Variables
# =============================================================================
# Copy this file to .env and fill in your actual values.
# NEVER commit .env files — they are gitignored.
# =============================================================================

# Appwrite Cloud
APPWRITE_ENDPOINT=https://cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=your-project-id
APPWRITE_DATABASE_ID=dakkho-main

# LiveKit Cloud
LIVEKIT_URL=wss://your-livekit-url.livekit.cloud
LIVEKIT_API_KEY=your-livekit-api-key
LIVEKIT_API_SECRET=your-livekit-api-secret

# OneSignal
ONESIGNAL_APP_ID=your-onesignal-app-id

# Cloudflare R2
R2_BUCKET_NAME=dakkho-videos
R2_PUBLIC_URL=https://cdn.dakkho.com

# Payment Gateways
SSLCOMMERZ_STORE_ID=your-store-id
SSLCOMMERZ_STORE_PASSWORD=your-store-password
BKASH_USERNAME=your-bkash-username
BKASH_PASSWORD=your-bkash-password
BKASH_APP_KEY=your-bkash-app-key
BKASH_APP_SECRET=your-bkash-app-secret
NAGAD_MERCHANT_ID=your-nagad-merchant-id
NAGAD_PUBLIC_KEY=your-nagad-public-key

# Google OAuth
GOOGLE_OAUTH_CLIENT_ID=your-google-client-id

# Optional: Sentry
SENTRY_DSN=
ENVEOF
    ok "  .env.example created."
  fi

  # Add remote if not already present
  local has_remote
  has_remote=$(git remote get-url origin 2>/dev/null || echo "")
  if [[ -z "$has_remote" ]]; then
    git remote add origin "$remote_url"
    ok "  Remote 'origin' added: ${remote_url}"
  elif [[ "$has_remote" != "$remote_url" ]]; then
    git remote set-url origin "$remote_url"
    ok "  Remote 'origin' updated: ${remote_url}"
  else
    ok "  Remote 'origin' already configured."
  fi

  # Stage and commit
  info "  Staging files..."
  git add -A

  # Check if there are changes to commit
  if git diff --cached --quiet; then
    ok "  No new changes to commit."
  else
    git commit -m "chore: initial project setup with README, .gitignore, and CI/CD"
    ok "  Initial commit created."
  fi

  # Push to remote
  info "  Pushing to GitHub..."
  local push_flags="-u origin main"
  if [[ "$FORCE_PUSH" == true ]]; then
    push_flags="-u origin main --force"
  fi

  if git push $push_flags 2>&1; then
    ok "  Successfully pushed to GitHub!"
  else
    # Handle case where remote already has commits
    warn "  Push failed. Remote may already have commits."
    if [[ "$FORCE_PUSH" == true ]]; then
      info "  Force pushing..."
      git push -u origin main --force 2>&1 && ok "  Force push succeeded."
    else
      info "  Pulling remote changes first..."
      git pull origin main --rebase 2>&1 || true
      git push -u origin main 2>&1 && ok "  Push succeeded after rebase."
    fi
  fi

  ok "Repository '${repo_name}' setup complete!"
  echo ""

  # Return to original directory
  cd - > /dev/null
}

# ---- Main -------------------------------------------------------------------

main() {
  echo ""
  echo -e "${BLUE}  ╔══════════════════════════════════════════════════════════╗"
  echo -e "  ║     DAKKHO Push to GitHub                               ║"
  echo -e "  ║     Account: ${GITHUB_EMAIL}              ║"
  echo -e "  ╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""

  check_auth
  echo ""

  for repo_name in "${!REPO_MAP[@]}"; do
    push_repo "$repo_name"
  done

  separator
  echo -e "${GREEN}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║           All Repositories Pushed!                      ║"
  echo "  ╠══════════════════════════════════════════════════════════╣"
  echo -e "  ║${NC}"
  echo -e "  ${GREEN}║${NC}  Next steps:"
  echo -e "  ${GREEN}║${NC}"
  echo -e "  ${GREEN}║${NC}  1. Add GitHub Secrets for CI/CD:"
  echo -e "  ${GREEN}║${NC}     - KEYSTORE_BASE64, KEYSTORE_PASSWORD"
  echo -e "  ${GREEN}║${NC}     - KEY_ALIAS, KEY_PASSWORD"
  echo -e "  ${GREEN}║${NC}     - ENV_FILE (base64-encoded .env)"
  echo -e "  ${GREEN}║${NC}"
  echo -e "  ${GREEN}║${NC}  2. Re-run setup-repos.sh to apply branch protection"
  echo -e "  ${GREEN}║${NC}"
  echo -e "  ${GREEN}║${NC}  3. Verify CI workflows trigger on push"
  echo -e "  ${GREEN}║${NC}"
  echo -e "${GREEN}  ╚══════════════════════════════════════════════════════════╝${NC}"
}

main "$@"
