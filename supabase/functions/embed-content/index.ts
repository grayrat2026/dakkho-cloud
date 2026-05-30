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
    const { content_type, content_id, title, description, tags } = await req.json()
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    )
    // Generate embedding via OpenAI (requires OPENAI_API_KEY secret)
    const openaiKey = Deno.env.get('OPENAI_API_KEY')
    let embedding = null
    if (openaiKey) {
      const response = await fetch('https://api.openai.com/v1/embeddings', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${openaiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: 'text-embedding-3-small', input: `${title} ${description}` })
      })
      const data = await response.json()
      embedding = data.data?.[0]?.embedding ?? null
    }
    const { error } = await supabase.from('content_embeddings').upsert({
      content_type, content_id, title, description, tags: tags || [], embedding
    }, { onConflict: 'content_type,content_id' })
    if (error) throw error
    return new Response(JSON.stringify({ success: true, has_embedding: !!embedding }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})
