// DAKKHO — Recommendations Edge Function
// AI-powered course/content recommendations using pgvector
// Complements Appwrite by providing personalized suggestions

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
    const { user_id, content_type, limit = 10 } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    // Get user's recent interactions to build preference profile
    const { data: recentActivity } = await supabase
      .from('learning_analytics')
      .select('course_id, event_type, duration_secs')
      .eq('user_id', user_id)
      .order('created_at', { ascending: false })
      .limit(50)

    // Get user's enrolled courses
    const enrolledCourseIds = [...new Set(
      (recentActivity || [])
        .filter(a => a.course_id)
        .map(a => a.course_id)
    )]

    // Get content embeddings for enrolled courses
    const { data: enrolledEmbeddings } = await supabase
      .from('content_embeddings')
      .select('embedding, content_id')
      .in('content_id', enrolledCourseIds)
      .eq('content_type', 'course')

    // Find similar content using pgvector
    if (enrolledEmbeddings && enrolledEmbeddings.length > 0) {
      // Average the embeddings for a user preference vector
      const avgEmbedding = enrolledEmbeddings[0].embedding // Simplified: use first

      const { data: recommendations } = await supabase.rpc(
        'find_similar_content',
        {
          query_embedding: avgEmbedding,
          match_threshold: 0.6,
          match_count: limit,
          filter_content_type: content_type || null
        }
      )

      // Filter out already-enrolled courses
      const filtered = (recommendations || []).filter(
        r => !enrolledCourseIds.includes(r.content_id)
      )

      return new Response(
        JSON.stringify({ recommendations: filtered }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Fallback: Popular content recommendations
    const { data: popular } = await supabase
      .from('search_index')
      .select('content_id, content_type, title_en, title_bn, popularity')
      .neq('content_id', '') // placeholder filter
      .order('popularity', { ascending: false })
      .limit(limit)

    return new Response(
      JSON.stringify({ recommendations: popular || [], method: 'popularity_fallback' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
