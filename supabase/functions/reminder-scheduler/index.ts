// DAKKHO — Reminder Scheduler Edge Function
// Checks subscription expiry, live class reminders, and study streaks
// Sends push notifications via OneSignal API
// Queries Appwrite via REST API for data

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
const SUBSCRIPTIONS_COLLECTION = 'subscriptions'
const LIVE_CLASSES_COLLECTION = 'live_classes'

/**
 * List documents from Appwrite via REST API
 */
async function listAppwriteDocs(collectionId: string, queries: string[] = []) {
  const params = new URLSearchParams()
  queries.forEach(q => params.append('queries[]', q))
  const resp = await fetch(
    `${APPWRITE_ENDPOINT}/databases/${DATABASE_ID}/collections/${collectionId}/documents?${params}`,
    { headers: appwriteHeaders }
  )
  if (!resp.ok) {
    const errText = await resp.text()
    throw new Error(`Appwrite list failed (${resp.status}): ${errText}`)
  }
  return resp.json()
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

/**
 * Send push notification via OneSignal
 */
async function sendPushNotification(
  userId: string,
  heading: string,
  content: string,
  data: Record<string, unknown> = {}
): Promise<Record<string, unknown> | null> {
  const onesignalAppId = Deno.env.get('ONESIGNAL_APP_ID')
  const onesignalRestApiKey = Deno.env.get('ONESIGNAL_REST_API_KEY')

  if (!onesignalAppId || !onesignalRestApiKey) {
    console.log('OneSignal not configured, skipping push notification')
    return null
  }

  const response = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${onesignalRestApiKey}`,
    },
    body: JSON.stringify({
      app_id: onesignalAppId,
      include_external_user_ids: [userId],
      headings: { en: heading, bn: heading },
      contents: { en: content, bn: content },
      data,
      small_icon: 'ic_notification',
    }),
  })

  return response.json()
}

/**
 * Check subscriptions expiring soon and already expired
 */
async function checkSubscriptionExpiry(): Promise<{ expiringSoon: number; deactivated: number }> {
  const now = new Date()
  const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000).toISOString()

  let expiringSoonCount = 0
  let deactivatedCount = 0

  // Find subscriptions expiring in 3 days
  const expiringSoon = await listAppwriteDocs(SUBSCRIPTIONS_COLLECTION, [
    `equal("status", "active")`,
    `lessThan("expires_at", "${threeDaysFromNow}")`,
    `greaterThan("expires_at", "${now.toISOString()}")`,
  ])

  console.log(`Found ${expiringSoon.documents?.length || 0} subscriptions expiring within 3 days`)

  for (const sub of expiringSoon.documents || []) {
    const daysLeft = Math.ceil(
      (new Date(sub.expires_at) - now) / (24 * 60 * 60 * 1000)
    )

    await sendPushNotification(
      sub.user_id,
      'সাবস্ক্রিপশন শীঘ্রই শেষ!',
      `আপনার সাবস্ক্রিপশন ${daysLeft} দিনের মধ্যে শেষ হবে। এখনই নবায়ন করুন!`,
      {
        type: 'subscription_expiry',
        daysLeft,
        subscriptionId: sub.$id,
        action: 'renew_subscription',
      }
    )

    console.log(`Sent expiry reminder to user ${sub.user_id} (${daysLeft} days left)`)
    expiringSoonCount++
  }

  // Find already expired subscriptions and update status
  const expired = await listAppwriteDocs(SUBSCRIPTIONS_COLLECTION, [
    `equal("status", "active")`,
    `lessThan("expires_at", "${now.toISOString()}")`,
  ])

  console.log(`Found ${expired.documents?.length || 0} expired subscriptions to deactivate`)

  for (const sub of expired.documents || []) {
    await updateAppwriteDoc(SUBSCRIPTIONS_COLLECTION, sub.$id, { status: 'expired' })

    await sendPushNotification(
      sub.user_id,
      'সাবস্ক্রিপশন শেষ হয়েছে',
      'আপনার সাবস্ক্রিপশন শেষ হয়েছে। আবার শুরু করতে নবায়ন করুন!',
      {
        type: 'subscription_expired',
        subscriptionId: sub.$id,
        action: 'renew_subscription',
      }
    )

    console.log(`Deactivated expired subscription for user ${sub.user_id}`)
    deactivatedCount++
  }

  return { expiringSoon: expiringSoonCount, deactivated: deactivatedCount }
}

/**
 * Check live classes starting soon and send reminders
 */
async function checkLiveClassReminders(): Promise<{ reminded: number }> {
  const now = new Date()
  const thirtyMinFromNow = new Date(now.getTime() + 30 * 60 * 1000).toISOString()

  let remindedCount = 0

  // Find live classes starting in 30 minutes
  const upcoming30 = await listAppwriteDocs(LIVE_CLASSES_COLLECTION, [
    `equal("status", "scheduled")`,
    `greaterThan("scheduled_at", "${now.toISOString()}")`,
    `lessThan("scheduled_at", "${thirtyMinFromNow}")`,
  ])

  console.log(`Found ${upcoming30.documents?.length || 0} live classes starting within 30 minutes`)

  for (const liveClass of upcoming30.documents || []) {
    const minutesLeft = Math.ceil(
      (new Date(liveClass.scheduled_at) - now) / (60 * 1000)
    )

    // Notify enrolled students (simplified — in production, query enrollments)
    await sendPushNotification(
      liveClass.instructor_id,
      'লাইভ ক্লাস শীঘ্রই শুরু!',
      `"${liveClass.title}" ${minutesLeft} মিনিটে শুরু হবে। তৈরি থাকুন!`,
      {
        type: 'live_class_reminder',
        liveClassId: liveClass.$id,
        roomName: liveClass.livekit_room_name,
        action: 'join_live_class',
      }
    )

    console.log(`Sent 30-min reminder for class "${liveClass.title}" to instructor ${liveClass.instructor_id}`)
    remindedCount++
  }

  return { reminded: remindedCount }
}

/**
 * Check study streak reminders (placeholder)
 */
async function checkStudyStreakReminders(): Promise<{ checked: boolean }> {
  // Simple streak reminder — students who haven't studied today
  // In a full implementation, this would check a separate streak/activity collection
  console.log('Study streak reminders checked (placeholder — implement with activity tracking)')
  return { checked: true }
}

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (!APPWRITE_API_KEY) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'APPWRITE_API_KEY not configured',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const results: Record<string, unknown> = {
      subscriptionExpiry: null,
      liveClassReminders: null,
      studyStreakReminders: null,
    }

    // Check subscription expiry
    try {
      const expiryResult = await checkSubscriptionExpiry()
      results.subscriptionExpiry = { status: 'completed', ...expiryResult }
    } catch (err) {
      console.error(`Subscription expiry check failed: ${(err as Error).message}`)
      results.subscriptionExpiry = { status: 'failed', error: (err as Error).message }
    }

    // Check live class reminders
    try {
      const liveClassResult = await checkLiveClassReminders()
      results.liveClassReminders = { status: 'completed', ...liveClassResult }
    } catch (err) {
      console.error(`Live class reminder check failed: ${(err as Error).message}`)
      results.liveClassReminders = { status: 'failed', error: (err as Error).message }
    }

    // Check study streak reminders
    try {
      const streakResult = await checkStudyStreakReminders()
      results.studyStreakReminders = { status: 'completed', ...streakResult }
    } catch (err) {
      console.error(`Study streak check failed: ${(err as Error).message}`)
      results.studyStreakReminders = { status: 'failed', error: (err as Error).message }
    }

    return new Response(
      JSON.stringify({
        success: true,
        timestamp: new Date().toISOString(),
        results,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (err) {
    console.error(`Reminder scheduler failed: ${err.message}`)
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
