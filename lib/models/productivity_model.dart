import 'package:flutter/material.dart';

class AppUsageModel {
  String appName;
  int durationMinutes; // Time spent
  Color color;

  AppUsageModel({
    required this.appName,
    required this.durationMinutes,
    required this.color,
  });
}

class ProductivityModel {
  List<AppUsageModel> appUsages;
  int totalWastedMinutes;
  int productiveMinutes;
  int productivityScore; // 0 to 100
  String emotionalNudge;

  ProductivityModel({
    required this.appUsages,
    this.totalWastedMinutes = 0,
    this.productiveMinutes = 0,
    this.productivityScore = 0,
    this.emotionalNudge = '',
  });
}
