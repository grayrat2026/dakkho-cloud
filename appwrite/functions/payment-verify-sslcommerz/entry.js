import { Client, Databases, ID, Query } from 'node-appwrite';
import crypto from 'crypto';

const DATABASE_ID = 'dakkho-main';
const SUBSCRIPTIONS_COLLECTION = 'subscriptions';
const AUDIT_LOGS_COLLECTION = 'audit_logs';

const SSLCZ_SANDBOX_URL = 'https://sandbox.sslcommerz.com';
const SSLCZ_PRODUCTION_URL = 'https://securepay.sslcommerz.com';

function getBaseUrl() {
  return process.env.SSLCOMMERZ_SANDBOX === 'true' ? SSLCZ_SANDBOX_URL : SSLCZ_PRODUCTION_URL;
}

function validateHash(postData) {
  const storePassword = process.env.SSLCOMMERZ_STORE_PASSWORD;
  if (!storePassword) throw new Error('SSLCOMMERZ_STORE_PASSWORD not configured');

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
  ];

  const hashString = hashKeys.filter(Boolean).join('&');
  const expectedHash = crypto.createHash('md5').update(hashString).digest('hex');

  return postData.verify_sign === expectedHash || postData.verify_key === expectedHash;
}

async function validateIPN(tranId, valId) {
  const baseUrl = getBaseUrl();
  const storeId = process.env.SSLCOMMERZ_STORE_ID;
  const storePassword = process.env.SSLCOMMERZ_STORE_PASSWORD;

  const response = await fetch(
    `${baseUrl}/validator/api/validationserverAPI.php?val_id=${valId}&store_id=${storeId}&store_passwd=${storePassword}&format=json`
  );

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
    const { tranId, valId, courseId, userId } = body;

    if (!tranId || !valId || !courseId || !userId) {
      return res.json({
        success: false,
        error: 'Missing required fields: tranId, valId, courseId, userId'
      }, 400);
    }

    // Step 1: Validate via SSLCommerz API (IPN validation)
    log(`Validating SSLCommerz payment: tranId=${tranId}, valId=${valId}...`);
    const validation = await validateIPN(tranId, valId);

    if (validation.status !== 'VALID' && validation.status !== 'VALIDATED') {
      error(`SSLCommerz validation failed: ${validation.status} - ${validation.error || 'Unknown'}`);
      return res.json({
        success: false,
        error: `Payment validation failed: ${validation.status}`,
        sslczResponse: validation,
      }, 400);
    }

    // Step 2: Hash verification
    if (body.verify_sign) {
      const hashValid = validateHash(body);
      if (!hashValid) {
        error('SSLCommerz hash verification failed — possible tampering');
        return res.json({
          success: false,
          error: 'Hash verification failed',
        }, 400);
      }
    }

    // Step 3: Verify transaction amount matches expected
    const paidAmount = parseFloat(validation.currency_amount || validation.amount || 0);
    log(`Payment amount: ${paidAmount} ${validation.currency_type || 'BDT'}`);

    // Step 4: Update subscription
    const client = getAppwriteClient();
    const databases = new Databases(client);

    const now = new Date();
    const expiresAt = new Date(now);
    expiresAt.setDate(expiresAt.getDate() + 30);

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
          payment_id: tranId,
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
          payment_id: tranId,
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
        action: 'payment.verify.sslcommerz',
        resource_type: 'subscriptions',
        resource_id: subscription.$id,
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
      }
    );

    log(`SSLCommerz payment verified: tranId=${tranId}, amount=${paidAmount}`);

    return res.json({
      success: true,
      tranId,
      valId,
      amount: paidAmount,
      currency: validation.currency_type || 'BDT',
      subscriptionId: subscription.$id,
    });
  } catch (err) {
    error(`SSLCommerz payment verification failed: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};
