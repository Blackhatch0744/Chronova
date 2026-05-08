import 'package:flutter/material.dart';
import 'alarm_model.dart';

class UserProfileModel {
  final String userType; // Student / Employee
  final String sourceAddress;
  final String destinationAddress;
  final TransportMode transportMode;
  final TimeOfDay wakeTime;
  final TimeOfDay arrivalTime;
  final String dailyRoutine;

  UserProfileModel({
    required this.userType,
    required this.sourceAddress,
    required this.destinationAddress,
    required this.transportMode,
    required this.wakeTime,
    required this.arrivalTime,
    required this.dailyRoutine,
  });

  Map<String, dynamic> toJson() {
    return {
      'userType': userType,
      'sourceAddress': sourceAddress,
      'destinationAddress': destinationAddress,
      'transportMode': transportMode.name,
      'wakeHour': wakeTime.hour,
      'wakeMinute': wakeTime.minute,
      'arrivalHour': arrivalTime.hour,
      'arrivalMinute': arrivalTime.minute,
      'dailyRoutine': dailyRoutine,
    };
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      userType: json['userType'] ?? 'Student',
      sourceAddress: json['sourceAddress'] ?? '',
      destinationAddress: json['destinationAddress'] ?? '',
      transportMode: TransportMode.values.firstWhere(
        (mode) => mode.name == json['transportMode'],
        orElse: () => TransportMode.car,
      ),
      wakeTime: TimeOfDay(
        hour: json['wakeHour'] ?? 7,
        minute: json['wakeMinute'] ?? 0,
      ),
      arrivalTime: TimeOfDay(
        hour: json['arrivalHour'] ?? 9,
        minute: json['arrivalMinute'] ?? 0,
      ),
      dailyRoutine: json['dailyRoutine'] ?? '',
    );
  }
}