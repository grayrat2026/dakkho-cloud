#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# DAKKHO — Supabase Setup Script
# ═══════════════════════════════════════════════════════════════
# This script deploys SQL migrations and Edge Functions to Supabase.
# Run after the main cloud setup is complete.
# ═══════════════════════════════════════════════════════════════

set -e

SUPABASE_URL="https://spomlopbjuihpgpzwdqb.supabase.co"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "═══════════════════════════════════════════════════════════"
echo "  DAKKHO — Supabase Complementary Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Architecture: Appwrite = Primary | Supabase = Complementary"
echo "  Appwrite → Auth, Document DB, File Storage, Functions"
echo "  Supabase → Analytics, AI/ML, Realtime, Cron, Queries"
echo ""

# ─── Step 1: Check Supabase CLI ────────────────────────────────
echo "🔍 Step 1: Checking Supabase CLI..."
if ! command -v supabase &> /dev/null; then
    echo "  ⚠️  Supabase CLI not found. Installing..."
    npm install -g supabase
    echo "  ✅ Supabase CLI installed"
else
    echo "  ✅ Supabase CLI found: $(supabase --version)"
fi

# ─── Step 2: Deploy SQL Migration ──────────────────────────────
echo ""
echo "📊 Step 2: Deploying SQL migration..."
echo "  This creates 10 tables, indexes, RLS policies, cron jobs, and functions."
echo ""
echo "  ⚠️  IMPORTANT: Run the SQL migration manually in Supabase Dashboard:"
echo "  1. Go to: ${SUPABASE_URL}/project/_/sql"
echo "  2. Click 'New Query'"
echo "  3. Paste the contents of: ${SCRIPT_DIR}/migrations/001_initial_schema.sql"
echo "  4. Click 'Run'"
echo ""
read -p "  Press Enter after running the SQL migration in dashboard..."

# ─── Step 3: Link Project ─────────────────────────────────────
echo ""
echo "🔗 Step 3: Linking Supabase project..."
if [ ! -f "${SCRIPT_DIR}/../.supabase/config.toml" ]; then
    echo "  Running: supabase link --project-ref spomlopbjuihpgpzwdqb"
    supabase link --project-ref spomlopbjuihpgpzwdqb || echo "  ⚠️  Link may require login: supabase login"
else
    echo "  ✅ Project already linked"
fi

# ─── Step 4: Deploy Edge Functions ─────────────────────────────
echo ""
echo "⚡ Step 4: Deploying Edge Functions..."

for func in recommendations leaderboard-compute analytics-batch embed-content study-reminder; do
    if [ -d "${SCRIPT_DIR}/functions/${func}" ]; then
        echo "  Deploying: ${func}..."
        supabase functions deploy "$func" --project-ref spomlopbjuihpgpzwdqb || echo "  ⚠️  Failed to deploy ${func}"
    else
        echo "  ⏭️  Skipping ${func} (directory not found)"
    fi
done

# ─── Step 5: Verify ───────────────────────────────────────────
echo ""
echo "✅ Supabase Setup Complete!"
echo ""
echo "  Verify at: ${SUPABASE_URL}/project/_/editor"
echo ""
echo "  Tables should include:"
echo "    - learning_analytics"
echo "    - progress_snapshots"
echo "    - leaderboards"
echo "    - content_embeddings"
echo "    - chat_presence"
echo "    - study_streaks"
echo "    - search_index"
echo "    - notification_log"
echo "    - ab_tests / ab_test_assignments"
echo "    - cron_job_log"
echo ""
echo "  Cron jobs should be active:"
echo "    - daily-leaderboard (00:05 UTC)"
echo "    - cleanup-expired (03:00 UTC)"
echo "    - weekly-progress-report (Mon 06:00 UTC)"
echo "    - update-study-streaks (00:30 UTC)"
echo ""
echo "═══════════════════════════════════════════════════════════"
