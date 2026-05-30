// DAKKHO — SSLCommerz Payment Verification Edge Function
// Validates SSLCommerz IPN and hash verification using MD5
// Updates subscriptions via Supabase

import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SSLCZ_SANDBOX_URL = 'https://sandbox.sslcommerz.com'
const SSLCZ_PRODUCTION_URL = 'https://securepay.sslcommerz.com'

function getBaseUrl(): string {
  return Deno.env.get('SSLCOMMERZ_SANDBOX') === 'true' ? SSLCZ_SANDBOX_URL : SSLCZ_PRODUCTION_URL
}

/**
 * Compute MD5 hash using Deno's crypto.subtle
 * Returns hex string
 */
async function md5Hash(input: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(input)
  const hashBuffer = await crypto.subtle.digest('MD5', data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

/**
 * Validate SSLCommerz verify_sign hash
 */
async function validateHash(postData: Record<string, string>): Promise<boolean> {
  const storePassword = Deno.env.get('SSLCOMMERZ_STORE_PASSWORD')
  if (!storePassword) throw new Error('SSLCOMMERZ_STORE_PASSWORD not configured')

  // SSLCommerz hash validation
  const hashKeys = [
    postData.val_id,
    storePassword,
    postData.amount,
    postData.card_type,
    postData.store_amount,
    postData.card_no,
    postData.currency,
    postData.bank_txn,
  ]

  const hashString = hashKeys.filter(Boolean).join('&')
  const expectedHash = await md5Hash(hashString)

  return postData.verify_sign === expectedHash || postData.verify_key === expectedHash
}

/**
 * Validate via SSLCommerz IPN API
 */
async function validateIPN(tranId: string, valId: string): Promise<Record<string, unknown>> {
  const baseUrl = getBaseUrl()
  const storeId = Deno.env.get('SSLCOMMERZ_STORE_ID')
  const storePassword = Deno.env.get('SSLCOMMERZ_STORE_PASSWORD')

  if (!storeId || !storePassword) throw new Error('SSLCOMMERZ credentials not configured')

  const response = await fetch(
    `${baseUrl}/validator/api/validationserverAPI.php?val_id=${valId}&store_id=${storeId}&store_passwd=${storePassword}&format=json`
  )

  return response.json()
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const { tranId, valId, courseId, userId, verify_sign, verify_key, val_id, amount, card_type, store_amount, card_no, currency, bank_txn } = body

    if (!tranId || !valId || !courseId || !userId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required fields: tranId, valId, courseId, userId',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 1: Validate via SSLCommerz API (IPN validation)
    console.log(`Validating SSLCommerz payment: tranId=${tranId}, valId=${valId}...`)
    const validation = await validateIPN(tranId, valId)

    if (validation.status !== 'VALID' && validation.status !== 'VALIDATED') {
      console.error(`SSLCommerz validation failed: ${validation.status} - ${validation.error || 'Unknown'}`)
      return new Response(
        JSON.stringify({
          success: false,
          error: `Payment validation failed: ${validation.status}`,
          sslczResponse: validation,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 2: Hash verification
    if (verify_sign) {
      const hashData: Record<string, string> = {
        val_id: val_id || valId,
        amount: amount || String(validation.currency_amount || validation.amount || ''),
        card_type: card_type || String(validation.card_type || ''),
        store_amount: store_amount || String(validation.store_amount || ''),
        card_no: card_no || String(validation.card_no || ''),
        currency: currency || String(validation.currency_type || ''),
        bank_txn: bank_txn || String(validation.bank_txn_id || ''),
        verify_sign,
        verify_key: verify_key || '',
      }
      const hashValid = await validateHash(hashData)
      if (!hashValid) {
        console.error('SSLCommerz hash verification failed — possible tampering')
        return new Response(
          JSON.stringify({
            success: false,
            error: 'Hash verification failed',
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Step 3: Verify transaction amount
    const paidAmount = parseFloat(validation.currency_amount as string || validation.amount as string || '0')
    console.log(`Payment amount: ${paidAmount} ${validation.currency_type || 'BDT'}`)

    // Step 4: Update subscription in Supabase
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
          payment_id: tranId,
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
          payment_id: tranId,
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
      action: 'payment.verify.sslcommerz',
      resource_type: 'subscriptions',
      resource_id: subscriptionId,
      metadata: JSON.stringify({
        tranId,
        valId,
        amount: paidAmount,
        currency: validation.currency_type,
        cardType: validation.card_type,
        bankTxn: validation.bank_txn_id,
        courseId,
      }),
      severity: 'info',
    })

    console.log(`SSLCommerz payment verified: tranId=${tranId}, amount=${paidAmount}`)

    return new Response(
      JSON.stringify({
        success: true,
        tranId,
        valId,
        amount: paidAmount,
        currency: validation.currency_type || 'BDT',
        subscriptionId,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error(`SSLCommerz payment verification failed: ${err.message}`)
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
