# DAKKHO — Supabase Integration Guide

## Architecture: Appwrite = Primary | Supabase = Complementary

| Feature | Appwrite (Primary) | Supabase (Complementary) |
|---------|-------------------|-------------------------|
| Auth | ✅ Main auth provider | ❌ Not used |
| Document DB | ✅ Courses, videos, quizzes | ❌ Not used |
| File Storage | ✅ Videos, documents, avatars | ❌ Not used |
| Functions | ✅ Payment, device, email | ✅ Analytics batch, recommendations |
| Realtime | ✅ Chat messages | ✅ Presence, leaderboard, notifications |
| Analytics | ❌ Basic only | ✅ Full event tracking + aggregation |
| AI/ML | ❌ Not available | ✅ pgvector semantic search |
| Cron Jobs | ❌ Not available | ✅ pg_cron scheduled tasks |
| Complex Queries | ❌ Limited (document DB) | ✅ SQL joins, aggregations |
| Leaderboards | ❌ Not available | ✅ Computed rankings |
| Search | ❌ Basic only | ✅ Full-text + vector hybrid search |

## Setup Steps

### 1. Flutter Dependency

Already added to `pubspec.yaml`:
```yaml
dependencies:
  supabase_flutter: ^2.0.0
```

### 2. Initialize in main.dart

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadEnvConfig();

  // Supabase is initialized inside AppConfigNotifier._initialize()
  // No manual initialization needed — it's handled automatically.

  runApp(const ProviderScope(child: DakkhoApp()));
}
```

### 3. Run SQL Migration

Go to Supabase Dashboard → SQL Editor → Paste contents of:
`/home/z/my-project/dakkho-cloud/supabase/migrations/001_initial_schema.sql`

This creates:
- 10 tables (analytics, progress, leaderboards, embeddings, presence, streaks, search, notifications, A/B tests, cron logs)
- pgvector indexes for semantic search
- RLS policies for data isolation
- pg_cron jobs for scheduled tasks
- Helper functions for search

### 4. Deploy Edge Functions

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link project
supabase link --project-ref spomlopbjuihpgpzwdqb

# Deploy functions
supabase functions deploy recommendations
supabase functions deploy leaderboard-compute
supabase functions deploy analytics-batch
supabase functions deploy embed-content
supabase functions deploy study-reminder
```

### 5. Using Supabase in Flutter

```dart
// Access via Riverpod provider
final supabase = ref.watch(supabaseClientProvider);

// Track learning event
await supabase.from('learning_analytics').insert({
  'user_id': userId,
  'event_type': 'video_watch',
  'course_id': courseId,
  'video_id': videoId,
  'duration_secs': watchDuration,
});

// Get leaderboard
final leaderboard = await supabase
  .from('leaderboards')
  .select()
  .eq('course_id', courseId)
  .eq('board_type', 'weekly')
  .order('rank_position')
  .limit(50);

// Semantic search
final results = await supabase.rpc('find_similar_content', {
  'query_embedding': embeddingVector,
  'match_threshold': 0.75,
  'match_count': 20,
});

// Realtime subscription (chat presence)
supabase.channel('chat')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'chat_presence',
    callback: (payload) => print('Presence change: ${payload.newRecord}'),
  )
  .subscribe();

// Get AI recommendations
final response = await supabase.functions.invoke(
  'recommendations',
  body: {'user_id': userId, 'limit': 10},
);
```

## Environment Variables

```env
SUPABASE_URL=https://spomlopbjuihpgpzwdqb.supabase.co
SUPABASE_ANON_KEY=sb_publishable_OIIoh_xHF4-LpBztS80ydQ_xs2wAME2
```

## Supabase Free Tier Limits

| Resource | Free Limit |
|----------|-----------|
| Database | 500 MB |
| Auth | 50,000 MAU |
| Storage | 1 GB |
| Edge Functions | 500K invocations/month |
| Realtime | 200 concurrent connections |
| pgvector | Included |
| pg_cron | Included |

## When to Use Which Service

### Use Appwrite when:
- User authentication (signup, login, OAuth)
- CRUD operations on documents (courses, videos, quizzes)
- File upload/download (videos, PDFs, avatars)
- Server-side functions (payment verification, email sending)
- Basic realtime subscriptions (chat messages)

### Use Supabase when:
- Analytics event tracking (batch writes)
- Leaderboard computations (SQL aggregations)
- AI-powered recommendations (pgvector)
- Semantic search (full-text + vector)
- Scheduled jobs (daily leaderboards, cleanup)
- Complex queries (multi-table joins, window functions)
- A/B testing assignments
- Realtime presence (who's online)
