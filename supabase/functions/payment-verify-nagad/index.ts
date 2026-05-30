// DAKKHO — Nagad Payment Verification Edge Function
// Verifies Nagad payments with RSA-SHA256 signing using Deno's Web Crypto API
// Updates subscriptions via Supabase

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const NAGAD_BASE_URL_SANDBOX = 'https://sandbox.mynagad.com'
const NAGAD_BASE_URL_PRODUCTION = 'https://api.mynagad.com'

function getBaseUrl(): string {
  return Deno.env.get('NAGAD_SANDBOX') === 'true' ? NAGAD_BASE_URL_SANDBOX : NAGAD_BASE_URL_PRODUCTION
}

/**
 * Import a PEM-formatted private key using Web Crypto API
 */
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/-----BEGIN RSA PRIVATE KEY-----/, '')
    .replace(/-----END RSA PRIVATE KEY-----/, '')
    .replace(/\s/g, '')

  const binaryStr = atob(pemBody)
  const bytes = new Uint8Array(binaryStr.length)
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i)
  }

  return await crypto.subtle.importKey(
    'pkcs8',
    bytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
}

/**
 * Import a PEM-formatted public key using Web Crypto API
 */
async function importPublicKey(pem: string): Promise<CryptoKey> {
  const pemBody = pem
    .replace(/-----BEGIN PUBLIC KEY-----/, '')
    .replace(/-----END PUBLIC KEY-----/, '')
    .replace(/\s/g, '')

  const binaryStr = atob(pemBody)
  const bytes = new Uint8Array(binaryStr.length)
  for (let i = 0; i < binaryStr.length; i++) {
    bytes[i] = binaryStr.charCodeAt(i)
  }

  return await crypto.subtle.importKey(
    'spki',
    bytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify']
  )
}

/**
 * Sign data with RSA-SHA256 using Web Crypto API
 */
async function signWithPrivateKey(data: string): Promise<string> {
  const privateKeyPem = Deno.env.get('NAGAD_PRIVATE_KEY')
  if (!privateKeyPem) throw new Error('NAGAD_PRIVATE_KEY not configured')

  const key = await importPrivateKey(privateKeyPem)
  const encoder = new TextEncoder()
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(data))

  // Convert ArrayBuffer to base64
  const bytes = new Uint8Array(signature)
  let binary = ''
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
}

/**
 * Verify signature with RSA-SHA256 using Web Crypto API
 */
async function verifyWithPublicKey(data: string, signature: string): Promise<boolean> {
  const publicKeyPem = Deno.env.get('NAGAD_PUBLIC_KEY')
  if (!publicKeyPem) throw new Error('NAGAD_PUBLIC_KEY not configured')

  const key = await importPublicKey(publicKeyPem)
  const encoder = new TextEncoder()

  // Convert base64 signature to ArrayBuffer
  const binaryStr = atob(signature)
  const sigBytes = new Uint8Array(binaryStr.length)
  for (let i = 0; i < binaryStr.length; i++) {
    sigBytes[i] = binaryStr.charCodeAt(i)
  }

  return await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    sigBytes.buffer,
    encoder.encode(data)
  )
}

/**
 * Generate random hex string using Web Crypto API
 */
function randomHex(bytes: number): string {
  const arr = new Uint8Array(bytes)
  crypto.getRandomValues(arr)
  return Array.from(arr).map(b => b.toString(16).padStart(2, '0')).join('')
}

async function verifyNagadPayment(paymentRefId: string): Promise<Record<string, unknown>> {
  const baseUrl = getBaseUrl()
  const merchantId = Deno.env.get('NAGAD_MERCHANT_ID')

  if (!merchantId) throw new Error('NAGAD_MERCHANT_ID not configured')

  // Step 1: Initialize verification
  const dateStr = new Date().toISOString()
  const randomStr = randomHex(16)

  const sensitiveData = JSON.stringify({
    merchantId,
    orderRef: paymentRefId,
    challenge: randomStr,
  })

  const signature = await signWithPrivateKey(sensitiveData)

  const response = await fetch(`${baseUrl}/api/dfs/verify/payment`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-KM-Api-Version': 'v-0.2.0',
      'X-KM-IP-V4': Deno.env.get('NAGAD_MERCHANT_IP') || '127.0.0.1',
      'X-KM-Client-Type': 'PC_WEB',
      Date: dateStr,
    },
    body: JSON.stringify({
      accountNumber: merchantId,
      paymentRefId,
      sensitiveData,
      signature,
    }),
  })

  return response.json()
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const { paymentRefId, courseId, userId } = body

    if (!paymentRefId || !courseId || !userId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required fields: paymentRefId, courseId, userId',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 1: Verify with Nagad
    console.log(`Verifying Nagad payment ${paymentRefId}...`)
    const nagadResult = await verifyNagadPayment(paymentRefId)

    if (nagadResult.status !== 'SUCCESS' && nagadResult.message !== 'Successful') {
      console.error(`Nagad verify failed: ${JSON.stringify(nagadResult)}`)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Payment verification failed',
          nagadResponse: nagadResult,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 2: Verify signature from Nagad
    if (nagadResult.signature && nagadResult.sensitiveData) {
      const isValid = await verifyWithPublicKey(
        nagadResult.sensitiveData as string,
        nagadResult.signature as string
      )
      if (!isValid) {
        console.error('Nagad response signature verification failed')
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Signature verification failed — possible tampering',
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Step 3: Update subscription in Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const now = new Date()
    const expiresAt = new Date(now)
    expiresAt.setDate(expiresAt.getDate() + 30)

    const { data: existingSubs, error: queryError } = await supabase
      .from('subscriptions')
      .select('*')
      .eq('user_id', userId)
      .eq('status', 'active')

    if (queryError) {
      console.error(`Subscription query error: ${queryError.message}`)
    }

    let subscriptionId: string

    if (existingSubs && existingSubs.length > 0) {
      const current = existingSubs[0]
      const currentExpiry = new Date(current.expires_at)
      const newExpiry = currentExpiry > now
        ? new Date(currentExpiry.getTime() + 30 * 24 * 60 * 60 * 1000)
        : expiresAt

      const { data: updated, error: updateError } = await supabase
        .from('subscriptions')
        .update({
          plan: 'basic',
          status: 'active',
          expires_at: newExpiry.toISOString(),
          payment_id: (nagadResult.paymentRefId as string) || paymentRefId,
          auto_renew: false,
        })
        .eq('id', current.id)
        .select('id')
        .single()

      if (updateError) {
        throw new Error(`Failed to update subscription: ${updateError.message}`)
      }
      subscriptionId = updated.id
    } else {
      const { data: created, error: createError } = await supabase
        .from('subscriptions')
        .insert({
          user_id: userId,
          plan: 'basic',
          status: 'active',
          started_at: now.toISOString(),
          expires_at: expiresAt.toISOString(),
          payment_id: (nagadResult.paymentRefId as string) || paymentRefId,
          auto_renew: false,
          trial_days_remaining: 0,
          features_json: JSON.stringify({ basic: true }),
        })
        .select('id')
        .single()

      if (createError) {
        throw new Error(`Failed to create subscription: ${createError.message}`)
      }
      subscriptionId = created.id
    }

    // Step 4: Audit log
    await supabase.from('audit_logs').insert({
      actor_id: userId,
      actor_type: 'user',
      action: 'payment.verify.nagad',
      resource_type: 'subscriptions',
      resource_id: subscriptionId,
      metadata: JSON.stringify({
        paymentRefId,
        amount: nagadResult.amount,
        courseId,
      }),
      severity: 'info',
    })

    console.log(`Nagad payment verified: refId=${paymentRefId}, amount=${nagadResult.amount}`)

    return new Response(
      JSON.stringify({
        success: true,
        paymentRefId,
        amount: nagadResult.amount,
        subscriptionId,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error(`Nagad payment verification failed: ${err.message}`)
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
