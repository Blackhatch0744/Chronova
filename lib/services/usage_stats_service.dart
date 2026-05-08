import 'package:flutter/services.dart';

class RealAppUsage {
  final String packageName;
  final String appName;
  final int durationMinutes;

  RealAppUsage({
    required this.packageName,
    required this.appName,
    required this.durationMinutes,
  });

  factory RealAppUsage.fromMap(Map<dynamic, dynamic> map) {
    return RealAppUsage(
      packageName: map['packageName']?.toString() ?? '',
      appName: map['appName']?.toString() ?? 'Unknown App',
      durationMinutes: map['durationMinutes'] is int
          ? map['durationMinutes'] as int
          : int.tryParse(map['durationMinutes'].toString()) ?? 0,
    );
  }
}

class UsageStatsService {
  static const MethodChannel _channel =
      MethodChannel('timepilot_ai/usage_stats');

  static Future<bool> hasUsageAccess() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasUsageAccess');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<RealAppUsage>> getTodayUsageStats() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getTodayUsageStats',
      );

      if (result == null) return [];

      return result
          .map((item) => RealAppUsage.fromMap(item as Map<dynamic, dynamic>))
          .where((item) => item.durationMinutes > 0)
          .toList();
    } catch (e) {
      return [];
    }
  }
}