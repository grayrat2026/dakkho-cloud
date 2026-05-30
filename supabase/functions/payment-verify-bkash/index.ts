// DAKKHO — bKash Payment Verification Edge Function
// Verifies bKash tokenized payments and updates subscriptions via Supabase

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// bKash API configuration
const BKASH_BASE_URL_SANDBOX = 'https://tokenized.sandbox.bka.sh/v1.2.0-beta'
const BKASH_BASE_URL_PRODUCTION = 'https://tokenized.pay.bka.sh/v1.2.0-beta'

function getBaseUrl(): string {
  return Deno.env.get('BKASH_SANDBOX') === 'true' ? BKASH_BASE_URL_SANDBOX : BKASH_BASE_URL_PRODUCTION
}

async function grantToken(): Promise<string> {
  const baseUrl = getBaseUrl()
  const response = await fetch(`${baseUrl}/tokenized/checkout/token/grant`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      username: Deno.env.get('BKASH_USERNAME') || '',
      password: Deno.env.get('BKASH_PASSWORD') || '',
    },
    body: JSON.stringify({
      app_key: Deno.env.get('BKASH_APP_KEY'),
      app_secret: Deno.env.get('BKASH_APP_SECRET'),
    }),
  })

  const data = await response.json()
  if (data.code !== '0000') {
    throw new Error(`bKash token grant failed: ${data.message || JSON.stringify(data)}`)
  }
  return data.id_token
}

async function verifyPayment(token: string, paymentId: string): Promise<Record<string, unknown>> {
  const baseUrl = getBaseUrl()
  const response = await fetch(`${baseUrl}/tokenized/checkout/payment/verify`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: token,
      'x-app-key': Deno.env.get('BKASH_APP_KEY') || '',
    },
    body: JSON.stringify({ paymentID: paymentId }),
  })
  return response.json()
}

async function executePayment(token: string, paymentId: string): Promise<Record<string, unknown>> {
  const baseUrl = getBaseUrl()
  const response = await fetch(`${baseUrl}/tokenized/checkout/payment/execute`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: token,
      'x-app-key': Deno.env.get('BKASH_APP_KEY') || '',
    },
    body: JSON.stringify({ paymentID: paymentId }),
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
    const { paymentId, courseId, userId } = body

    if (!paymentId || !courseId || !userId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required fields: paymentId, courseId, userId',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 1: Grant bKash token
    console.log('Granting bKash token...')
    const token = await grantToken()

    // Step 2: Verify the payment
    console.log(`Verifying payment ${paymentId}...`)
    const verifyResult = await verifyPayment(token, paymentId)

    if (verifyResult.statusCode !== '0000') {
      console.error(`bKash verify failed: ${verifyResult.statusMessage}`)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Payment verification failed',
          bkashResponse: verifyResult,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 3: Execute the payment
    console.log(`Executing payment ${paymentId}...`)
    const executeResult = await executePayment(token, paymentId)

    if (executeResult.statusCode !== '0000') {
      console.error(`bKash execute failed: ${executeResult.statusMessage}`)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Payment execution failed',
          bkashResponse: executeResult,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 4: Update subscription in Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const now = new Date()
    const expiresAt = new Date(now)
    expiresAt.setDate(expiresAt.getDate() + 30) // 30-day subscription

    // Check for existing active subscription
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
      // Extend existing subscription
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
          payment_id: executeResult.trxID as string,
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
      // Create new subscription
      const { data: created, error: createError } = await supabase
        .from('subscriptions')
        .insert({
          user_id: userId,
          plan: 'basic',
          status: 'active',
          started_at: now.toISOString(),
          expires_at: expiresAt.toISOString(),
          payment_id: executeResult.trxID as string,
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

    // Step 5: Audit log
    await supabase.from('audit_logs').insert({
      actor_id: userId,
      actor_type: 'user',
      action: 'payment.verify.bkash',
      resource_type: 'subscriptions',
      resource_id: subscriptionId,
      metadata: JSON.stringify({
        trxId: executeResult.trxID,
        amount: executeResult.amount,
        currency: executeResult.currency,
        paymentId,
        courseId,
      }),
      severity: 'info',
    })

    console.log(`bKash payment verified: trxID=${executeResult.trxID}, amount=${executeResult.amount}`)

    return new Response(
      JSON.stringify({
        success: true,
        trxId: executeResult.trxID,
        amount: executeResult.amount,
        currency: executeResult.currency,
        subscriptionId,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error(`bKash payment verification failed: ${err.message}`)
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
