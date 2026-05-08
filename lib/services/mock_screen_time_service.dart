import 'package:flutter/material.dart';
import '../models/productivity_model.dart';

class MockScreenTimeService {
  Future<ProductivityModel> getTodayProductivity() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    return ProductivityModel(
      appUsages: [
        AppUsageModel(appName: "Instagram", durationMinutes: 140, color: Colors.pinkAccent),
        AppUsageModel(appName: "YouTube", durationMinutes: 70, color: Colors.redAccent),
        AppUsageModel(appName: "WhatsApp", durationMinutes: 45, color: Colors.green),
        AppUsageModel(appName: "Study App", durationMinutes: 40, color: Colors.blueAccent),
      ],
      totalWastedMinutes: 210, // Insta + Youtube
      productiveMinutes: 85,
      productivityScore: 40,
      emotionalNudge: "You spent 2h 20m on Instagram today. In this time, you could have completed your DAA practical or revised DBMS.",
    );
  }
}
