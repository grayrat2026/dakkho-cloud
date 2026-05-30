import { Client, Databases, ID, Query } from 'node-appwrite';

const DATABASE_ID = 'dakkho-main';
const SUBSCRIPTIONS_COLLECTION = 'subscriptions';
const AUDIT_LOGS_COLLECTION = 'audit_logs';

// bKash API configuration
const BKASH_BASE_URL_SANDBOX = 'https://tokenized.sandbox.bka.sh/v1.2.0-beta';
const BKASH_BASE_URL_PRODUCTION = 'https://tokenized.pay.bka.sh/v1.2.0-beta';

function getBaseUrl() {
  return process.env.BKASH_SANDBOX === 'true' ? BKASH_BASE_URL_SANDBOX : BKASH_BASE_URL_PRODUCTION;
}

async function grantToken() {
  const baseUrl = getBaseUrl();
  const response = await fetch(`${baseUrl}/tokenized/checkout/token/grant`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      username: process.env.BKASH_USERNAME,
      password: process.env.BKASH_PASSWORD,
    },
    body: JSON.stringify({
      app_key: process.env.BKASH_APP_KEY,
      app_secret: process.env.BKASH_APP_SECRET,
    }),
  });

  const data = await response.json();
  if (data.code !== '0000') {
    throw new Error(`bKash token grant failed: ${data.message || JSON.stringify(data)}`);
  }
  return data.id_token;
}

async function verifyPayment(token, paymentId) {
  const baseUrl = getBaseUrl();
  const response = await fetch(`${baseUrl}/tokenized/checkout/payment/verify`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: token,
      'x-app-key': process.env.BKASH_APP_KEY,
    },
    body: JSON.stringify({ paymentID: paymentId }),
  });
  return response.json();
}

async function executePayment(token, paymentId) {
  const baseUrl = getBaseUrl();
  const response = await fetch(`${baseUrl}/tokenized/checkout/payment/execute`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      Authorization: token,
      'x-app-key': process.env.BKASH_APP_KEY,
    },
    body: JSON.stringify({ paymentID: paymentId }),
  });
  return response.json();
}

function getAppwriteClient() {
  return new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1')
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);
}

export default async ({ req, res, log, error }) => {
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    const { paymentId, courseId, userId } = body;

    if (!paymentId || !courseId || !userId) {
      return res.json({
        success: false,
        error: 'Missing required fields: paymentId, courseId, userId'
      }, 400);
    }

    // Step 1: Grant bKash token
    log('Granting bKash token...');
    const token = await grantToken();

    // Step 2: Verify the payment
    log(`Verifying payment ${paymentId}...`);
    const verifyResult = await verifyPayment(token, paymentId);

    if (verifyResult.statusCode !== '0000') {
      error(`bKash verify failed: ${verifyResult.statusMessage}`);
      return res.json({
        success: false,
        error: 'Payment verification failed',
        bkashResponse: verifyResult,
      }, 400);
    }

    // Step 3: Execute the payment
    log(`Executing payment ${paymentId}...`);
    const executeResult = await executePayment(token, paymentId);

    if (executeResult.statusCode !== '0000') {
      error(`bKash execute failed: ${executeResult.statusMessage}`);
      return res.json({
        success: false,
        error: 'Payment execution failed',
        bkashResponse: executeResult,
      }, 400);
    }

    // Step 4: Update subscription in database
    const client = getAppwriteClient();
    const databases = new Databases(client);

    const now = new Date();
    const expiresAt = new Date(now);
    expiresAt.setDate(expiresAt.getDate() + 30); // 30-day subscription

    // Create or update subscription
    const existingSubs = await databases.listDocuments(
      DATABASE_ID,
      SUBSCRIPTIONS_COLLECTION,
      [
        Query.equal('user_id', userId),
        Query.equal('status', 'active'),
      ]
    );

    let subscription;
    if (existingSubs.documents.length > 0) {
      // Extend existing subscription
      const current = existingSubs.documents[0];
      const currentExpiry = new Date(current.expires_at);
      const newExpiry = currentExpiry > now
        ? new Date(currentExpiry.getTime() + 30 * 24 * 60 * 60 * 1000)
        : expiresAt;

      subscription = await databases.updateDocument(
        DATABASE_ID,
        SUBSCRIPTIONS_COLLECTION,
        current.$id,
        {
          plan: 'basic',
          status: 'active',
          expires_at: newExpiry.toISOString(),
          payment_id: executeResult.trxID,
          auto_renew: false,
        }
      );
    } else {
      subscription = await databases.createDocument(
        DATABASE_ID,
        SUBSCRIPTIONS_COLLECTION,
        ID.unique(),
        {
          user_id: userId,
          plan: 'basic',
          status: 'active',
          started_at: now.toISOString(),
          expires_at: expiresAt.toISOString(),
          payment_id: executeResult.trxID,
          auto_renew: false,
          trial_days_remaining: 0,
          features_json: JSON.stringify({ basic: true }),
        }
      );
    }

    // Step 5: Audit log
    await databases.createDocument(
      DATABASE_ID,
      AUDIT_LOGS_COLLECTION,
      ID.unique(),
      {
        actor_id: userId,
        actor_type: 'user',
        action: 'payment.verify.bkash',
        resource_type: 'subscriptions',
        resource_id: subscription.$id,
        metadata: JSON.stringify({
          trxId: executeResult.trxID,
          amount: executeResult.amount,
          currency: executeResult.currency,
          paymentId,
          courseId,
        }),
        severity: 'info',
      }
    );

    log(`bKash payment verified: trxID=${executeResult.trxID}, amount=${executeResult.amount}`);

    return res.json({
      success: true,
      trxId: executeResult.trxID,
      amount: executeResult.amount,
      currency: executeResult.currency,
      subscriptionId: subscription.$id,
    });
  } catch (err) {
    error(`bKash payment verification failed: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};
