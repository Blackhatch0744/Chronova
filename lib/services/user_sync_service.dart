import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile_model.dart';
import 'fcm_service.dart';

class UserSyncService {
  static const String baseUrl = 'https://hackathon-cz82.onrender.com';

  static Future<void> syncProfileToBackend({
    required UserProfileModel profile,
  }) async {
    final token = await FcmService.getDeviceToken();

    if (token == null) {
      throw Exception('FCM token not available');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/save-user-routine'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'deviceId': token,
        'fcmToken': token,
        'userType': profile.userType,
        'origin': profile.sourceAddress,
        'destination': profile.destinationAddress,
        'transportMode': profile.transportMode.name,
        'wakeHour': profile.wakeTime.hour,
        'wakeMinute': profile.wakeTime.minute,
        'arrivalHour': profile.arrivalTime.hour,
        'arrivalMinute': profile.arrivalTime.minute,
        'dailyRoutine': profile.dailyRoutine,
        'autoTrafficWatch': true,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend sync failed: ${response.body}');
    }
  }
}