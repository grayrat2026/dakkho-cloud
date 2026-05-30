import { AccessToken } from 'livekit-server-sdk';

export default async ({ req, res, log, error }) => {
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    const { roomName, participantName, role = 'student' } = body;

    if (!roomName || !participantName) {
      return res.json({
        success: false,
        error: 'Missing required fields: roomName, participantName'
      }, 400);
    }

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET;

    if (!apiKey || !apiSecret) {
      error('LiveKit credentials not configured');
      return res.json({
        success: false,
        error: 'Server configuration error'
      }, 500);
    }

    const at = new AccessToken(apiKey, apiSecret, {
      identity: participantName,
    });

    // Grant permissions based on role
    if (role === 'instructor') {
      at.addGrant({
        roomJoin: true,
        room: roomName,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
        roomAdmin: true,
        roomCreate: true,
      });
    } else {
      at.addGrant({
        roomJoin: true,
        room: roomName,
        canPublish: false,
        canSubscribe: true,
        canPublishData: true,
      });
    }

    const token = await at.toJwt();

    log(`Generated LiveKit token for ${participantName} in room ${roomName} (role: ${role})`);

    return res.json({
      success: true,
      token,
      roomName,
      participantName,
      role,
    });
  } catch (err) {
    error(`LiveKit token generation failed: ${err.message}`);
    return res.json({
      success: false,
      error: err.message
    }, 500);
  }
};
