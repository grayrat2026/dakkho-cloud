// DAKKHO — Video Upload Handler Edge Function
// Generates R2 presigned upload URLs using AWS Signature V4
// Uses Deno's Web Crypto API (no Node.js crypto dependency)
// Updates Appwrite video document via REST API

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
 * Compute SHA-256 hash using Web Crypto API
 */
async function sha256Hex(data: string): Promise<string> {
  const encoder = new TextEncoder()
  const hashBuffer = await crypto.subtle.digest('SHA-256', encoder.encode(data))
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

/**
 * Compute HMAC-SHA256 using Web Crypto API
 * Returns ArrayBuffer
 */
async function hmacSha256(key: Uint8Array | ArrayBuffer, message: string): Promise<ArrayBuffer> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    key instanceof ArrayBuffer ? key : key.buffer,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )
  const encoder = new TextEncoder()
  return await crypto.subtle.sign('HMAC', cryptoKey, encoder.encode(message))
}

/**
 * ArrayBuffer to hex string
 */
function bufferToHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

/**
 * Generate a presigned URL for Cloudflare R2 upload
 * R2 is S3-compatible, using AWS Signature V4
 * All crypto operations use Deno's Web Crypto API
 */
async function generatePresignedUrl(
  bucketName: string,
  objectKey: string,
  region = 'auto'
): Promise<string> {
  const accessKeyId = Deno.env.get('R2_ACCESS_KEY_ID')
  const secretAccessKey = Deno.env.get('R2_SECRET_ACCESS_KEY')
  const endpoint = Deno.env.get('R2_ENDPOINT')

  if (!accessKeyId || !secretAccessKey || !endpoint) {
    throw new Error('R2 credentials not configured')
  }

  // R2 endpoint format: https://<account_id>.r2.cloudflarestorage.com
  const host = endpoint.replace('https://', '').replace('http://', '')

  const now = new Date()
  const dateStamp = now.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z'
  const dateOnly = dateStamp.substring(0, 8)

  const expiration = 3600 // 1 hour

  // Build canonical request for presigned URL
  const method = 'PUT'
  const canonicalUri = `/${bucketName}/${objectKey}`

  const credential = `${accessKeyId}/${dateOnly}/${region}/s3/aws4_request`

  const queryParams = new URLSearchParams({
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': credential,
    'X-Amz-Date': dateStamp,
    'X-Amz-Expires': expiration.toString(),
    'X-Amz-SignedHeaders': 'host',
  })

  const canonicalHeaders = `host:${host}\n`
  const signedHeaders = 'host'
  const payloadHash = 'UNSIGNED-PAYLOAD'

  const canonicalRequest = [
    method,
    canonicalUri,
    queryParams.toString(),
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n')

  // Build string to sign
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    dateStamp,
    `${dateOnly}/${region}/s3/aws4_request`,
    await sha256Hex(canonicalRequest),
  ].join('\n')

  // Calculate signature using Web Crypto API
  const encoder = new TextEncoder()
  const kDate = await hmacSha256(encoder.encode(`AWS4${secretAccessKey}`), dateOnly)
  const kRegion = await hmacSha256(new Uint8Array(kDate), region)
  const kService = await hmacSha256(new Uint8Array(kRegion), 's3')
  const kSigning = await hmacSha256(new Uint8Array(kService), 'aws4_request')
  const signature = bufferToHex(await hmacSha256(new Uint8Array(kSigning), stringToSign))

  const presignedUrl = `${endpoint}${canonicalUri}?${queryParams.toString()}&X-Amz-Signature=${signature}`

  return presignedUrl
}

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
    const { videoId, fileName, courseId } = body

    if (!fileName) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required field: fileName',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const bucketName = Deno.env.get('R2_BUCKET_NAME')
    if (!bucketName) {
      console.error('R2_BUCKET_NAME not configured')
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Storage not configured',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Generate unique R2 path
    const uniqueId = crypto.randomUUID()
    const ext = fileName.split('.').pop()
    const r2Path = `videos/raw/${courseId || 'uncategorized'}/${uniqueId}.${ext}`

    // Generate presigned URL
    console.log(`Generating presigned URL for ${r2Path}...`)
    const presignedUrl = await generatePresignedUrl(bucketName, r2Path)

    // If videoId provided, update the video document in Appwrite
    if (videoId && APPWRITE_API_KEY) {
      try {
        await updateAppwriteDoc(VIDEOS_COLLECTION, videoId, {
          raw_file_id: r2Path,
          file_size_bytes: 0, // Will be updated after upload
        })
        console.log(`Updated video ${videoId} with R2 path: ${r2Path}`)
      } catch (updateErr) {
        console.error(`Failed to update video document: ${(updateErr as Error).message}`)
        // Non-fatal — URL is still valid
      }
    }

    console.log(`Presigned URL generated for ${r2Path}`)

    return new Response(
      JSON.stringify({
        success: true,
        uploadUrl: presignedUrl,
        r2Path,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/octet-stream',
        },
        expiresInSeconds: 3600,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error(`Video upload handler failed: ${err.message}`)
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
