/// Mock implementation of usage_stats package for when the real package has build issues
class MockUsageEvent {
  String? packageName;
  String? eventType;
  String? timeStamp;

  MockUsageEvent({
    required this.packageName,
    required this.eventType,
    required this.timeStamp,
  });
}

class MockUsageInfo {
  String? packageName;
  String? totalTimeInForeground;

  MockUsageInfo({
    required this.packageName,
    required this.totalTimeInForeground,
  });
}

/// Mock Usage Stats - simulates Android usage stats behavior
class UsageStats {
  // Static variable to track permission state
  static bool _hasPermission = false;

  static Future<bool?> checkUsagePermission() async {
    // Simulate checking permission - return the current state
    // In a real app, this would check if the user has granted PACKAGE_USAGE_STATS permission
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate async check
    return _hasPermission;
  }

  static Future<List<MockUsageEvent>> queryEvents(
    DateTime startTime,
    DateTime endTime,
  ) async {
    // Simulate some realistic usage events
    if (!_hasPermission) return [];

    final now = DateTime.now();
    final events = <MockUsageEvent>[];

    // Simulate usage for common apps
    final apps = [
      'com.instagram.android',
      'com.snapchat.android',
      'com.facebook.katana',
      'com.twitter.android',
      'com.google.youtube',
      'com.google.chrome',
      'com.whatsapp',
    ];

    for (int i = 0; i < apps.length; i++) {
      final app = apps[i];
      final startTime = now.subtract(Duration(hours: i + 1));
      final endTime = startTime.add(Duration(minutes: 10 + i * 3));

      // Add start event (eventType = "1" - MOVE_TO_FOREGROUND)
      events.add(MockUsageEvent(
        packageName: app,
        eventType: "1",
        timeStamp: startTime.millisecondsSinceEpoch.toString(),
      ));

      // Add end event (eventType = "2" - MOVE_TO_BACKGROUND)
      events.add(MockUsageEvent(
        packageName: app,
        eventType: "2",
        timeStamp: endTime.millisecondsSinceEpoch.toString(),
      ));
    }

    return events;
  }

  static Future<List<MockUsageInfo>> queryUsageStats(
    DateTime startTime,
    DateTime endTime,
  ) async {
    // Simulate usage stats for the day
    if (!_hasPermission) return [];

    final usageStats = <MockUsageInfo>[];

    final apps = [
      ('com.instagram.android', 2700000), // 45 minutes
      ('com.snapchat.android', 1800000), // 30 minutes
      ('com.facebook.katana', 1500000),  // 25 minutes
      ('com.twitter.android', 900000),    // 15 minutes
      ('com.google.youtube', 1200000),    // 20 minutes
      ('com.google.chrome', 3600000),     // 60 minutes
      ('com.whatsapp', 600000),           // 10 minutes
    ];

    for (final app in apps) {
      usageStats.add(MockUsageInfo(
        packageName: app.$1,
        totalTimeInForeground: app.$2.toString(),
      ));
    }

    return usageStats;
  }

  // Method to simulate granting permission (for testing)
  static void grantPermission() {
    _hasPermission = true;
  }

  // Method to simulate revoking permission (for testing)
  static void revokePermission() {
    _hasPermission = false;
  }
}
