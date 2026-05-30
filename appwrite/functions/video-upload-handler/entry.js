import { Client, Databases, ID, Query } from 'node-appwrite';
import crypto from 'crypto';

const DATABASE_ID = 'dakkho-main';
const VIDEOS_COLLECTION = 'videos';

function getAppwriteClient() {
  return new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1')
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);
}

/**
 * Generate a presigned URL for Cloudflare R2 upload
 * R2 is S3-compatible, so we use AWS Signature V4
 */
function generatePresignedUrl(bucketName, objectKey, region = 'auto') {
  const accessKeyId = process.env.R2_ACCESS_KEY_ID;
  const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
  const endpoint = process.env.R2_ENDPOINT;

  if (!accessKeyId || !secretAccessKey || !endpoint) {
    throw new Error('R2 credentials not configured');
  }

  // R2 endpoint format: https://<account_id>.r2.cloudflarestorage.com
  const host = endpoint.replace('https://', '').replace('http://', '');

  const now = new Date();
  const dateStamp = now.toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z';
  const dateOnly = dateStamp.substring(0, 8);

  const expiration = 3600; // 1 hour

  // Build canonical request for presigned URL
  const method = 'PUT';
  const canonicalUri = `/${bucketName}/${objectKey}`;

  const credential = `${accessKeyId}/${dateOnly}/${region}/s3/aws4_request`;

  const queryParams = new URLSearchParams({
    'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
    'X-Amz-Credential': credential,
    'X-Amz-Date': dateStamp,
    'X-Amz-Expires': expiration.toString(),
    'X-Amz-SignedHeaders': 'host',
  });

  const canonicalHeaders = `host:${host}\n`;
  const signedHeaders = 'host';
  const payloadHash = 'UNSIGNED-PAYLOAD';

  const canonicalRequest = [
    method,
    canonicalUri,
    queryParams.toString(),
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n');

  // Build string to sign
  const stringToSign = [
    'AWS4-HMAC-SHA256',
    dateStamp,
    `${dateOnly}/${region}/s3/aws4_request`,
    crypto.createHash('sha256').update(canonicalRequest).digest('hex'),
  ].join('\n');

  // Calculate signature
  const kDate = crypto.createHmac('sha256', `AWS4${secretAccessKey}`).update(dateOnly).digest();
  const kRegion = crypto.createHmac('sha256', kDate).update(region).digest();
  const kService = crypto.createHmac('sha256', kRegion).update('s3').digest();
  const kSigning = crypto.createHmac('sha256', kService).update('aws4_request').digest();
  const signature = crypto.createHmac('sha256', kSigning).update(stringToSign).digest('hex');

  const presignedUrl = `${endpoint}${canonicalUri}?${queryParams.toString()}&X-Amz-Signature=${signature}`;

  return presignedUrl;
}

export default async ({ req, res, log, error }) => {
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    const { videoId, fileName, courseId } = body;

    if (!fileName) {
      return res.json({
        success: false,
        error: 'Missing required field: fileName'
      }, 400);
    }

    const bucketName = process.env.R2_BUCKET_NAME;
    if (!bucketName) {
      error('R2_BUCKET_NAME not configured');
      return res.json({
        success: false,
        error: 'Storage not configured'
      }, 500);
    }

    // Generate unique R2 path
    const uniqueId = crypto.randomUUID();
    const ext = fileName.split('.').pop();
    const r2Path = `videos/raw/${courseId || 'uncategorized'}/${uniqueId}.${ext}`;

    // Generate presigned URL
    log(`Generating presigned URL for ${r2Path}...`);
    const presignedUrl = generatePresignedUrl(bucketName, r2Path);

    // If videoId provided, update the video document
    if (videoId) {
      const client = getAppwriteClient();
      const databases = new Databases(client);

      try {
        await databases.updateDocument(
          DATABASE_ID,
          VIDEOS_COLLECTION,
          videoId,
          {
            raw_file_id: r2Path,
            file_size_bytes: 0, // Will be updated after upload
          }
        );
        log(`Updated video ${videoId} with R2 path: ${r2Path}`);
      } catch (updateErr) {
        error(`Failed to update video document: ${updateErr.message}`);
        // Non-fatal — URL is still valid
      }
    }

    log(`Presigned URL generated for ${r2Path}`);

    return res.json({
      success: true,
      uploadUrl: presignedUrl,
      r2Path,
      method: 'PUT',
      headers: {
        'Content-Type': 'application/octet-stream',
      },
      expiresInSeconds: 3600,
    });
  } catch (err) {
    error(`Video upload handler failed: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};
