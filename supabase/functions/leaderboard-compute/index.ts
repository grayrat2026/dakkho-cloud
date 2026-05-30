// DAKKHO — Leaderboard Compute Edge Function
// Computes and caches leaderboard rankings on demand
// Complements Appwrite which stores course/quiz data

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { course_id, board_type = 'weekly', limit = 50 } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    const periodDays = {
      daily: 1,
      weekly: 7,
      monthly: 30,
      all_time: 36500
    }[board_type] || 7

    // Compute leaderboard from progress snapshots
    const { data: leaderboard } = await supabase
      .from('leaderboards')
      .select('user_id, rank_position, score, total_watch_secs, quizzes_passed, streak_days')
      .eq('board_type', board_type)
      .eq('course_id', course_id || null)
      .order('rank_position', { ascending: true })
      .limit(limit)

    if (leaderboard && leaderboard.length > 0) {
      return new Response(
        JSON.stringify({ leaderboard, board_type, course_id }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Fallback: Compute on-the-fly from analytics
    const { data: analytics } = await supabase
      .from('learning_analytics')
      .select('user_id, duration_secs, event_type, event_data')
      .gte('created_at', new Date(Date.now() - periodDays * 86400000).toISOString())
      .eq(course_id ? 'course_id' : 'id', course_id || undefined)

    // Aggregate user scores
    const userScores = {}
    for (const event of (analytics || [])) {
      if (!userScores[event.user_id]) {
        userScores[event.user_id] = { watch_secs: 0, quizzes: 0, score: 0 }
      }
      userScores[event.user_id].watch_secs += event.duration_secs || 0
      if (event.event_type === 'quiz_attempt') {
        userScores[event.user_id].quizzes += 1
        userScores[event.user_id].score += (event.event_data?.score || 0)
      }
    }

    const computedLeaderboard = Object.entries(userScores)
      .map(([user_id, data]) => ({
        user_id,
        score: data.score,
        total_watch_secs: data.watch_secs,
        quizzes_passed: data.quizzes,
      }))
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
      .map((entry, i) => ({ ...entry, rank_position: i + 1 }))

    return new Response(
      JSON.stringify({ leaderboard: computedLeaderboard, board_type, course_id, computed: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
