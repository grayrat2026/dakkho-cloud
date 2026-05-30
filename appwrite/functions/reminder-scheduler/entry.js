import { Client, Databases, Query } from 'node-appwrite';

const DATABASE_ID = 'dakkho-main';
const SUBSCRIPTIONS_COLLECTION = 'subscriptions';
const LIVE_CLASSES_COLLECTION = 'live_classes';
const NOTIFICATION_TEMPLATES_COLLECTION = 'notification_templates';

function getAppwriteClient() {
  return new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1')
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);
}

const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

async function sendPushNotification(userId, heading, content, data = {}) {
  if (!ONESIGNAL_APP_ID || !ONESIGNAL_REST_API_KEY) {
    console.log('OneSignal not configured, skipping push notification');
    return null;
  }

  const response = await fetch('https://onesignal.com/api/v1/notifications', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
    },
    body: JSON.stringify({
      app_id: ONESIGNAL_APP_ID,
      include_external_user_ids: [userId],
      headings: { en: heading, bn: heading },
      contents: { en: content, bn: content },
      data,
      small_icon: 'ic_notification',
    }),
  });

  return response.json();
}

async function checkSubscriptionExpiry(databases, log) {
  const now = new Date();
  const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000).toISOString();

  // Find subscriptions expiring in 3 days
  const expiringSoon = await databases.listDocuments(
    DATABASE_ID,
    SUBSCRIPTIONS_COLLECTION,
    [
      Query.equal('status', 'active'),
      Query.lessThan('expires_at', threeDaysFromNow),
      Query.greaterThan('expires_at', now.toISOString()),
    ]
  );

  log(`Found ${expiringSoon.documents.length} subscriptions expiring within 3 days`);

  for (const sub of expiringSoon.documents) {
    const daysLeft = Math.ceil((new Date(sub.expires_at) - now) / (24 * 60 * 60 * 1000));

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
    );

    log(`Sent expiry reminder to user ${sub.user_id} (${daysLeft} days left)`);
  }

  // Find already expired subscriptions and update status
  const expired = await databases.listDocuments(
    DATABASE_ID,
    SUBSCRIPTIONS_COLLECTION,
    [
      Query.equal('status', 'active'),
      Query.lessThan('expires_at', now.toISOString()),
    ]
  );

  log(`Found ${expired.documents.length} expired subscriptions to deactivate`);

  for (const sub of expired.documents) {
    await databases.updateDocument(
      DATABASE_ID,
      SUBSCRIPTIONS_COLLECTION,
      sub.$id,
      { status: 'expired' }
    );

    await sendPushNotification(
      sub.user_id,
      'সাবস্ক্রিপশন শেষ হয়েছে',
      'আপনার সাবস্ক্রিপশন শেষ হয়েছে। আবার শুরু করতে নবায়ন করুন!',
      {
        type: 'subscription_expired',
        subscriptionId: sub.$id,
        action: 'renew_subscription',
      }
    );

    log(`Deactivated expired subscription for user ${sub.user_id}`);
  }
}

async function checkLiveClassReminders(databases, log) {
  const now = new Date();
  const thirtyMinFromNow = new Date(now.getTime() + 30 * 60 * 1000).toISOString();
  const fiveMinFromNow = new Date(now.getTime() + 5 * 60 * 1000).toISOString();

  // Find live classes starting in 30 minutes
  const upcoming30 = await databases.listDocuments(
    DATABASE_ID,
    LIVE_CLASSES_COLLECTION,
    [
      Query.equal('status', 'scheduled'),
      Query.greaterThan('scheduled_at', now.toISOString()),
      Query.lessThan('scheduled_at', thirtyMinFromNow),
    ]
  );

  log(`Found ${upcoming30.documents.length} live classes starting within 30 minutes`);

  for (const liveClass of upcoming30.documents) {
    const minutesLeft = Math.ceil((new Date(liveClass.scheduled_at) - now) / (60 * 1000));

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
    );

    log(`Sent 30-min reminder for class "${liveClass.title}" to instructor ${liveClass.instructor_id}`);
  }
}

async function checkStudyStreakReminders(databases, log) {
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();

  // Simple streak reminder — students who haven't studied today
  // In a full implementation, this would check a separate streak/activity collection
  log('Study streak reminders checked (placeholder — implement with activity tracking)');
}

export default async ({ req, res, log, error }) => {
  try {
    const client = getAppwriteClient();
    const databases = new Databases(client);

    const results = {
      subscriptionExpiry: null,
      liveClassReminders: null,
      studyStreakReminders: null,
    };

    // Check subscription expiry
    try {
      await checkSubscriptionExpiry(databases, log);
      results.subscriptionExpiry = 'completed';
    } catch (err) {
      error(`Subscription expiry check failed: ${err.message}`);
      results.subscriptionExpiry = `failed: ${err.message}`;
    }

    // Check live class reminders
    try {
      await checkLiveClassReminders(databases, log);
      results.liveClassReminders = 'completed';
    } catch (err) {
      error(`Live class reminder check failed: ${err.message}`);
      results.liveClassReminders = `failed: ${err.message}`;
    }

    // Check study streak reminders
    try {
      await checkStudyStreakReminders(databases, log);
      results.studyStreakReminders = 'completed';
    } catch (err) {
      error(`Study streak check failed: ${err.message}`);
      results.studyStreakReminders = `failed: ${err.message}`;
    }

    return res.json({
      success: true,
      timestamp: new Date().toISOString(),
      results,
    });
  } catch (err) {
    error(`Reminder scheduler failed: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};
