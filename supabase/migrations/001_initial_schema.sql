-- ═══════════════════════════════════════════════════════════════
-- DAKKHO — Supabase Complementary Tables
-- ═══════════════════════════════════════════════════════════════
-- Architecture: Appwrite = Primary | Supabase = Complementary
-- ─────────────────────────────────────────────────────────────
-- Appwrite handles: Auth, Document DB, File Storage, Serverless Functions
-- Supabase handles: Analytics, AI/ML, Realtime, Cron, Complex Queries
-- ═══════════════════════════════════════════════════════════════

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "vector";       -- pgvector for AI/ML
CREATE EXTENSION IF NOT EXISTS "pg_cron";      -- Scheduled jobs
CREATE EXTENSION IF NOT EXISTS "pg_trgm";      -- Trigram fuzzy search
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";    -- UUID generation

-- ───────────────────────────────────────────────────────────────
-- 1. LEARNING ANALYTICS
-- Tracks every learning interaction for progress tracking
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS learning_analytics (
    id            UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id       TEXT NOT NULL,                    -- Appwrite user ID
    event_type    TEXT NOT NULL,                    -- video_watch, quiz_attempt, lesson_complete, etc.
    event_data    JSONB DEFAULT '{}',               -- Flexible event payload
    course_id     TEXT,                             -- Appwrite course document ID
    chapter_id    TEXT,                             -- Appwrite chapter document ID
    video_id      TEXT,                             -- Appwrite video document ID
    duration_secs INTEGER DEFAULT 0,                -- Watch duration / time spent
    created_at    TIMESTAMPTZ DEFAULT NOW(),

    -- Indexes for common query patterns
    CONSTRAINT valid_event_type CHECK (event_type IN (
        'video_watch', 'video_complete', 'quiz_attempt', 'quiz_complete',
        'lesson_complete', 'chapter_complete', 'course_enroll', 'course_complete',
        'live_class_join', 'live_class_leave', 'doubt_posted', 'doubt_resolved',
        'download_start', 'download_complete', 'app_open', 'app_close'
    ))
);

CREATE INDEX idx_analytics_user_id ON learning_analytics (user_id);
CREATE INDEX idx_analytics_event_type ON learning_analytics (event_type);
CREATE INDEX idx_analytics_course_id ON learning_analytics (course_id);
CREATE INDEX idx_analytics_created_at ON learning_analytics (created_at);
CREATE INDEX idx_analytics_user_course ON learning_analytics (user_id, course_id);
CREATE INDEX idx_analytics_user_date ON learning_analytics (user_id, created_at DESC);

-- ───────────────────────────────────────────────────────────────
-- 2. PROGRESS SNAPSHOTS
-- Pre-computed daily/weekly/monthly progress per student
-- Updated by pg_cron jobs
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS progress_snapshots (
    id                UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id           TEXT NOT NULL,
    course_id         TEXT NOT NULL,
    snapshot_type     TEXT NOT NULL DEFAULT 'daily',   -- daily, weekly, monthly
    total_watch_secs  INTEGER DEFAULT 0,
    videos_completed  INTEGER DEFAULT 0,
    quizzes_taken     INTEGER DEFAULT 0,
    quiz_avg_score    DECIMAL(5,2) DEFAULT 0,
    chapters_completed INTEGER DEFAULT 0,
    completion_pct    DECIMAL(5,2) DEFAULT 0,           -- 0.00–100.00
    streak_days       INTEGER DEFAULT 0,
    snapshot_date     DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at        TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_snapshot_type CHECK (snapshot_type IN ('daily', 'weekly', 'monthly')),
    CONSTRAINT unique_user_course_date UNIQUE (user_id, course_id, snapshot_type, snapshot_date)
);

CREATE INDEX idx_progress_user ON progress_snapshots (user_id);
CREATE INDEX idx_progress_course ON progress_snapshots (course_id);
CREATE INDEX idx_progress_date ON progress_snapshots (snapshot_date DESC);
CREATE INDEX idx_progress_user_date ON progress_snapshots (user_id, snapshot_date DESC);

-- ───────────────────────────────────────────────────────────────
-- 3. LEADERBOARDS
-- Ranked student performance across multiple dimensions
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS leaderboards (
    id                UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id           TEXT NOT NULL,
    course_id         TEXT,                              -- NULL = global leaderboard
    board_type        TEXT NOT NULL DEFAULT 'weekly',    -- daily, weekly, monthly, all_time
    rank_position     INTEGER NOT NULL,
    score             DECIMAL(10,2) DEFAULT 0,
    total_watch_secs  INTEGER DEFAULT 0,
    quizzes_passed    INTEGER DEFAULT 0,
    streak_days       INTEGER DEFAULT 0,
    period_start      DATE,
    period_end        DATE,
    updated_at        TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_board_type CHECK (board_type IN ('daily', 'weekly', 'monthly', 'all_time'))
);

CREATE INDEX idx_leaderboard_course_type ON leaderboards (course_id, board_type);
CREATE INDEX idx_leaderboard_rank ON leaderboards (board_type, rank_position);
CREATE INDEX idx_leaderboard_user ON leaderboards (user_id, board_type);

-- ───────────────────────────────────────────────────────────────
-- 4. CONTENT EMBEDDINGS (pgvector)
-- AI-powered semantic search, recommendations, quiz similarity
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS content_embeddings (
    id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    content_type    TEXT NOT NULL,                     -- course, video, quiz, chapter
    content_id      TEXT NOT NULL,                     -- Appwrite document ID
    title           TEXT,
    description     TEXT,
    tags            TEXT[] DEFAULT '{}',                -- Bengali + English tags
    embedding       vector(1536),                       -- OpenAI text-embedding-3-small
    metadata        JSONB DEFAULT '{}',                 -- Extra searchable metadata
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_content_type CHECK (content_type IN ('course', 'video', 'quiz', 'chapter', 'document')),
    CONSTRAINT unique_content UNIQUE (content_type, content_id)
);

-- HNSW index for fast approximate nearest neighbor search
CREATE INDEX idx_embeddings_vector ON content_embeddings
    USING hnsw (embedding vector_cosine_ops);

-- GIN index for tag-based filtering
CREATE INDEX idx_embeddings_tags ON content_embeddings USING GIN (tags);

-- Trigram index for fuzzy text search on title
CREATE INDEX idx_embeddings_title_trgm ON content_embeddings
    USING GIN (title gin_trgm_ops);

-- ───────────────────────────────────────────────────────────────
-- 5. CHAT PRESENCE
-- Real-time online status for study groups & community
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS chat_presence (
    id          UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id     TEXT NOT NULL,
    room_id     TEXT NOT NULL,                         -- course_id or 'community'
    status      TEXT NOT NULL DEFAULT 'online',        -- online, away, offline
    last_seen   TIMESTAMPTZ DEFAULT NOW(),
    metadata    JSONB DEFAULT '{}',

    CONSTRAINT valid_status CHECK (status IN ('online', 'away', 'offline')),
    CONSTRAINT unique_user_room UNIQUE (user_id, room_id)
);

CREATE INDEX idx_presence_room ON chat_presence (room_id, status);
CREATE INDEX idx_presence_last_seen ON chat_presence (last_seen DESC);

-- ───────────────────────────────────────────────────────────────
-- 6. STUDY STREAKS
-- Daily login + content interaction tracking for gamification
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS study_streaks (
    id                UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id           TEXT NOT NULL UNIQUE,
    current_streak    INTEGER DEFAULT 0,
    longest_streak    INTEGER DEFAULT 0,
    last_active_date  DATE DEFAULT CURRENT_DATE,
    total_active_days INTEGER DEFAULT 0,
    updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_streaks_current ON study_streaks (current_streak DESC);
CREATE INDEX idx_streaks_user ON study_streaks (user_id);

-- ───────────────────────────────────────────────────────────────
-- 7. SEARCH INDEX
-- Unified full-text + vector search across all content
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS search_index (
    id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    content_type    TEXT NOT NULL,
    content_id      TEXT NOT NULL,
    title_bn        TEXT,                              -- Bengali title
    title_en        TEXT,                              -- English title
    description_bn  TEXT,
    description_en  TEXT,
    keywords        TEXT[] DEFAULT '{}',
    search_vector   tsvector,                          -- Full-text search vector
    embedding       vector(1536),                       -- Semantic search vector
    popularity      INTEGER DEFAULT 0,                  -- Sort by popularity
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_search_content_type CHECK (content_type IN ('course', 'video', 'quiz', 'chapter', 'instructor')),
    CONSTRAINT unique_search_content UNIQUE (content_type, content_id)
);

-- GIN index for full-text search
CREATE INDEX idx_search_vector ON search_index USING GIN (search_vector);

-- HNSW index for semantic search
CREATE INDEX idx_search_embedding ON search_index
    USING hnsw (embedding vector_cosine_ops);

-- Trigram indexes for fuzzy matching
CREATE INDEX idx_search_title_bn_trgm ON search_index USING GIN (title_bn gin_trgm_ops);
CREATE INDEX idx_search_title_en_trgm ON search_index USING GIN (title_en gin_trgm_ops);

-- ───────────────────────────────────────────────────────────────
-- 8. NOTIFICATION LOG
-- Delivery tracking + read receipts for push notifications
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notification_log (
    id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id         TEXT NOT NULL,
    onesignal_id    TEXT,                              -- OneSignal notification ID
    category        TEXT NOT NULL,                     -- live_class, subscription, etc.
    title           TEXT,
    body            TEXT,
    data            JSONB DEFAULT '{}',
    is_read         BOOLEAN DEFAULT FALSE,
    delivered_at    TIMESTAMPTZ,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_notif_category CHECK (category IN (
        'live_class', 'subscription', 'study_reminder', 'announcement', 'system',
        'quiz_result', 'badge_earned', 'payment', 'doubt_resolved'
    ))
);

CREATE INDEX idx_notif_user ON notification_log (user_id, created_at DESC);
CREATE INDEX idx_notif_unread ON notification_log (user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notif_category ON notification_log (category);

-- ───────────────────────────────────────────────────────────────
-- 9. A/B TESTS
-- Feature flag experiments for admin-controlled rollouts
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ab_tests (
    id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    test_name       TEXT NOT NULL UNIQUE,
    description     TEXT,
    variant_a       JSONB DEFAULT '{}',               -- Control group config
    variant_b       JSONB DEFAULT '{}',               -- Test group config
    traffic_pct     INTEGER DEFAULT 50,                -- % of users in variant B
    is_active       BOOLEAN DEFAULT FALSE,
    started_at      TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ab_test_assignments (
    id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    test_name       TEXT NOT NULL REFERENCES ab_tests(test_name),
    user_id         TEXT NOT NULL,
    variant         TEXT NOT NULL DEFAULT 'A',         -- A or B
    assigned_at     TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_variant CHECK (variant IN ('A', 'B')),
    CONSTRAINT unique_test_user UNIQUE (test_name, user_id)
);

-- ───────────────────────────────────────────────────────────────
-- 10. CRON JOB LOG
-- Monitoring pg_cron scheduled task executions
-- ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cron_job_log (
    id              UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    job_name        TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'running',   -- running, success, failed
    started_at      TIMESTAMPTZ DEFAULT NOW(),
    finished_at     TIMESTAMPTZ,
    duration_ms     INTEGER,
    rows_affected   INTEGER DEFAULT 0,
    error_message   TEXT,
    metadata        JSONB DEFAULT '{}',

    CONSTRAINT valid_cron_status CHECK (status IN ('running', 'success', 'failed'))
);

CREATE INDEX idx_cron_job_name ON cron_job_log (job_name, started_at DESC);
CREATE INDEX idx_cron_failed ON cron_job_log (status) WHERE status = 'failed';

-- ───────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY (RLS)
-- Students can only access their own data
-- ───────────────────────────────────────────────────────────────

ALTER TABLE learning_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboards ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE study_streaks ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE ab_test_assignments ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only read/write their own data
CREATE POLICY "Users read own analytics" ON learning_analytics
    FOR SELECT USING (user_id = current_setting('request.jwt.claims')::json->>'sub');
CREATE POLICY "Users insert own analytics" ON learning_analytics
    FOR INSERT WITH CHECK (user_id = current_setting('request.jwt.claims')::json->>'sub');

CREATE POLICY "Users read own progress" ON progress_snapshots
    FOR SELECT USING (user_id = current_setting('request.jwt.claims')::json->>'sub');

CREATE POLICY "Anyone read leaderboards" ON leaderboards
    FOR SELECT USING (true);

CREATE POLICY "Users manage own presence" ON chat_presence
    FOR ALL USING (user_id = current_setting('request.jwt.claims')::json->>'sub');

CREATE POLICY "Users read own streaks" ON study_streaks
    FOR SELECT USING (user_id = current_setting('request.jwt.claims')::json->>'sub');

CREATE POLICY "Anyone read search" ON search_index
    FOR SELECT USING (true);

CREATE POLICY "Anyone read embeddings" ON content_embeddings
    FOR SELECT USING (true);

CREATE POLICY "Users read own notifications" ON notification_log
    FOR SELECT USING (user_id = current_setting('request.jwt.claims')::json->>'sub');
CREATE POLICY "Users update own notifications" ON notification_log
    FOR UPDATE USING (user_id = current_setting('request.jwt.claims')::json->>'sub');

-- ───────────────────────────────────────────────────────────────
-- REALTIME SUBSCRIPTIONS
-- Enable Realtime for chat presence and live class updates
-- ───────────────────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE chat_presence;
ALTER PUBLICATION supabase_realtime ADD TABLE leaderboards;
ALTER PUBLICATION supabase_realtime ADD TABLE notification_log;

-- ───────────────────────────────────────────────────────────────
-- pg_cron SCHEDULED JOBS
-- ───────────────────────────────────────────────────────────────

-- Daily leaderboard computation (00:05 UTC = 06:05 BST)
SELECT cron.schedule(
    'daily-leaderboard',
    '5 0 * * *',
    $$
    INSERT INTO cron_job_log (job_name, status, started_at)
    VALUES ('daily-leaderboard', 'running', NOW());

    -- Compute weekly leaderboard
    INSERT INTO leaderboards (user_id, course_id, board_type, rank_position, score, total_watch_secs, quizzes_passed, streak_days, period_start, period_end)
    SELECT
        user_id,
        course_id,
        'weekly',
        ROW_NUMBER() OVER (PARTITION BY course_id ORDER BY score DESC),
        score,
        total_watch_secs,
        quizzes_passed,
        streak_days,
        CURRENT_DATE - INTERVAL '7 days',
        CURRENT_DATE
    FROM (
        SELECT
            p.user_id,
            p.course_id,
            SUM(p.total_watch_secs) AS total_watch_secs,
            SUM(p.quizzes_taken) AS quizzes_passed,
            AVG(p.quiz_avg_score) AS score,
            MAX(p.streak_days) AS streak_days
        FROM progress_snapshots p
        WHERE p.snapshot_date >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY p.user_id, p.course_id
    ) ranked
    ON CONFLICT DO NOTHING;
    $$
);

-- Cleanup expired data (03:00 UTC = 09:00 BST)
SELECT cron.schedule(
    'cleanup-expired',
    '0 3 * * *',
    $$
    -- Prune analytics older than 90 days (aggregated in snapshots)
    DELETE FROM learning_analytics WHERE created_at < NOW() - INTERVAL '90 days';

    -- Prune old chat presence
    DELETE FROM chat_presence WHERE last_seen < NOW() - INTERVAL '24 hours';

    -- Prune old cron logs
    DELETE FROM cron_job_log WHERE started_at < NOW() - INTERVAL '30 days';

    -- Mark expired A/B tests as inactive
    UPDATE ab_tests SET is_active = FALSE WHERE ended_at < NOW() AND is_active = TRUE;
    $$
);

-- Weekly progress report generation (Monday 06:00 UTC = 12:00 BST)
SELECT cron.schedule(
    'weekly-progress-report',
    '0 6 * * 1',
    $$
    INSERT INTO progress_snapshots (user_id, course_id, snapshot_type, total_watch_secs, videos_completed, quizzes_taken, quiz_avg_score, chapters_completed, completion_pct, streak_days, snapshot_date)
    SELECT
        user_id,
        course_id,
        'weekly',
        SUM(duration_secs),
        COUNT(*) FILTER (WHERE event_type = 'video_complete'),
        COUNT(*) FILTER (WHERE event_type = 'quiz_attempt'),
        COALESCE(AVG((event_data->>'score')::DECIMAL), 0),
        COUNT(*) FILTER (WHERE event_type = 'chapter_complete'),
        0,  -- computed separately
        0,  -- computed from study_streaks
        CURRENT_DATE
    FROM learning_analytics
    WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY user_id, course_id
    ON CONFLICT (user_id, course_id, snapshot_type, snapshot_date) DO UPDATE SET
        total_watch_secs = EXCLUDED.total_watch_secs,
        videos_completed = EXCLUDED.videos_completed,
        quizzes_taken = EXCLUDED.quizzes_taken,
        quiz_avg_score = EXCLUDED.quiz_avg_score,
        updated_at = NOW();
    $$
);

-- Update study streaks (00:30 UTC = 06:30 BST)
SELECT cron.schedule(
    'update-study-streaks',
    '30 0 * * *',
    $$
    INSERT INTO study_streaks (user_id, current_streak, longest_streak, last_active_date, total_active_days)
    SELECT
        user_id,
        1,
        1,
        CURRENT_DATE,
        1
    FROM (SELECT DISTINCT user_id FROM learning_analytics WHERE created_at >= CURRENT_DATE) active_users
    ON CONFLICT (user_id) DO UPDATE SET
        current_streak = CASE
            WHEN study_streaks.last_active_date = CURRENT_DATE - 1 THEN study_streaks.current_streak + 1
            WHEN study_streaks.last_active_date = CURRENT_DATE THEN study_streaks.current_streak
            ELSE 1
        END,
        longest_streak = GREATEST(study_streaks.longest_streak, study_streaks.current_streak + 1),
        last_active_date = CURRENT_DATE,
        total_active_days = study_streaks.total_active_days + 1,
        updated_at = NOW();
    $$
);

-- ───────────────────────────────────────────────────────────────
-- HELPER FUNCTIONS
-- ───────────────────────────────────────────────────────────────

-- Semantic search function: find similar content by embedding
CREATE OR REPLACE FUNCTION find_similar_content(
    query_embedding vector(1536),
    match_threshold FLOAT DEFAULT 0.75,
    match_count INT DEFAULT 20,
    filter_content_type TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    content_type TEXT,
    content_id TEXT,
    title TEXT,
    description TEXT,
    tags TEXT[],
    metadata JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        ce.id,
        ce.content_type,
        ce.content_id,
        ce.title,
        ce.description,
        ce.tags,
        ce.metadata,
        1 - (ce.embedding <=> query_embedding) AS similarity
    FROM content_embeddings ce
    WHERE
        (filter_content_type IS NULL OR ce.content_type = filter_content_type)
        AND 1 - (ce.embedding <=> query_embedding) >= match_threshold
    ORDER BY ce.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Full-text + semantic hybrid search function
CREATE OR REPLACE FUNCTION hybrid_search(
    search_query TEXT,
    query_embedding vector(1536) DEFAULT NULL,
    match_count INT DEFAULT 20,
    semantic_weight FLOAT DEFAULT 0.7,
    text_weight FLOAT DEFAULT 0.3
)
RETURNS TABLE (
    id UUID,
    content_type TEXT,
    content_id TEXT,
    title_en TEXT,
    title_bn TEXT,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        si.id,
        si.content_type,
        si.content_id,
        si.title_en,
        si.title_bn,
        CASE
            WHEN query_embedding IS NOT NULL THEN
                (text_weight * ts_rank_cd(si.search_vector, plainto_tsquery('english', search_query)))
                + (semantic_weight * (1 - (si.embedding <=> query_embedding)))
            ELSE
                ts_rank_cd(si.search_vector, plainto_tsquery('english', search_query))
        END AS similarity
    FROM search_index si
    WHERE
        si.search_vector @@ plainto_tsquery('english', search_query)
        OR (query_embedding IS NOT NULL AND 1 - (si.embedding <=> query_embedding) >= 0.5)
        OR si.title_en ILIKE '%' || search_query || '%'
        OR si.title_bn ILIKE '%' || search_query || '%'
    ORDER BY similarity DESC
    LIMIT match_count;
END;
$$;

-- ───────────────────────────────────────────────────────────────
-- TRIGGER: Auto-update search_vector on insert/update
-- ───────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector :=
        setweight(to_tsvector('english', COALESCE(NEW.title_en, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.description_en, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.title_bn, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.description_bn, '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_search_vector
    BEFORE INSERT OR UPDATE ON search_index
    FOR EACH ROW
    EXECUTE FUNCTION update_search_vector();

-- ═══════════════════════════════════════════════════════════════
-- MIGRATION COMPLETE
-- ═══════════════════════════════════════════════════════════════
