import { Client, Databases, ID, Query } from 'node-appwrite';

const DATABASE_ID = process.env.APPWRITE_DATABASE_ID || 'dakkho_main';
const ACTIVE_DEVICES_COLLECTION = 'active_devices';
const DEVICE_SWAP_LOGS_COLLECTION = 'device_swap_logs';

// Rate limit: max 1 swap per 7 days
const SWAP_COOLDOWN_DAYS = 7;

function getAppwriteClient() {
  return new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1')
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);
}

export default async ({ req, res, log, error }) => {
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    const { userId, androidId, deviceName, deviceModel, fcmToken, appVersion } = body;

    if (!userId || !androidId) {
      return res.json({
        success: false,
        error: 'Missing required fields: userId, androidId'
      }, 400);
    }

    const client = getAppwriteClient();
    const databases = new Databases(client);
    const now = new Date().toISOString();

    // Generate device fingerprint from androidId
    const crypto = await import('crypto');
    const deviceFingerprint = crypto.createHash('sha256').update(androidId + userId).digest('hex');

    // Check if this user already has an active device
    const existingDevices = await databases.listDocuments(
      DATABASE_ID,
      ACTIVE_DEVICES_COLLECTION,
      [
        Query.equal('user_id', userId),
        Query.equal('is_active', true),
      ]
    );

    if (existingDevices.documents.length > 0) {
      const currentDevice = existingDevices.documents[0];

      // Same device — just update last_seen_at
      if (currentDevice.device_fingerprint === deviceFingerprint) {
        await databases.updateDocument(
          DATABASE_ID,
          ACTIVE_DEVICES_COLLECTION,
          currentDevice.$id,
          {
            last_seen_at: now,
            app_version: appVersion || currentDevice.app_version,
          }
        );

        log(`Same device heartbeat updated for user ${userId}`);
        return res.json({
          success: true,
          allowed: true,
          action: 'heartbeat',
        });
      }

      // Different device — check swap cooldown
      const swapLogs = await databases.listDocuments(
        DATABASE_ID,
        DEVICE_SWAP_LOGS_COLLECTION,
        [
          Query.equal('user_id', userId),
          Query.orderDesc('created_at'),
          Query.limit(1),
        ]
      );

      if (swapLogs.documents.length > 0) {
        const lastSwap = new Date(swapLogs.documents[0].created_at);
        const cooldownMs = SWAP_COOLDOWN_DAYS * 24 * 60 * 60 * 1000;
        const timeSinceLastSwap = Date.now() - lastSwap.getTime();

        if (timeSinceLastSwap < cooldownMs) {
          const remainingDays = Math.ceil((cooldownMs - timeSinceLastSwap) / (24 * 60 * 60 * 1000));
          log(`Swap rate limited for user ${userId}: ${remainingDays} days remaining`);
          return res.json({
            success: true,
            allowed: false,
            action: 'swap_rate_limited',
            reason: `আপনি ইতিমধ্যে একটি ডিভাইস পরিবর্তন করেছেন। আবার পরিবর্তন করতে ${remainingDays} দিন অপেক্ষা করুন।`,
            cooldownRemainingDays: remainingDays,
          });
        }
      }

      // Deactivate old device
      await databases.updateDocument(
        DATABASE_ID,
        ACTIVE_DEVICES_COLLECTION,
        currentDevice.$id,
        { is_active: false }
      );

      // Log the swap
      await databases.createDocument(
        DATABASE_ID,
        DEVICE_SWAP_LOGS_COLLECTION,
        ID.unique(),
        {
          user_id: userId,
          old_device_fingerprint: currentDevice.device_fingerprint,
          new_device_fingerprint: deviceFingerprint,
          swap_reason: 'user_initiated',
          old_device_name: currentDevice.device_name || 'Unknown',
          new_device_name: deviceModel || deviceName || 'Unknown',
          ip_address: req.headers?.['x-forwarded-for'] || null,
        }
      );

      log(`Device swap logged for user ${userId}: ${currentDevice.device_fingerprint} → ${deviceFingerprint}`);
    }

    // Register new device
    await databases.createDocument(
      DATABASE_ID,
      ACTIVE_DEVICES_COLLECTION,
      ID.unique(),
      {
        user_id: userId,
        device_fingerprint: deviceFingerprint,
        device_name: deviceModel || deviceName || 'Unknown',
        android_id: androidId,
        app_version: appVersion || null,
        os_version: null,
        registered_at: now,
        last_seen_at: now,
        is_active: true,
      }
    );

    log(`New device registered for user ${userId}: ${deviceFingerprint}`);

    return res.json({
      success: true,
      allowed: true,
      action: existingDevices.documents.length > 0 ? 'device_swapped' : 'device_registered',
    });
  } catch (err) {
    error(`Device registration failed: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};
