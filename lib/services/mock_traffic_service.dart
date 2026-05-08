import 'dart:convert';
import 'package:http/http.dart' as http;

class TrafficCheckResult {
  final int normalDurationMinutes;
  final int trafficDurationMinutes;
  final int extraDelayMinutes;
  final bool shouldReschedule;
  final int distanceMeters;
  final String message;

  TrafficCheckResult({
    required this.normalDurationMinutes,
    required this.trafficDurationMinutes,
    required this.extraDelayMinutes,
    required this.shouldReschedule,
    required this.distanceMeters,
    required this.message,
  });

  factory TrafficCheckResult.fromJson(Map<String, dynamic> json) {
    return TrafficCheckResult(
      normalDurationMinutes: json['normalDurationMinutes'] ?? 0,
      trafficDurationMinutes: json['trafficDurationMinutes'] ?? 0,
      extraDelayMinutes: json['extraDelayMinutes'] ?? 0,
      shouldReschedule: json['shouldReschedule'] ?? false,
      distanceMeters: json['distanceMeters'] ?? 0,
      message: json['message']?.toString() ?? '',
    );
  }
}

class TrafficApiService {
  // Use your live Render backend URL here.
  static const String baseUrl = 'https://hackathon-cz82.onrender.com';

  static Future<TrafficCheckResult> checkTraffic({
    required String origin,
    required String destination,
    required String transportMode,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/check-traffic'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'origin': origin,
        'destination': destination,
        'transportMode': transportMode,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Traffic API failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return TrafficCheckResult.fromJson(data);
  }
}