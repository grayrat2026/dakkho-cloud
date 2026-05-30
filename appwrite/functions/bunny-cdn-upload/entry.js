import { Client, Databases, ID, Query } from 'node-appwrite';

const DATABASE_ID = 'dakkho-main';
const VIDEOS_COLLECTION = 'videos';

function getAppwriteClient() {
  return new Client()
    .setEndpoint(process.env.APPWRITE_ENDPOINT || 'https://cloud.appwrite.io/v1')
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(process.env.APPWRITE_API_KEY);
}

export default async ({ req, res, log, error }) => {
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    const { videoId, libraryId } = body;

    if (!videoId) {
      return res.json({
        success: false,
        error: 'Missing required field: videoId'
      }, 400);
    }

    const apiKey = process.env.BUNNY_API_KEY;
    const bunnyLibraryId = libraryId || process.env.BUNNY_LIBRARY_ID;

    if (!apiKey || !bunnyLibraryId) {
      error('Bunny CDN credentials not configured');
      return res.json({
        success: false,
        error: 'Bunny CDN not configured yet. Admin needs to set BUNNY_API_KEY and BUNNY_LIBRARY_ID in function environment variables.'
      }, 500);
    }

    // Step 1: Create video entry in Bunny library
    log(`Creating Bunny video entry in library ${bunnyLibraryId}...`);
    const createResponse = await fetch(
      `https://video.bunnycdn.com/library/${bunnyLibraryId}/videos`,
      {
        method: 'POST',
        headers: {
          AccessKey: apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ title: `DAKKHO_${videoId}` }),
      }
    );

    if (!createResponse.ok) {
      const errText = await createResponse.text();
      throw new Error(`Bunny create video failed (${createResponse.status}): ${errText}`);
    }

    const createData = await createResponse.json();
    const bunnyVideoId = createData.guid;

    log(`Bunny video created: ${bunnyVideoId}`);

    // Step 2: Generate upload URL (TUS protocol)
    const uploadUrl = `https://video.bunnycdn.com/library/${bunnyLibraryId}/videos/${bunnyVideoId}`;

    // Step 3: Update video document in database
    const client = getAppwriteClient();
    const databases = new Databases(client);

    try {
      await databases.updateDocument(
        DATABASE_ID,
        VIDEOS_COLLECTION,
        videoId,
        {
          bunny_video_id: bunnyVideoId,
        }
      );
      log(`Updated video document ${videoId} with bunny_video_id: ${bunnyVideoId}`);
    } catch (updateErr) {
      error(`Failed to update video document: ${updateErr.message}`);
      // Non-fatal
    }

    return res.json({
      success: true,
      bunnyVideoId,
      uploadUrl,
      uploadHeaders: {
        AccessKey: apiKey,
        'Content-Type': 'application/octet-stream',
      },
      libraryId: bunnyLibraryId,
      // Status check URL
      statusUrl: `https://video.bunnycdn.com/library/${bunnyLibraryId}/videos/${bunnyVideoId}`,
    });
  } catch (err) {
    error(`Bunny CDN upload failed: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};
