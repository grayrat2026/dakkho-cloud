# DAKKHO — Cloudflare R2 Flutter Integration Guide

## Table of Contents
1. [Uploading Videos from Flutter](#uploading-videos-from-flutter)
2. [Generating Presigned URLs](#generating-presigned-urls)
3. [Streaming HLS from R2](#streaming-hls-from-r2)
4. [Bunny CDN Plug & Play](#bunny-cdn-plug--play)
5. [Directory Structure](#directory-structure)
6. [Error Handling](#error-handling)

---

## Uploading Videos from Flutter

### Option A: Direct Upload via Appwrite Function (Recommended)

The Flutter app should **never** have R2 credentials. Uploads go through an Appwrite Function that handles the S3 upload server-side.

#### Flutter Side

```dart
import 'package:appwrite/appwrite.dart';

class R2UploadService {
  final Functions _functions;
  
  R2UploadService(Client client) : _functions = Functions(client);

  /// Upload a video file to R2 via Appwrite Function
  Future<VideoUploadResult> uploadVideo({
    required String localPath,
    required String courseId,
    required String chapterId,
    required String title,
    required Function(double) onProgress,
  }) async {
    // Step 1: Upload file to Appwrite Storage (temporary)
    final storage = Storage(_functions.client);
    final file = InputFile.fromPath(
      path: localPath,
      filename: '${courseId}_${chapterId}_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    
    final storageFile = await storage.createFile(
      bucketId: 'videos-raw',
      fileId: ID.unique(),
      file: file,
      onProgress: (progress) => onProgress(progress / 100),
    );

    // Step 2: Trigger Appwrite Function to process & move to R2
    final result = await _functions.createExecution(
      functionId: 'bunny-cdn-upload',
      body: jsonEncode({
        'storageFileId': storageFile.$id,
        'courseId': courseId,
        'chapterId': chapterId,
        'title': title,
        'destinationPath': 'courses/$courseId/$chapterId/${storageFile.$id}.mp4',
      }),
    );

    if (result.status != 'completed') {
      throw Exception('Video processing failed: ${result.response}');
    }

    final data = jsonDecode(result.response);
    return VideoUploadResult(
      videoId: data['videoId'],
      hlsUrl: data['hlsUrl'],
      thumbnailUrl: data['thumbnailUrl'],
    );
  }
}

class VideoUploadResult {
  final String videoId;
  final String hlsUrl;
  final String thumbnailUrl;
  
  VideoUploadResult({
    required this.videoId,
    required this.hlsUrl,
    required this.thumbnailUrl,
  });
}
```

### Option B: Presigned URL Upload (Direct to R2)

For large files (>100MB), use presigned URLs to upload directly to R2, bypassing Appwrite Storage limits.

```dart
import 'package:dio/dio.dart';

class R2DirectUpload {
  final Functions _functions;
  final Dio _dio;
  
  R2DirectUpload(Client client) 
    : _functions = Functions(client),
      _dio = Dio();

  /// Get presigned upload URL from Appwrite Function
  Future<String> _getPresignedUploadUrl(String objectKey) async {
    final result = await _functions.createExecution(
      functionId: 'r2-presign',
      body: jsonEncode({
        'action': 'put',
        'key': objectKey,
        'contentType': 'video/mp4',
        'expiresIn': 3600, // 1 hour
      }),
    );
    
    final data = jsonDecode(result.response);
    return data['url'];
  }

  /// Upload file directly to R2 using presigned URL
  Future<void> uploadWithPresignedUrl({
    required String localPath,
    required String objectKey,
    required Function(double) onProgress,
  }) async {
    final presignedUrl = await _getPresignedUploadUrl(objectKey);
    
    final file = MultipartFile.fromFileSync(localPath);
    
    await _dio.put(
      presignedUrl,
      data: FormData.fromMap({'file': file}),
      options: Options(
        contentType: 'video/mp4',
        sendTimeout: const Duration(hours: 1),
        receiveTimeout: const Duration(hours: 1),
      ),
      onSendProgress: (sent, total) {
        if (total > 0) onProgress(sent / total);
      },
    );
  }
}
```

---

## Generating Presigned URLs

### Appwrite Function: `r2-presign`

```javascript
// Appwrite Function: r2-presign
// Generates presigned URLs for R2 objects

import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

export default async ({ req, res }) => {
  const { action, key, contentType, expiresIn = 3600 } = JSON.parse(req.body);

  const s3 = new S3Client({
    region: 'auto',
    endpoint: process.env.R2_ENDPOINT,
    credentials: {
      accessKeyId: process.env.R2_ACCESS_KEY_ID,
      secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
    },
  });

  let command;
  if (action === 'put') {
    command = new PutObjectCommand({
      Bucket: process.env.R2_BUCKET_NAME,
      Key: key,
      ContentType: contentType,
    });
  } else {
    command = new GetObjectCommand({
      Bucket: process.env.R2_BUCKET_NAME,
      Key: key,
    });
  }

  const url = await getSignedUrl(s3, command, { expiresIn });

  return res.json({ url, key, expiresIn });
};
```

### Flutter Usage

```dart
class R2PresignService {
  final Functions _functions;
  
  R2PresignService(Client client) : _functions = Functions(client);

  /// Get a download URL for a video (presigned, time-limited)
  Future<String> getDownloadUrl({
    required String objectKey,
    int expiresIn = 3600,
  }) async {
    final result = await _functions.createExecution(
      functionId: 'r2-presign',
      body: jsonEncode({
        'action': 'get',
        'key': objectKey,
        'expiresIn': expiresIn,
      }),
    );
    
    final data = jsonDecode(result.response);
    return data['url'];
  }
}
```

---

## Streaming HLS from R2

### Architecture

```
┌─────────────┐     ┌──────────────────────┐     ┌──────────────────┐
│  Flutter App │────▶│  R2 Public URL /     │────▶│  HLS .m3u8 File  │
│  (media_kit) │     │  Bunny CDN (cached)  │     │  + .ts segments  │
└─────────────┘     └──────────────────────┘     └──────────────────┘
```

### R2 Directory Structure for HLS

```
dakkho-videos/
├── courses/
│   └── {courseId}/
│       └── {chapterId}/
│           └── {videoId}/
│               ├── master.m3u8        ← Main HLS manifest
│               ├── stream_0/
│               │   ├── index.m3u8     ← 720p quality
│               │   ├── seg_0.ts
│               │   ├── seg_1.ts
│               │   └── ...
│               ├── stream_1/
│               │   ├── index.m3u8     ← 480p quality
│               │   ├── seg_0.ts
│               │   └── ...
│               └── thumbnails/
│                   ├── 00001.jpg
│                   └── sprite.jpg
├── temp/                          ← Auto-deleted after 30 days
│   └── uploads/
│       └── {uploadId}.mp4
├── processing/                    ← Auto-deleted after 7 days
│   └── {videoId}/
│       └── transcoding/
└── failed/                        ← Auto-deleted after 3 days
    └── {videoId}.error.log
```

### Flutter HLS Player (media_kit)

```dart
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class DakkhoVideoPlayer extends StatefulWidget {
  final String videoId;
  final String courseId;
  final String chapterId;
  
  const DakkhoVideoPlayer({
    super.key,
    required this.videoId,
    required this.courseId,
    required this.chapterId,
  });

  @override
  State<DakkhoVideoPlayer> createState() => _DakkhoVideoPlayerState();
}

class _DakkhoVideoPlayerState extends State<DakkhoVideoPlayer> {
  late final Player _player;
  late final VideoController _controller;
  
  // Use Bunny CDN URL if configured, otherwise R2 public URL
  static const String _cdnBaseUrl = String.fromEnvironment(
    'CDN_BASE_URL',
    defaultValue: 'https://pub-XXXXX.r2.dev', // R2 public URL fallback
  );

  String get _hlsUrl => 
    '$_cdnBaseUrl/courses/${widget.courseId}/${widget.chapterId}/${widget.videoId}/master.m3u8';

  @override
  void initState() {
    super.initState();
    _player = Player(configuration: const PlayerConfiguration());
    _controller = VideoController(_player);
    _player.open(Media(_hlsUrl));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: _controller,
      controls: MaterialVideoControls,
    );
  }
}
```

### Alternative: Using video_player with HLS

```dart
import 'package:video_player/video_player.dart';

class DakkhoHLSPlayer extends StatefulWidget {
  final String hlsUrl;
  const DakkhoHLSPlayer({super.key, required this.hlsUrl});

  @override
  State<DakkhoHLSPlayer> createState() => _DakkhoHLSPlayerState();
}

class _DakkhoHLSPlayerState extends State<DakkhoHLSPlayer> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.hlsUrl))
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
```

---

## Bunny CDN Plug & Play

Bunny CDN can be layered on top of R2 for global caching with zero code changes — just swap the base URL.

### Setup Steps

1. **Create Bunny CDN account** at https://bunny.net
2. **Create a Pull Zone**:
   - Origin URL: Your R2 public URL (`https://pub-XXXXX.r2.dev`)
   - Origin Type: Storage / External
   - Name: `dakkho-videos`
3. **Configure**:
   - Enable **Edge Rules** for caching `.m3u8` for 5 min, `.ts` for 30 days
   - Enable **Token Authentication** for DRM
   - Set **Custom Hostname**: `cdn.dakkho.com.bd`
4. **Free Tier**: 1 TB/month free egress (personal account)

### Flutter: Swap CDN with One Line

```dart
class VideoUrlConfig {
  /// CDN base URL — change this single value to switch between R2 direct and Bunny CDN
  /// 
  /// R2 Direct:   https://pub-XXXXX.r2.dev
  /// Bunny CDN:   https://dakkho-videos.b-cdn.net
  /// Custom:      https://cdn.dakkho.com.bd
  static const String cdnBaseUrl = String.fromEnvironment(
    'CDN_BASE_URL',
    defaultValue: 'https://dakkho-videos.b-cdn.net', // Bunny CDN
  );

  /// Build full HLS URL for a video
  static String hlsUrl({
    required String courseId,
    required String chapterId,
    required String videoId,
  }) {
    return '$cdnBaseUrl/courses/$courseId/$chapterId/$videoId/master.m3u8';
  }

  /// Build thumbnail URL
  static String thumbnailUrl({
    required String courseId,
    required String chapterId,
    required String videoId,
  }) {
    return '$cdnBaseUrl/courses/$courseId/$chapterId/$videoId/thumbnails/00001.jpg';
  }

  /// Build sprite sheet URL for seek preview
  static String spriteUrl({
    required String courseId,
    required String chapterId,
    required String videoId,
  }) {
    return '$cdnBaseUrl/courses/$courseId/$chapterId/$videoId/thumbnails/sprite.jpg';
  }
}
```

### Bunny CDN Edge Rules (recommended)

| Pattern | TTL | Reason |
|---------|-----|--------|
| `*.m3u8` | 5 minutes | Manifest updates quickly |
| `*.ts` | 30 days | Segments are immutable |
| `*.jpg` | 7 days | Thumbnails rarely change |
| `*.mp4` | 30 days | Downloads are immutable |

### Cost Comparison

| Service | Storage | Egress | CDN | Total (1K students) |
|---------|---------|--------|-----|---------------------|
| R2 Only | Free (10GB) | **Free** | None | $0/mo |
| R2 + Bunny | Free (10GB) | Free | Free (1TB) | $0/mo |
| Scale (100GB) | $1.50 | Free | Free | $1.50/mo |

---

## Directory Structure

### Expected Video Pipeline

```
[Instructor Upload]
       │
       ▼
[Appwrite Storage (temp)] ─── videos-raw bucket (5GB limit)
       │
       ▼
[Appwrite Function: bunny-cdn-upload]
       │
       ├─▶ [Cloudflare R2] ─── HLS segments stored
       │    dakkho-videos/courses/{courseId}/{chapterId}/{videoId}/
       │
       └─▶ [Appwrite Database] ─── Video metadata updated
            videos collection: { hlsUrl, thumbnailUrl, duration, ... }
```

---

## Error Handling

```dart
class R2ErrorHandler {
  /// Map R2/CDN errors to user-friendly Bengali messages
  static String userMessage(dynamic error) {
    if (error.toString().contains('403')) {
      return 'ভিডিও অ্যাক্সেস করার অনুমতি নেই। সাবস্ক্রিপশন চেক করুন।';
    }
    if (error.toString().contains('404')) {
      return 'ভিডিও পাওয়া যায়নি। পরে আবার চেষ্টা করুন।';
    }
    if (error.toString().contains('SocketException') || 
        error.toString().contains('Connection refused')) {
      return 'ইন্টারনেট সংযোগ চেক করুন।';
    }
    return 'কিছু একটা সমস্যা হয়েছে। পরে আবার চেষ্টা করুন।';
  }

  /// Fallback: Try Bunny CDN first, then R2 direct, then show error
  static Future<String> getVideoUrlWithFallback({
    required String courseId,
    required String chapterId,
    required String videoId,
  }) async {
    const urls = [
      'https://dakkho-videos.b-cdn.net',   // Bunny CDN (primary)
      'https://pub-XXXXX.r2.dev',           // R2 direct (fallback)
    ];
    
    for (final base in urls) {
      try {
        final url = '$base/courses/$courseId/$chapterId/$videoId/master.m3u8';
        final response = await http.head(Uri.parse(url)).timeout(
          const Duration(seconds: 5),
        );
        if (response.statusCode == 200) return url;
      } catch (_) {
        continue;
      }
    }
    
    throw Exception('ভিডিও লোড করা যাচ্ছে না। সব সার্ভার অনুপলব্ধ।');
  }
}
```

---

## Quick Reference

| Task | Method |
|------|--------|
| Upload video | `R2UploadService.uploadVideo()` |
| Get download URL | `R2PresignService.getDownloadUrl()` |
| Play HLS stream | `VideoUrlConfig.hlsUrl()` |
| Switch CDN | Change `CDN_BASE_URL` env variable |
| Fallback | `R2ErrorHandler.getVideoUrlWithFallback()` |
