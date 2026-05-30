#!/usr/bin/env bash
# =============================================================================
# DAKKHO GitHub Repository Setup Script
# =============================================================================
# Creates 3 private GitHub repositories for the DAKKHO platform:
#   1. dakkho-student   (com.grayrat.dakkho.student.pro.bd)
#   2. dakkho-admin     (com.grayrat.dakkho.admin.pro.bd)
#   3. dakkho-instructor (com.grayrat.dakkho.instructor.pro.bd)
#
# Prerequisites:
#   - GitHub CLI (gh) installed: https://cli.github.com/
#   - GitHub account with appropriate permissions
#   - Git configured with name/email
#
# Usage:
#   chmod +x setup-repos.sh
#   ./setup-repos.sh
# =============================================================================

set -euo pipefail

# ---- Configuration -----------------------------------------------------------

GITHUB_EMAIL="himadrient@proton.me"
REPOS=("dakkho-student" "dakkho-admin" "dakkho-instructor")
DESCRIPTIONS=(
  "BTEB Diploma Engineering Education Platform - Student App"
  "Admin Panel for DAKKHO Platform"
  "Instructor App for DAKKHO Platform"
)
PACKAGES=(
  "com.grayrat.dakkho.student.pro.bd"
  "com.grayrat.dakkho.admin.pro.bd"
  "com.grayrat.dakkho.instructor.pro.bd"
)
TOPICS="flutter,education,bteb,bangladesh,appwrite"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---- Helper Functions --------------------------------------------------------

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

separator() {
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ---- Step 1: Check gh CLI ---------------------------------------------------

check_gh_cli() {
  info "Checking for GitHub CLI (gh)..."
  if ! command -v gh &>/dev/null; then
    error "GitHub CLI (gh) is not installed."
    echo ""
    echo "Install it from: https://cli.github.com/"
    echo "  macOS:   brew install gh"
    echo "  Linux:   https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    echo "  Windows: winget install --id GitHub.cli"
    exit 1
  fi

  local gh_version
  gh_version=$(gh --version | head -1)
  ok "GitHub CLI found: ${gh_version}"
}

# ---- Step 2: Authenticate with GitHub ---------------------------------------

authenticate() {
  info "Checking GitHub authentication status..."

  if gh auth status &>/dev/null; then
    ok "Already authenticated with GitHub."
    gh auth status 2>&1 | sed 's/^/  /'
    return 0
  fi

  warn "Not authenticated. Starting login flow..."
  echo ""
  echo "You will need a GitHub Personal Access Token (PAT) with these scopes:"
  echo "  - repo (full control of private repositories)"
  echo "  - workflow (update GitHub Actions workflows)"
  echo ""
  echo "Create a token at: https://github.com/settings/tokens/new"
  echo ""

  gh auth login --with-token || {
    error "Authentication failed. Please try again."
    exit 1
  }

  ok "Successfully authenticated with GitHub."
}

# ---- Step 3: Create Repositories --------------------------------------------

create_repo() {
  local repo_name="$1"
  local description="$2"
  local package="$3"

  separator
  info "Creating repository: ${repo_name}"
  info "  Description: ${description}"
  info "  Package: ${package}"

  # Check if repo already exists
  if gh repo view "${repo_name}" &>/dev/null; then
    warn "Repository '${repo_name}' already exists. Skipping creation."
    return 0
  fi

  # Create private repository
  gh repo create "${repo_name}" \
    --private \
    --description "${description}" \
    --clone=false

  if [ $? -eq 0 ]; then
    ok "Repository '${repo_name}' created successfully."
  else
    error "Failed to create repository '${repo_name}'."
    return 1
  fi

  # Add topics/tags
  info "  Adding topics: ${TOPICS}..."
  gh repo edit "${repo_name}" --add-topic "${TOPICS}" 2>/dev/null || {
    warn "  Could not add topics (may need to set them manually)."
  }

  ok "Topics added to '${repo_name}'."
}

create_all_repos() {
  info "Creating ${#REPOS[@]} private repositories..."
  echo ""

  for i in "${!REPOS[@]}"; do
    create_repo "${REPOS[$i]}" "${DESCRIPTIONS[$i]}" "${PACKAGES[$i]}"
    echo ""
  done

  ok "All repositories created."
}

# ---- Step 4: Branch Protection ----------------------------------------------

setup_branch_protection() {
  local repo_name="$1"

  info "  Setting up branch protection for 'main' on '${repo_name}'..."

  # Branch protection requires a Pro/Team/Enterprise organization,
  # or a personal account with the right plan. This will gracefully
  # handle the case where it's not available.
  gh api "repos/{owner}/${repo_name}/branches/main/protection" \
    --method PUT \
    --input - <<'EOF' 2>/dev/null || {
    warn "  Branch protection could not be set (requires GitHub Pro/Team plan, or repo must have at least 1 commit)."
    warn "  You can set it manually later via: Settings > Branches > Branch protection rules"
    return 0
  }
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["test", "build-apk"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

  ok "  Branch protection configured for '${repo_name}/main'."
}

setup_all_branch_protection() {
  separator
  info "Configuring branch protection for all repositories..."
  echo ""

  for repo_name in "${REPOS[@]}"; do
    setup_branch_protection "${repo_name}"
  done

  echo ""
  ok "Branch protection setup complete."
  warn "Note: Branch protection requires at least 1 commit on 'main' branch."
  warn "Run push-to-github.sh first, then re-run this script to apply protection."
}

# ---- Step 5: Summary --------------------------------------------------------

print_summary() {
  separator
  echo -e "${GREEN}"
  echo "  ╔══════════════════════════════════════════════════════════╗"
  echo "  ║           DAKKHO GitHub Repositories Ready              ║"
  echo "  ╠══════════════════════════════════════════════════════════╣"
  echo -e "  ║${NC}"
  for i in "${!REPOS[@]}"; do
    echo -e "  ${GREEN}║${NC}  ${REPOS[$i]}"
    echo -e "  ${GREEN}║${NC}    Package: ${PACKAGES[$i]}"
    echo -e "  ${GREEN}║${NC}    URL: https://github.com/$(gh repo view "${REPOS[$i]}" --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "OWNER/${REPOS[$i]}")"
    echo -e "  ${GREEN}║${NC}"
  done
  echo -e "  ${GREEN}║${NC}  Topics: ${TOPICS}"
  echo -e "  ${GREEN}║${NC}  Visibility: Private"
  echo -e "  ${GREEN}║${NC}"
  echo -e "  ${GREEN}║${NC}  Next steps:"
  echo -e "  ${GREEN}║${NC}    1. Run push-to-github.sh to push initial commits"
  echo -e "  ${GREEN}║${NC}    2. Re-run this script to apply branch protection"
  echo -e "  ${GREEN}║${NC}    3. Add GitHub Secrets for CI/CD (see workflows/)"
  echo -e "  ${GREEN}║${NC}"
  echo -e "${GREEN}  ╚══════════════════════════════════════════════════════════╝${NC}"
}

# ---- Main -------------------------------------------------------------------

main() {
  echo ""
  echo -e "${BLUE}  ╔══════════════════════════════════════════════════════════╗"
  echo -e "  ║     DAKKHO GitHub Repository Setup                      ║"
  echo -e "  ║     Account: ${GITHUB_EMAIL}              ║"
  echo -e "  ╚══════════════════════════════════════════════════════════╝${NC}"
  echo ""

  check_gh_cli
  echo ""
  authenticate
  echo ""
  create_all_repos
  setup_all_branch_protection
  print_summary
}

main "$@"
