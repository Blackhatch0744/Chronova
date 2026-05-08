import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenClawResponse {
  final String reply;
  final Map<String, dynamic>? action;

  OpenClawResponse({
    required this.reply,
    this.action,
  });

  factory OpenClawResponse.fromJson(Map<String, dynamic> json) {
    return OpenClawResponse(
      reply: json['reply']?.toString() ?? 'OpenClaw did not return a reply.',
      action: json['action'] is Map
          ? Map<String, dynamic>.from(json['action'] as Map)
          : null,
    );
  }
}

class OpenClawApiService {
  // Android emulator uses 10.0.2.2 to access localhost on your Mac.
  static const String baseUrl = 'https://hackathon-cz82.onrender.com';
  static Future<OpenClawResponse> askOpenClaw({
    required String message,
    required Map<String, dynamic> context,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ask-openclaw'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'context': context,
        }),
      );

      if (response.statusCode != 200) {
        return OpenClawResponse(
          reply:
              'OpenClaw backend error: ${response.statusCode}. Please check server logs.',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return OpenClawResponse.fromJson(data);
    } catch (e) {
      return OpenClawResponse(
        reply:
            'Could not connect to OpenClaw backend. Make sure backend is running on port 3000.',
      );
    }
  }
}