class ScheduleModel {
  String id;
  String title;
  String description;
  DateTime time;
  String suggestion;
  bool isUserAdded;
  bool hasReminder;
  bool isCompleted;
  int notificationId;

  ScheduleModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.time,
    this.suggestion = '',
    this.isUserAdded = true,
    this.hasReminder = false,
    this.isCompleted = false,
    int? notificationId,
  }) : notificationId =
            notificationId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
}