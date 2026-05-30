import { Client, Databases, ID, Query } from 'node-appwrite';
import crypto from 'crypto';

const DATABASE_ID = 'dakkho-main';
const SUBSCRIPTIONS_COLLECTION = 'subscriptions';
const AUDIT_LOGS_COLLECTION = 'audit_logs';

const NAGAD_BASE_URL_SANDBOX = 'https://sandbox.mynagad.com';
const NAGAD_BASE_URL_PRODUCTION = 'https://api.mynagad.com';

function getBaseUrl() {
  return process.env.NAGAD_SANDBOX === 'true' ? NAGAD_BASE_URL_SANDBOX : NAGAD_BASE_URL_PRODUCTION;
}

function signWithPrivateKey(data) {
  const privateKey = process.env.NAGAD_PRIVATE_KEY;
  if (!privateKey) throw new Error('NAGAD_PRIVATE_KEY not configured');
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(data);
  signer.end();
  return signer.sign(privateKey, 'base64');
}

function verifyWithPublicKey(data, signature) {
  const publicKey = process.env.NAGAD_PUBLIC_KEY;
  if (!publicKey) throw new Error('NAGAD_PUBLIC_KEY not configured');
  const verifier = crypto.createVerify('RSA-SHA256');
  verifier.update(data);
  verifier.end();
  return verifier.verify(publicKey, signature, 'base64');
}

async function verifyNagadPayment(paymentRefId) {
  const baseUrl = getBaseUrl();
  const merchantId = process.env.NAGAD_MERCHANT_ID;

  // Step 1: Initialize verification
  const dateStr = new Date().toISOString();
  const randomStr = crypto.randomBytes(16).toString('hex');

  const sensitiveData = JSON.stringify({
    merchantId,
    orderRef: paymentRefId,
    challenge: randomStr,
  });

  const signature = signWithPrivateKey(sensitiveData);

  const response = await fetch(`${baseUrl}/api/dfs/verify/payment`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-KM-Api-Version': 'v-0.2.0',
      'X-KM-IP-V4': process.env.NAGAD_MERCHANT_IP || '127.0.0.1',
      'X-KM-Client-Type': 'PC_WEB',
      Date: dateStr,
    },
    body: JSON.stringify({
      accountNumber: merchantId,
      paymentRefId,
      sensitiveData,
      signature,
    }),
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
    const { paymentRefId, courseId, userId } = body;

    if (!paymentRefId || !courseId || !userId) {
      return res.json({
        success: false,
        error: 'Missing required fields: paymentRefId, courseId, userId'
      }, 400);
    }

    // Step 1: Verify with Nagad
    log(`Verifying Nagad payment ${paymentRefId}...`);
    const nagadResult = await verifyNagadPayment(paymentRefId);

    if (nagadResult.status !== 'SUCCESS' && nagadResult.message !== 'Successful') {
      error(`Nagad verify failed: ${JSON.stringify(nagadResult)}`);
      return res.json({
        success: false,
        error: 'Payment verification failed',
        nagadResponse: nagadResult,
      }, 400);
    }

    // Step 2: Verify signature from Nagad
    if (nagadResult.signature && nagadResult.sensitiveData) {
      const isValid = verifyWithPublicKey(nagadResult.sensitiveData, nagadResult.signature);
      if (!isValid) {
        error('Nagad response signature verification failed');
        return res.json({
          success: false,
          error: 'Signature verification failed — possible tampering',
        }, 400);
      }
    }

    // Step 3: Update subscription
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
          payment_id: nagadResult.paymentRefId || paymentRefId,
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
          payment_id: nagadResult.paymentRefId || paymentRefId,
          auto_renew: false,
          trial_days_remaining: 0,
          features_json: JSON.stringify({ basic: true }),
        }
      );
    }

    // Step 4: Audit log
    await databases.createDocument(
      DATABASE_ID,
      AUDIT_LOGS_COLLECTION,
      ID.unique(),
      {
        actor_id: userId,
        actor_type: 'user',
        action: 'payment.verify.nagad',
        resource_type: 'subscriptions',
        resource_id: subscription.$id,
        metadata: JSON.stringify({
          paymentRefId,
          amount: nagadResult.amount,
          courseId,
        }),
        severity: 'info',
      }
    );

    log(`Nagad payment verified: refId=${paymentRefId}, amount=${nagadResult.amount}`);

    return res.json({
      success: true,
      paymentRefId,
      amount: nagadResult.amount,
      subscriptionId: subscription.$id,
    });
  } catch (err) {
    error(`Nagad payment verification failed: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};
