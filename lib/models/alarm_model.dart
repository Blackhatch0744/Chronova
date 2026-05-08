// TransportMode enum for dynamic traffic delay calculation
enum TransportMode { car, bike, bus, metro }

extension TransportModeLabel on TransportMode {
  String get label {
    switch (this) {
      case TransportMode.car:
        return 'Car';
      case TransportMode.bike:
        return 'Bike';
      case TransportMode.bus:
        return 'Bus';
      case TransportMode.metro:
        return 'Metro';
    }
  }

  String get icon {
    switch (this) {
      case TransportMode.car:
        return '🚗';
      case TransportMode.bike:
        return '🚲';
      case TransportMode.bus:
        return '🚌';
      case TransportMode.metro:
        return '🚇';
    }
  }
}

class AlarmModel {
  String id;
  String origin;
  String title;
  String destination;
  TransportMode transportMode;
  DateTime originalWakeTime;
  DateTime? aiUpdatedWakeTime;
  DateTime arrivalTime;
  bool isEnabled;
  int trafficDelayMinutes;
  DateTime? recommendedLeaveTime;
  String reason;
  DateTime createdAt;

  AlarmModel({
    required this.origin,
    required this.id,
    required this.title,
    required this.destination,
    required this.transportMode,
    required this.originalWakeTime,
    this.aiUpdatedWakeTime,
    required this.arrivalTime,
    this.isEnabled = true,
    this.trafficDelayMinutes = 0,
    this.recommendedLeaveTime,
    this.reason = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  DateTime get activeTime => aiUpdatedWakeTime ?? originalWakeTime;
}
