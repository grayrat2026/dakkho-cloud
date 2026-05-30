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
    const { user_id } = await req.json()
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )
    // Get user's study streak and active courses
    const { data: streak } = await supabase.from('study_streaks')
      .select('*').eq('user_id', user_id).single()
    const { data: progress } = await supabase.from('progress_snapshots')
      .select('course_id, completion_pct').eq('user_id', user_id)
      .order('snapshot_date', { ascending: false }).limit(5)
    return new Response(JSON.stringify({ streak, progress }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
