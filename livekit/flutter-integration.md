# DAKKHO — LiveKit Cloud Flutter Integration Guide

## Table of Contents
1. [Connecting from Flutter](#connecting-from-flutter)
2. [Token Generation Flow](#token-generation-flow)
3. [Fallback Configuration](#fallback-configuration)
4. [Room Management](#room-management)
5. [Bengali UI Considerations](#bengali-ui-considerations)

---

## Connecting from Flutter

### Dependencies

```yaml
# pubspec.yaml
dependencies:
  livekit_client: ^2.3.0
  appwrite: ^12.0.0
```

### LiveKit Service

```dart
import 'package:livekit_client/livekit_client.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:convert';

class LiveKitService {
  final Functions _functions;
  Room? _room;
  
  LiveKitService(Client client) : _functions = Functions(client);

  /// Connect to a live class room
  Future<Room> connectToRoom({
    required String roomId,
    required String userId,
    required String userName,
    required String userRole, // 'instructor' or 'student'
  }) async {
    try {
      // Step 1: Get token from Appwrite Function
      final token = await _getToken(
        roomId: roomId,
        userId: userId,
        userName: userName,
        userRole: userRole,
      );

      // Step 2: Connect to LiveKit room
      final wsUrl = const String.fromEnvironment(
        'LIVEKIT_WS_URL',
        defaultValue: 'wss://dakkho.livekit.cloud',
      );

      final roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultCameraCaptureOptions: CameraCaptureOptions(
          maxFrameRate: 30,
        ),
        defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(
          maxFrameRate: 15,
        ),
      );

      final connectOptions = ConnectOptions(
        autoSubscribe: true,
        token: token,
      );

      _room = await Room.connect(
        wsUrl,
        token,
        roomOptions: roomOptions,
        connectOptions: connectOptions,
      );

      return _room!;
    } on LiveKitError catch (e) {
      throw _mapLiveKitError(e);
    } catch (e) {
      throw Exception('লাইভ ক্লাসে যুক্ত হওয়া যায়নি। পরে আবার চেষ্টা করুন।');
    }
  }

  /// Disconnect from current room
  Future<void> disconnect() async {
    await _room?.disconnect();
    _room = null;
  }

  /// Toggle local microphone
  Future<void> toggleMicrophone(bool enabled) async {
    if (_room == null) return;
    
    if (enabled) {
      await _room!.localParticipant?.setMicrophoneEnabled(true);
    } else {
      await _room!.localParticipant?.setMicrophoneEnabled(false);
    }
  }

  /// Toggle local camera
  Future<void> toggleCamera(bool enabled) async {
    if (_room == null) return;
    
    if (enabled) {
      await _room!.localParticipant?.setCameraEnabled(true);
    } else {
      await _room!.localParticipant?.setCameraEnabled(false);
    }
  }

  /// Send chat message via data channel
  Future<void> sendChatMessage(String message) async {
    if (_room == null) return;
    
    await _room!.localParticipant?.publishData(
      utf8.encode(jsonEncode({
        'type': 'chat',
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      })),
      reliability: Reliability.reliable,
    );
  }

  /// Raise hand (student)
  Future<void> raiseHand() async {
    if (_room == null) return;
    
    await _room!.localParticipant?.publishData(
      utf8.encode(jsonEncode({
        'type': 'raise_hand',
        'timestamp': DateTime.now().toIso8601String(),
      })),
      reliability: Reliability.reliable,
    );
  }

  /// Get token from Appwrite Function
  Future<String> _getToken({
    required String roomId,
    required String userId,
    required String userName,
    required String userRole,
  }) async {
    final result = await _functions.createExecution(
      functionId: 'livekit-token',
      body: jsonEncode({
        'roomId': roomId,
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
      }),
    );

    if (result.status != 'completed') {
      throw Exception('টোকেন তৈরি করা যায়নি।');
    }

    final data = jsonDecode(result.response);
    return data['token'];
  }

  /// Map LiveKit errors to Bengali messages
  String _mapLiveKitError(LiveKitError error) {
    switch (error.code) {
      case 1001: // Connection failed
        return 'সার্ভারে সংযোগ করা যায়নি। ইন্টারনেট চেক করুন।';
      case 1002: // Connection timeout
        return 'সংযোগ সময়মতো হচ্ছে না। পরে আবার চেষ্টা করুন।';
      case 1003: // Token expired
        return 'সেশন মেয়াদোত্তীর্ণ। পুনরায় যুক্ত হোন।';
      case 1004: // Room not found
        return 'লাইভ ক্লাস পাওয়া যায়নি। সঠিক লিংক ব্যবহার করুন।';
      case 1005: // Room full
        return 'লাইভ ক্লাস ভর্তি। কিছুক্ষণ পর চেষ্টা করুন।';
      default:
        return 'লাইভ ক্লাসে সমস্যা হয়েছে। (কোড: ${error.code})';
    }
  }
}
```

### Live Class Screen Widget

```dart
class LiveClassScreen extends StatefulWidget {
  final String roomId;
  final String courseName;
  final String userRole;
  
  const LiveClassScreen({
    super.key,
    required this.roomId,
    required this.courseName,
    required this.userRole,
  });

  @override
  State<LiveClassScreen> createState() => _LiveClassScreenState();
}

class _LiveClassScreenState extends State<LiveClassScreen> {
  final LiveKitService _liveKit = LiveKitService(/* client */);
  Room? _room;
  bool _isConnecting = true;
  bool _isMicOn = false;
  bool _isCameraOn = false;
  String? _errorMessage;
  List<RemoteParticipant> _participants = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      _room = await _liveKit.connectToRoom(
        roomId: widget.roomId,
        userId: 'current-user-id',
        userName: 'ব্যবহারকারী',
        userRole: widget.userRole,
      );

      _room!.listener.on<ParticipantConnectedEvent>((event) {
        setState(() => _participants = _room!.remoteParticipants.values.toList());
      });

      _room!.listener.on<ParticipantDisconnectedEvent>((event) {
        setState(() => _participants = _room!.remoteParticipants.values.toList());
      });

      _room!.listener.on<DataReceivedEvent>((event) {
        final data = jsonDecode(utf8.decode(event.data));
        if (data['type'] == 'chat') {
          _showChatMessage(data['message']);
        } else if (data['type'] == 'raise_hand') {
          _showHandRaised(event.participant?.name ?? 'শিক্ষার্থী');
        }
      });

      setState(() {
        _isConnecting = false;
        _participants = _room!.remoteParticipants.values.toList();
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _liveKit.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('লাইভ ক্লাসে যুক্ত হচ্ছে...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isConnecting = true;
                      _errorMessage = null;
                    });
                    _connect();
                  },
                  child: const Text('আবার চেষ্টা করুন'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        actions: [
          IconButton(
            icon: Icon(_isMicOn ? Icons.mic : Icons.mic_off),
            onPressed: () {
              _liveKit.toggleMicrophone(!_isMicOn);
              setState(() => _isMicOn = !_isMicOn);
            },
          ),
          if (widget.userRole == 'instructor')
            IconButton(
              icon: Icon(_isCameraOn ? Icons.videocam : Icons.videocam_off),
              onPressed: () {
                _liveKit.toggleCamera(!_isCameraOn);
                setState(() => _isCameraOn = !_isCameraOn);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Main video area (instructor)
          Expanded(
            child: _buildMainVideo(),
          ),
          // Participant strip
          if (_participants.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _participants.length,
                itemBuilder: (context, index) => _buildParticipantTile(_participants[index]),
              ),
            ),
          // Controls
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildMainVideo() {
    // Find the instructor's video track
    final instructorVideo = _room?.remoteParticipants.values
        .expand((p) => p.videoTrackPublications)
        .where((t) => t.subscribed && t.track != null)
        .firstOrNull;

    if (instructorVideo != null && instructorVideo.track != null) {
      return VideoTrackRenderer(
        instructorVideo.track!,
        fit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      );
    }

    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
          SizedBox(height: 8),
          Text('ইনস্ট্রাক্টর শীঘ্রই শুরু করবেন...'),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(RemoteParticipant participant) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          CircleAvatar(
            child: Text(participant.name.isNotEmpty ? participant.name[0] : '?'),
          ),
          Text(participant.name, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF0A0E1A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(_isMicOn ? Icons.mic : Icons.mic_off),
            color: _isMicOn ? Colors.cyan : Colors.grey,
            onPressed: () {
              _liveKit.toggleMicrophone(!_isMicOn);
              setState(() => _isMicOn = !_isMicOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            color: Colors.cyan,
            onPressed: () => _showChatPanel(),
          ),
          if (widget.userRole == 'student')
            IconButton(
              icon: const Icon(Icons.back_hand),
              color: Colors.cyan,
              onPressed: () => _liveKit.raiseHand(),
            ),
          IconButton(
            icon: const Icon(Icons.call_end),
            color: Colors.red,
            onPressed: () {
              _liveKit.disconnect();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showChatMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  void _showHandRaised(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✋ $name হাত তুলেছেন'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showChatPanel() {
    // Show bottom sheet with chat
  }
}
```

---

## Token Generation Flow

### Architecture

```
┌─────────────┐     ┌─────────────────────┐     ┌──────────────────┐
│  Flutter App │────▶│  Appwrite Function  │────▶│  LiveKit Cloud   │
│             │     │  (livekit-token)    │     │                  │
│  Request:   │     │  1. Verify user     │     │  Token created   │
│  roomId     │     │  2. Check sub.      │     │  with grants     │
│  userId     │     │  3. Generate JWT    │     │                  │
│  userRole   │     │  4. Return token    │     │                  │
└─────────────┘     └─────────────────────┘     └──────────────────┘
```

### Appwrite Function: `livekit-token`

```javascript
// Appwrite Function: livekit-token
// Generates LiveKit access tokens with role-based permissions

import { AccessToken, VideoGrant } from 'livekit-server-sdk';

export default async ({ req, res, log, error }) => {
  try {
    const { roomId, userId, userName, userRole } = JSON.parse(req.body);

    // Validate inputs
    if (!roomId || !userId || !userName || !userRole) {
      return res.json({ error: 'Missing required fields' }, 400);
    }

    // Validate room ID format (alphanumeric + hyphens only)
    if (!/^[a-zA-Z0-9-]+$/.test(roomId)) {
      return res.json({ error: 'Invalid room ID format' }, 400);
    }

    const apiKey = process.env.LIVEKIT_API_KEY;
    const apiSecret = process.env.LIVEKIT_API_SECRET;

    if (!apiKey || !apiSecret) {
      error('LiveKit credentials not configured');
      return res.json({ error: 'Service configuration error' }, 500);
    }

    // Create video grant based on role
    const grant = new VideoGrant({
      room: roomId,
      roomJoin: true,
      canPublish: userRole === 'instructor' || userRole === 'moderator',
      canSubscribe: true,
      canPublishData: true,
      canUpdateMetadata: userRole === 'instructor' || userRole === 'moderator',
    });

    // Create access token
    const token = new AccessToken(apiKey, apiSecret, {
      identity: userId,
      name: userName,
      metadata: JSON.stringify({
        role: userRole,
        joinedAt: new Date().toISOString(),
      }),
    });

    token.addGrant(grant);

    // Set TTL (4 hours max for live class)
    token.ttl = '4h';

    const jwt = await token.toJwt();

    log(`Token generated for ${userRole} ${userId} in room ${roomId}`);

    return res.json({
      token: jwt,
      roomId: roomId,
      wsUrl: process.env.LIVEKIT_WS_URL,
      identity: userId,
    });
  } catch (err) {
    error(`Token generation failed: ${err.message}`);
    return res.json({ error: 'Token generation failed' }, 500);
  }
};
```

### Token Generation Environment Variables

```
LIVEKIT_API_KEY=your_livekit_api_key
LIVEKIT_API_SECRET=your_livekit_api_secret
LIVEKIT_WS_URL=wss://xxxxx.livekit.cloud
```

### Security Notes

- **Never** include LiveKit API secret in Flutter app code
- Token generation must always go through Appwrite Function
- Tokens have 4-hour TTL — expired tokens auto-disconnect
- Student tokens: `canPublish: false` (view-only by default)
- Instructor tokens: `canPublish: true` (camera + screen share)
- Room IDs validated server-side to prevent injection

---

## Fallback Configuration

### When LiveKit Cloud is Unavailable

```dart
class LiveKitFallbackService {
  final LiveKitService _liveKit;
  
  LiveKitFallbackService(this._liveKit);

  /// Connect with automatic fallback handling
  Future<ConnectResult> connectWithFallback({
    required String roomId,
    required String userId,
    required String userName,
    required String userRole,
  }) async {
    try {
      final room = await _liveKit.connectToRoom(
        roomId: roomId,
        userId: userId,
        userName: userName,
        userRole: userRole,
      ).timeout(const Duration(seconds: 15));
      
      return ConnectResult(connected: true, room: room);
    } on LiveKitError catch (e) {
      return _handleLiveKitError(e);
    } on TimeoutException {
      return ConnectResult(
        connected: false,
        errorMessage: 'সংযোগ সময়মতো হচ্ছে না। ইন্টারনেট চেক করুন।',
      );
    } catch (e) {
      return ConnectResult(
        connected: false,
        errorMessage: 'লাইভ ক্লাস এখন অনুপলব্ধ।',
      );
    }
  }

  ConnectResult _handleLiveKitError(LiveKitError error) {
    switch (error.code) {
      case 1001: // Connection failed
      case 1002: // Timeout
        return ConnectResult(
          connected: false,
          errorMessage: 'লাইভ ক্লাস অনুপলব্ধ। ইন্টারনেট সংযোগ চেক করুন।',
          canRetry: true,
        );
      case 1004: // Room not found
        return ConnectResult(
          connected: false,
          errorMessage: 'এই লাইভ ক্লাসটি শেষ হয়ে গেছে বা আর নেই।',
          canRetry: false,
        );
      case 1005: // Room full
        return ConnectResult(
          connected: false,
          errorMessage: 'লাইভ ক্লাস ভর্তি। কিছুক্ষণ পর চেষ্টা করুন।',
          canRetry: true,
          retryAfter: const Duration(minutes: 2),
        );
      default:
        return ConnectResult(
          connected: false,
          errorMessage: 'লাইভ ক্লাস অনুপলব্ধ। পরে আবার চেষ্টা করুন।',
          canRetry: true,
        );
    }
  }
}

class ConnectResult {
  final bool connected;
  final Room? room;
  final String? errorMessage;
  final bool canRetry;
  final Duration? retryAfter;

  ConnectResult({
    required this.connected,
    this.room,
    this.errorMessage,
    this.canRetry = false,
    this.retryAfter,
  });
}
```

### Fallback UI Widget

```dart
class LiveClassUnavailable extends StatelessWidget {
  final String message;
  final bool canRetry;
  final VoidCallback? onRetry;
  
  const LiveClassUnavailable({
    super.key,
    required this.message,
    this.canRetry = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated offline illustration
              Icon(
                Icons.videocam_off_rounded,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                'লাইভ ক্লাস অনুপলব্ধ',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF0A0E1A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              if (canRetry && onRetry != null)
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('আবার চেষ্টা করুন'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ফিরে যান'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Health Check Before Connecting

```dart
class LiveKitHealthCheck {
  static const String _healthUrl = 'https://cloud.livekit.io/api/v1/health';
  
  /// Check if LiveKit Cloud is reachable
  static Future<bool> isLiveKitAvailable() async {
    try {
      final response = await http
          .get(Uri.parse(_healthUrl))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

// Usage before navigating to live class screen
Future<void> joinLiveClass(BuildContext context, String roomId) async {
  final isAvailable = await LiveKitHealthCheck.isLiveKitAvailable();
  
  if (!isAvailable) {
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const LiveClassUnavailable(
            message: 'লাইভ ক্লাস সার্ভার অনুপলব্ধ। কিছুক্ষণ পর আবার চেষ্টা করুন।',
            canRetry: true,
          ),
        ),
      );
    }
    return;
  }
  
  // Proceed to live class
  if (context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveClassScreen(roomId: roomId, /* ... */),
      ),
    );
  }
}
```

---

## Room Management

### Creating Rooms (Server-Side Only)

```javascript
// Appwrite Function: livekit-room
// Creates/manages LiveKit rooms

import { RoomServiceClient } from 'livekit-server-sdk';

const roomService = new RoomServiceClient(
  process.env.LIVEKIT_WS_URL,
  process.env.LIVEKIT_API_KEY,
  process.env.LIVEKIT_API_SECRET
);

export default async ({ req, res }) => {
  const { action, roomName, metadata } = JSON.parse(req.body);

  switch (action) {
    case 'create': {
      const room = await roomService.createRoom({
        name: roomName,
        emptyTimeout: 300,     // 5 min
        maxParticipants: 100,
        metadata: JSON.stringify(metadata),
      });
      return res.json({ room });
    }

    case 'list': {
      const rooms = await roomService.listRooms();
      return res.json({ rooms });
    }

    case 'delete': {
      await roomService.deleteRoom(roomName);
      return res.json({ deleted: true });
    }

    case 'listParticipants': {
      const participants = await roomService.listParticipants(roomName);
      return res.json({ participants });
    }

    case 'removeParticipant': {
      const { identity } = JSON.parse(req.body);
      await roomService.removeParticipant(roomName, identity);
      return res.json({ removed: true });
    }

    case 'muteParticipant': {
      const { identity, muted } = JSON.parse(req.body);
      await roomService.updateParticipant(roomName, identity, undefined, {
        canPublish: !muted,
      });
      return res.json({ muted });
    }

    default:
      return res.json({ error: 'Unknown action' }, 400);
  }
};
```

### Free Tier Limits (Hard Coded)

```dart
class LiveKitLimits {
  static const int maxRooms = 5;
  static const int maxParticipantsPerRoom = 100;
  static const int maxMinutesPerMonth = 10000; // ~166 hours
  
  /// Check if we're likely to hit free tier limits
  static String? checkLimits({
    required int activeRooms,
    required int totalMinutesThisMonth,
  }) {
    if (activeRooms >= maxRooms) {
      return 'ফ্রি প্ল্যানে সর্বোচ্চ ৫টি রুম। আপগ্রেড করুন।';
    }
    if (totalMinutesThisMonth >= maxMinutesPerMonth * 0.9) {
      return 'এই মাসে ফ্রি মিনিট শেষ হয়ে যাচ্ছে।';
    }
    return null; // No warnings
  }
}
```

---

## Bengali UI Considerations

### Connection Status Messages

| State | Bengali Message |
|-------|----------------|
| Connecting | লাইভ ক্লাসে যুক্ত হচ্ছে... |
| Connected | লাইভ ক্লাস চলছে |
| Reconnecting | পুনরায় সংযোগ হচ্ছে... |
| Disconnected | সংযোগ বিচ্ছিন্ন হয়েছে |
| Error | সমস্যা হয়েছে |
| Room Full | ক্লাস ভর্তি |
| Ended | ক্লাস শেষ হয়েছে |

### Control Labels

| English | Bengali |
|---------|---------|
| Mute | মাইক বন্ধ |
| Unmute | মাইক খুলুন |
| Camera On | ক্যামেরা খুলুন |
| Camera Off | ক্যামেরা বন্ধ |
| Chat | চ্যাট |
| Raise Hand | হাত তুলুন |
| Leave | ক্লাস ছাড়ুন |
| Participants | অংশগ্রহণকারী |
