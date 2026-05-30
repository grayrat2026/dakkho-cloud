# DAKKHO — OneSignal Flutter Integration Guide

## Table of Contents
1. [Initializing OneSignal in Flutter](#initializing-onesignal-in-flutter)
2. [Handling Notification Clicks](#handling-notification-clicks)
3. [Sending Targeted Notifications from Appwrite Functions](#sending-targeted-notifications-from-appwrite-functions)
4. [Tag-Based Segmentation](#tag-based-segmentation)
5. [Bengali Notification Best Practices](#bengali-notification-best-practices)

---

## Initializing OneSignal in Flutter

### Dependencies

```yaml
# pubspec.yaml
dependencies:
  onesignal_flutter: ^5.2.0
  appwrite: ^12.0.0
```

### Android Configuration

**`android/app/build.gradle`**:
```gradle
android {
    defaultConfig {
        manifestPlaceholders += [
            onesignal_app_id: '',  // Set via code, not here
            onesignal_google_project_number: 'REMOTE'
        ]
    }
}
```

**`android/app/src/main/AndroidManifest.xml`**:
```xml
<manifest>
    <!-- OneSignal required permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
</manifest>
```

### Initialization Code

```dart
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  static const String _appId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'your-onesignal-app-id',
  );

  /// Initialize OneSignal — call once in main() before runApp()
  static Future<void> initialize() async {
    // Set log level for debugging
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

    // Initialize with app ID
    OneSignal.initialize(_appId);

    // Prompt for notification permission (Android 13+)
    final permission = await OneSignal.Notifications.requestPermission(true);
    
    if (permission == true) {
      debugPrint('✅ Notification permission granted');
    } else {
      debugPrint('⚠️ Notification permission denied');
    }

    // Set notification click handler
    OneSignal.Notifications.addClickListener(_onNotificationClicked);

    // Set foreground notification handler
    OneSignal.Notifications.addForegroundWillShowListener(_onForegroundNotification);

    // Set subscription observer
    OneSignal.User.pushSubscription.addObserver(_onSubscriptionChanged);

    debugPrint('📱 OneSignal Player ID: ${OneSignal.User.pushSubscription.id}');
  }

  /// Handle notification click
  static void _onNotificationClicked(OSNotificationClickEvent event) {
    final notification = event.notification;
    final additionalData = notification.additionalData;
    
    debugPrint('🔔 Notification clicked: ${notification.title}');
    debugPrint('📋 Additional data: $additionalData');
    
    // Route to appropriate screen based on notification category
    _handleNotificationRouting(additionalData);
  }

  /// Handle foreground notification
  static void _onForegroundNotification(OSNotificationWillDisplayEvent event) {
    // Show notification in foreground (default behavior)
    // You can modify the notification before displaying
    event.notification.display();
  }

  /// Handle subscription changes
  static void _onSubscriptionChanged(OSStateChangedEvent event) {
    debugPrint('📱 Subscription changed: ${OneSignal.User.pushSubscription.id}');
    // Sync player ID with Appwrite backend
    _syncPlayerIdWithBackend();
  }

  /// Route notification clicks to appropriate screens
  static void _handleNotificationRouting(Map<String, dynamic>? data) {
    if (data == null) return;

    final category = data['category'] as String? ?? '';
    final targetId = data['target_id'] as String? ?? '';

    switch (category) {
      case 'live_class':
        // Navigate to live class screen
        _navigateToLiveClass(targetId);
        break;
      case 'subscription':
        // Navigate to subscription screen
        _navigateToSubscription();
        break;
      case 'study_reminder':
        // Navigate to course/video
        _navigateToCourse(targetId);
        break;
      case 'announcement':
        // Navigate to announcement detail
        _navigateToAnnouncement(targetId);
        break;
      case 'system':
        // Navigate to device settings or system screen
        _navigateToSystem(targetId);
        break;
    }
  }
}
```

### Initialization in `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Appwrite first
  final client = Client()
    ..setEndpoint('https://cloud.appwrite.io/v1')
    ..setProject('your-project-id');
  
  // Initialize OneSignal
  await OneSignalService.initialize();
  
  runApp(const DakkhoApp());
}
```

---

## Handling Notification Clicks

### Deep Link Router

```dart
class NotificationRouter {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Handle notification click and navigate to the correct screen
  static void routeFromNotification(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final category = data['category'] as String? ?? '';
    
    switch (category) {
      case 'live_class':
        _routeToLiveClass(context, data);
        break;
      case 'subscription':
        Navigator.of(context).pushNamed('/subscription');
        break;
      case 'study_reminder':
        _routeToStudyReminder(context, data);
        break;
      case 'announcement':
        Navigator.of(context).pushNamed('/announcements', arguments: data['target_id']);
        break;
      case 'system':
        if (data['action'] == 'device_swap') {
          Navigator.of(context).pushNamed('/device-management');
        } else if (data['action'] == 'app_update') {
          _openAppStore();
        }
        break;
    }
  }

  static void _routeToLiveClass(BuildContext context, Map<String, dynamic> data) {
    final roomId = data['room_id'] as String? ?? '';
    final courseName = data['course_name'] as String? ?? '';
    
    Navigator.of(context).pushNamed(
      '/live-class',
      arguments: {
        'roomId': roomId,
        'courseName': courseName,
      },
    );
  }

  static void _routeToStudyReminder(BuildContext context, Map<String, dynamic> data) {
    final courseId = data['course_id'] as String? ?? '';
    final chapterId = data['chapter_id'] as String? ?? '';
    final videoId = data['video_id'] as String? ?? '';
    
    if (videoId.isNotEmpty) {
      Navigator.of(context).pushNamed(
        '/video-player',
        arguments: {
          'courseId': courseId,
          'chapterId': chapterId,
          'videoId': videoId,
        },
      );
    } else if (courseId.isNotEmpty) {
      Navigator.of(context).pushNamed('/course-detail', arguments: courseId);
    }
  }

  static void _openAppStore() {
    // Open Google Play Store
    launchUrl(Uri.parse('market://details?id=com.grayrat.dakkho.student.pro.bd'));
  }
}
```

### Notification Action Buttons (Android)

```dart
class OneSignalActionButtons {
  /// Register notification categories with action buttons
  static Future<void> setupCategories() async {
    // Android notification channels for different categories
    await OneSignal.Notifications.clearAll();
    
    // Note: Notification channels are configured in AndroidManifest.xml
    // or via the OneSignal dashboard for Android 8.0+ channel support
  }
}
```

---

## Sending Targeted Notifications from Appwrite Functions

### Appwrite Function: `send-notification`

```javascript
// Appwrite Function: send-notification
// Sends targeted push notifications via OneSignal API

const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID;
const ONESIGNAL_REST_API_KEY = process.env.ONESIGNAL_REST_API_KEY;

export default async ({ req, res, log }) => {
  const { 
    category,      // live_class | subscription | study_reminder | announcement | system
    titleBn,       // Bengali title
    titleEn,       // English title (fallback)
    messageBn,     // Bengali message
    messageEn,     // English message (fallback)
    targetSegment, // Segment name or 'specific' for individual users
    targetUsers,   // Array of player IDs (when targetSegment = 'specific')
    data,          // Additional data for click handling
    sendAt,        // ISO timestamp for scheduled delivery (optional)
  } = JSON.parse(req.body);

  // Validate required fields
  if (!category || !messageBn) {
    return res.json({ error: 'category and messageBn are required' }, 400);
  }

  // Build notification payload
  const payload = {
    app_id: ONESIGNAL_APP_ID,
    headings: {
      en: titleEn || 'DAKKHO',
      bn: titleBn || 'ডাকো',
    },
    contents: {
      en: messageEn || messageBn,
      bn: messageBn,
    },
    data: {
      category,
      ...data,
    },
    android_channel_id: category, // Maps to Android notification channel
    priority: getCategoryPriority(category),
    ttl: getCategoryTTL(category),
  };

  // Target recipients
  if (targetSegment === 'specific' && targetUsers?.length > 0) {
    payload.include_player_ids = targetUsers;
  } else if (targetSegment) {
    payload.included_segments = [targetSegment];
  } else {
    payload.included_segments = ['All'];
  }

  // Schedule if specified
  if (sendAt) {
    payload.send_after = sendAt;
  }

  try {
    const response = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    const result = await response.json();

    if (result.id) {
      log(`Notification sent: ${result.id} to ${targetSegment || 'All'}`);
      return res.json({
        success: true,
        notificationId: result.id,
        recipients: result.recipients,
      });
    } else {
      log(`Notification failed: ${JSON.stringify(result.errors)}`);
      return res.json({ 
        success: false, 
        errors: result.errors 
      }, 400);
    }
  } catch (error) {
    log(`Notification error: ${error.message}`);
    return res.json({ error: 'Failed to send notification' }, 500);
  }
};

function getCategoryPriority(category) {
  switch (category) {
    case 'live_class':
    case 'subscription':
      return 10; // High priority
    case 'study_reminder':
    case 'announcement':
      return 5;  // Normal priority
    case 'system':
      return 1;  // Low priority
    default:
      return 5;
  }
}

function getCategoryTTL(category) {
  switch (category) {
    case 'live_class':
      return 3600;     // 1 hour (class-specific)
    case 'study_reminder':
      return 7200;     // 2 hours (time-sensitive)
    case 'announcement':
      return 86400;    // 24 hours
    case 'subscription':
      return 259200;   // 3 days (important, persist)
    case 'system':
      return 86400;    // 24 hours
    default:
      return 86400;
  }
}
```

### Usage Examples from Appwrite Functions

```javascript
// Example 1: Live class starting in 5 minutes
await sendNotification({
  category: 'live_class',
  titleBn: 'লাইভ ক্লাস শুরু!',
  titleEn: 'Live Class Starting!',
  messageBn: `${courseName} লাইভ ক্লাস ৫ মিনিটে শুরু হবে`,
  messageEn: `${courseName} live class starts in 5 minutes`,
  targetSegment: 'all_users',
  data: {
    room_id: liveKitRoomId,
    course_name: courseName,
    course_id: courseId,
  },
});

// Example 2: Subscription expiring
await sendNotification({
  category: 'subscription',
  titleBn: 'সাবস্ক্রিপশন মেয়াদ শেষ',
  titleEn: 'Subscription Expiring',
  messageBn: 'আপনার প্রিমিয়াম সাবস্ক্রিপশন ৩ দিনে মেয়াদ শেষ হবে',
  messageEn: 'Your premium subscription expires in 3 days',
  targetSegment: 'trial_expiring',
  data: {
    action: 'renew_subscription',
  },
});

// Example 3: Study reminder (targeted to specific user)
await sendNotification({
  category: 'study_reminder',
  titleBn: 'পড়াশোনার সময়!',
  titleEn: 'Time to Study!',
  messageBn: 'আজকের পড়াশোনা শেষ করুন। আপনার স্ট্রিক: ৭ দিন 🔥',
  messageEn: 'Complete today\'s study. Your streak: 7 days 🔥',
  targetSegment: 'specific',
  targetUsers: [playerId],
  data: {
    course_id: courseId,
    chapter_id: chapterId,
  },
});

// Example 4: New content announcement
await sendNotification({
  category: 'announcement',
  titleBn: 'নতুন কোর্স!',
  titleEn: 'New Course!',
  messageBn: `${courseName} এখন উপলব্ধ। এখনই শুরু করুন!`,
  messageEn: `${courseName} is now available. Start learning!`,
  targetSegment: 'bteb_students',
  data: {
    course_id: courseId,
  },
});
```

---

## Tag-Based Segmentation

### Setting User Tags from Flutter

```dart
class OneSignalTagService {
  /// Set user tags for segmentation after login/registration
  static Future<void> setUserTags({
    required String userId,
    required String subscriptionType, // 'free' | 'trial' | 'basic' | 'premium'
    required String subscriptionStatus, // 'active' | 'expired' | 'cancelled'
    String? courseType, // 'bteb' | 'hsc' | 'general'
    String? department, // 'computer' | 'electrical' | etc.
    int? semester, // 1-8
    String? trialExpiresDays, // Days until trial expires
  }) async {
    // Set subscription tags
    await OneSignal.User.addTag('user_id', userId);
    await OneSignal.User.addTag('subscription_type', subscriptionType);
    await OneSignal.User.addTag('subscription_status', subscriptionStatus);

    // Set course tags
    if (courseType != null) {
      await OneSignal.User.addTag('course_type', courseType);
    }
    if (department != null) {
      await OneSignal.User.addTag('department', department);
    }
    if (semester != null) {
      await OneSignal.User.addTag('semester', semester.toString());
    }
    if (trialExpiresDays != null) {
      await OneSignal.User.addTag('trial_expires_days', trialExpiresDays);
    }

    debugPrint('🏷️ OneSignal tags set for user: $userId');
  }

  /// Update subscription tags when subscription changes
  static Future<void> updateSubscriptionTags({
    required String subscriptionType,
    required String subscriptionStatus,
  }) async {
    await OneSignal.User.addTag('subscription_type', subscriptionType);
    await OneSignal.User.addTag('subscription_status', subscriptionStatus);
  }

  /// Remove tags when user logs out
  static Future<void> clearUserTags() async {
    await OneSignal.User.removeTag('user_id');
    await OneSignal.User.removeTag('subscription_type');
    await OneSignal.User.removeTag('subscription_status');
    await OneSignal.User.removeTag('course_type');
    await OneSignal.User.removeTag('department');
    await OneSignal.User.removeTag('semester');
    await OneSignal.User.removeTag('trial_expires_days');
  }
}
```

### Tag Update Flow

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  Flutter App │────▶│  Appwrite Cloud  │────▶│  OneSignal       │
│              │     │                  │     │                  │
│ Login/Signup│     │ 1. Verify auth   │     │ Tags updated:    │
│ Purchase    │     │ 2. Update DB     │     │ - sub_type       │
│ Logout      │     │ 3. Return tags   │     │ - sub_status     │
└──────────────┘     └──────────────────┘     │ - course_type    │
                                               └──────────────────┘
```

---

## Bengali Notification Best Practices

### 1. Always provide both `bn` and `en` content

```javascript
// ✅ GOOD
{
  headings: { en: "Live Class!", bn: "লাইভ ক্লাস!" },
  contents: { en: "Class starts in 5 min", bn: "৫ মিনিটে ক্লাস শুরু" }
}

// ❌ BAD — Bengali-only will show garbled on non-Bengali devices
{
  headings: { en: "লাইভ ক্লাস!" },
  contents: { en: "৫ মিনিটে ক্লাস শুরু" }
}
```

### 2. Keep Bengali notifications under 50 characters for visibility

```javascript
// ✅ GOOD — concise
"নতুন ভিডিও আপলোড হয়েছে: ডাটাবেস ম্যানেজমেন্ট"

// ❌ BAD — too long, truncated on lock screen
"আপনার কোর্স 'কম্পিউটার সায়েন্স ৪র্থ সেমিস্টার' এর 'ডাটাবেস ম্যানেজমেন্ট সিস্টেম' চ্যাপ্টারে নতুন ভিডিও আপলোড হয়েছে"
```

### 3. Use Unicode Bengali numerals for cultural consistency

```javascript
// ✅ GOOD — Bengali numerals
"৩ দিনে সাবস্ক্রিপশন শেষ"

// Acceptable — International numerals (common in BD)
"3 দিনে সাবস্ক্রিপশন শেষ"
```

### 4. Notification timing for Bangladesh (UTC+6)

| Time | Type | Reason |
|------|------|--------|
| 8:00 AM | Study reminder | Morning study session |
| 12:00 PM | Announcement | Midday engagement |
| 5:00 PM | Live class alert | Evening class start |
| 8:00 PM | Study reminder | Evening study session |
| 10:00 PM | System | Low-impact updates |

### 5. Frequency limits

| Segment | Max per day | Max per week |
|---------|------------|-------------|
| All users | 2 | 5 |
| Premium | 3 | 7 |
| Free | 1 | 3 |
| Inactive | 1 | 2 |
