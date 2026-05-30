// DAKKHO — Bunny CDN Upload Edge Function
// Creates Bunny video entry, generates upload URL
// Updates Appwrite video document via REST API
// Gracefully handles missing credentials (not yet configured)

import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Appwrite REST API helpers
const APPWRITE_ENDPOINT = Deno.env.get('APPWRITE_ENDPOINT') || 'https://sgp.cloud.appwrite.io/v1'
const APPWRITE_PROJECT_ID = Deno.env.get('APPWRITE_PROJECT_ID') || 'dakkho'
const APPWRITE_API_KEY = Deno.env.get('APPWRITE_API_KEY')

const appwriteHeaders: Record<string, string> = {
  'Content-Type': 'application/json',
  'X-Appwrite-Project': APPWRITE_PROJECT_ID,
  'X-Appwrite-Key': APPWRITE_API_KEY || '',
  'X-Appwrite-Response-Format': '1.6.0',
}

const DATABASE_ID = 'dakkho-main'
const VIDEOS_COLLECTION = 'videos'

/**
 * Update document in Appwrite via REST API
 */
async function updateAppwriteDoc(
  collectionId: string,
  docId: string,
  data: Record<string, unknown>
) {
  const resp = await fetch(
    `${APPWRITE_ENDPOINT}/databases/${DATABASE_ID}/collections/${collectionId}/documents/${docId}`,
    {
      method: 'PATCH',
      headers: appwriteHeaders,
      body: JSON.stringify({ data }),
    }
  )
  if (!resp.ok) {
    const errText = await resp.text()
    throw new Error(`Appwrite update failed (${resp.status}): ${errText}`)
  }
  return resp.json()
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const { videoId, libraryId } = body

    if (!videoId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required field: videoId',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const apiKey = Deno.env.get('BUNNY_API_KEY')
    const bunnyLibraryId = libraryId || Deno.env.get('BUNNY_LIBRARY_ID')

    // Gracefully handle missing Bunny CDN credentials
    if (!apiKey || !bunnyLibraryId) {
      console.error('Bunny CDN credentials not configured')
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Bunny CDN not configured yet. Admin needs to set BUNNY_API_KEY and BUNNY_LIBRARY_ID in function environment variables.',
          hint: 'Configure secrets in Supabase Dashboard → Edge Functions → Secrets',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 1: Create video entry in Bunny library
    console.log(`Creating Bunny video entry in library ${bunnyLibraryId}...`)
    const createResponse = await fetch(
      `https://video.bunnycdn.com/library/${bunnyLibraryId}/videos`,
      {
        method: 'POST',
        headers: {
          AccessKey: apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ title: `DAKKHO_${videoId}` }),
      }
    )

    if (!createResponse.ok) {
      const errText = await createResponse.text()
      throw new Error(`Bunny create video failed (${createResponse.status}): ${errText}`)
    }

    const createData = await createResponse.json()
    const bunnyVideoId = createData.guid

    console.log(`Bunny video created: ${bunnyVideoId}`)

    // Step 2: Generate upload URL (TUS protocol)
    const uploadUrl = `https://video.bunnycdn.com/library/${bunnyLibraryId}/videos/${bunnyVideoId}`

    // Step 3: Update video document in Appwrite
    if (APPWRITE_API_KEY) {
      try {
        await updateAppwriteDoc(VIDEOS_COLLECTION, videoId, {
          bunny_video_id: bunnyVideoId,
        })
        console.log(`Updated video document ${videoId} with bunny_video_id: ${bunnyVideoId}`)
      } catch (updateErr) {
        console.error(`Failed to update video document: ${(updateErr as Error).message}`)
        // Non-fatal
      }
    } else {
      console.warn('APPWRITE_API_KEY not configured, skipping video document update')
    }

    return new Response(
      JSON.stringify({
        success: true,
        bunnyVideoId,
        uploadUrl,
        uploadHeaders: {
          AccessKey: apiKey,
          'Content-Type': 'application/octet-stream',
        },
        libraryId: bunnyLibraryId,
        // Status check URL
        statusUrl: `https://video.bunnycdn.com/library/${bunnyLibraryId}/videos/${bunnyVideoId}`,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error(`Bunny CDN upload failed: ${err.message}`)
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
