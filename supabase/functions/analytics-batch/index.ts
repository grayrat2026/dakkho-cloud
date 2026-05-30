// DAKKHO — Analytics Batch Edge Function
// Processes learning analytics events in batch
// Complements Appwrite by handling high-frequency event writes

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
    const { events } = await req.json()

    if (!events || !Array.isArray(events) || events.length === 0) {
      return new Response(
        JSON.stringify({ error: 'events array is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (events.length > 50) {
      return new Response(
        JSON.stringify({ error: 'Maximum 50 events per batch' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )

    // Batch insert analytics events
    const { data, error } = await supabase
      .from('learning_analytics')
      .insert(events.map(event => ({
        user_id: event.user_id,
        event_type: event.event_type,
        event_data: event.event_data || {},
        course_id: event.course_id || null,
        chapter_id: event.chapter_id || null,
        video_id: event.video_id || null,
        duration_secs: event.duration_secs || 0,
      })))

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ success: true, events_processed: events.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
