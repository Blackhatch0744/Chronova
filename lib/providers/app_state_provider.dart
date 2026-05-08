import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile_model.dart';
import '../models/alarm_model.dart';
import '../models/productivity_model.dart';
import '../models/meeting_model.dart';
import '../services/user_sync_service.dart';
import '../models/schedule_model.dart';

import '../services/mock_traffic_service.dart';
import '../services/mock_openclaw_agent.dart';
import '../services/mock_screen_time_service.dart';
import '../services/mock_notification_service.dart';
import '../services/alarm_notification_service.dart';
import '../services/openclaw_api_service.dart';
import '../services/usage_stats_service.dart';

/// AppStateProvider — single source of truth for all TimePilot AI state.
///
/// Manages: alarms, traffic, planner tasks, generated plan, productivity mode,
/// screen time data, meeting brief, and chat messages.
class AppStateProvider extends ChangeNotifier {
   bool isDarkMode = false;
  final MockOpenClawAgent openClawAgent = MockOpenClawAgent();
  final MockScreenTimeService _screenTimeService = MockScreenTimeService();
  final MockNotificationService _notificationService =
      MockNotificationService();

  // ── Alarm State ──
  String _lastAutoTrafficCheckKey = '';
  List<AlarmModel> alarms = [];
  AlarmModel? activeAlarm;
  bool isCheckingTraffic = false;
  int lastTrafficDelayMinutes = 0;
  String notificationMessage = '';

  // ── Planner State ──
  List<ScheduleModel> plannerTasks = [];
  List<ScheduleModel> generatedPlan = [];
  bool isGeneratingPlan = false;
  bool planGenerated = false;
  String suggestedWakeUpTime = '';
  String plannerNotificationMessage = '';
  List<String> productivitySuggestions = [];

  // ── Productivity State ──
  ProductivityModel? productivityData;
  String productivityMode = 'demo';
  bool hasUsagePermission = false;
  List<String> usageDebugMessages = [];
  String _lastProductivityRefreshDate = '';

  // ── Meeting State ──
  MeetingModel? meetingBrief;
  String meetingInputText = '';
  bool isGeneratingBrief = false;

  // ── Chat State ──
  List<Map<String, String>> chatMessages = [];
  bool isChatLoading = false;

  // ── Loading ──
  bool isLoadingStats = true;

  // ── Current Action Assistant ──
  String currentActionSuggestion = '';
  bool isGeneratingCurrentAction = false;
  ScheduleModel? nextActionTask;

  // ── Daily Time Report ──
  String dailyReportSummary = '';
  bool isGeneratingDailyReport = false;
  int dailyTotalTasks = 0;
  int dailyCompletedTasks = 0;
  int dailyCompletionPercent = 0;

  // ── Energy Check-in ──
  String selectedEnergyMood = 'Okay';
  String energyRescheduleMessage = '';
  String _lastDashboardResetDate = '';

  UserProfileModel? userProfile;
bool isProfileLoaded = false;
bool hasCompletedOnboarding = false;
  AppStateProvider() {
  _initializeData();
  loadUserProfile();
  loadThemePreference();
  AlarmNotificationService.init().then(
    (_) => AlarmNotificationService.requestPermissions(),
  );
}
Future<void> loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  isDarkMode = prefs.getBool('is_dark_mode') ?? false;
  notifyListeners();
}

Future<void> toggleTheme() async {
  isDarkMode = !isDarkMode;

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('is_dark_mode', isDarkMode);

  notifyListeners();
}

  int _safeNotificationId(String id) {
    final onlyNumbers = id.replaceAll(RegExp(r'[^0-9]'), '');

    if (onlyNumbers.isEmpty) {
      return 1001;
    }

    final safePart = onlyNumbers.length > 9
        ? onlyNumbers.substring(onlyNumbers.length - 9)
        : onlyNumbers;

    return int.parse(safePart);
  }
  Future<void> autoCheckTrafficIfDue(BuildContext context) async {
  if (activeAlarm == null) return;
  if (isCheckingTraffic) return;

  final now = DateTime.now();

  final checkTime = activeAlarm!.originalWakeTime.subtract(
    const Duration(hours: 1),
  );

  final diffMinutes = now.difference(checkTime).inMinutes.abs();

  final todayKey =
      '${now.year}-${now.month}-${now.day}_${activeAlarm!.id}';

  if (_lastAutoTrafficCheckKey == todayKey) return;

  // For testing/hackathon: allow 5 minute window
  if (diffMinutes <= 16) {
    _lastAutoTrafficCheckKey = todayKey;

    notificationMessage =
        'Auto Traffic Watch: checking Google Maps traffic for your route...';

    notifyListeners();

    await checkTrafficAndReschedule(context);
  }
}
Future<void> applyBackendTrafficShiftFromFcm(
  Map<String, dynamic> data,
) async {
  final type = data['type']?.toString();

  if (type != 'traffic_alarm_shift') {
    return;
  }

  if (activeAlarm == null) {
    return;
  }

  final extraDelayMinutes =
      int.tryParse(data['extraDelayMinutes']?.toString() ?? '') ?? 0;

  final normalDurationMinutes =
      int.tryParse(data['normalDurationMinutes']?.toString() ?? '') ?? 0;

  final trafficDurationMinutes =
      int.tryParse(data['trafficDurationMinutes']?.toString() ?? '') ?? 0;

  final newWakeLabel = data['newWakeLabel']?.toString();

  if (extraDelayMinutes <= 0 || newWakeLabel == null) {
    return;
  }

  final newWakeTime = _dateTimeFromBackendWakeLabel(
    newWakeLabel,
    activeAlarm!.originalWakeTime,
  );

  activeAlarm!.aiUpdatedWakeTime = newWakeTime;
  activeAlarm!.trafficDelayMinutes = extraDelayMinutes;
  lastTrafficDelayMinutes = extraDelayMinutes;

  if (trafficDurationMinutes > 0) {
    activeAlarm!.recommendedLeaveTime = activeAlarm!.arrivalTime.subtract(
      Duration(minutes: trafficDurationMinutes),
    );
  }

  activeAlarm!.reason =
      'Backend Auto Traffic Watch: Google Maps detected +$extraDelayMinutes min delay. '
      'Normal ${normalDurationMinutes}m, current ${trafficDurationMinutes}m.';

  notificationMessage =
      'Backend Auto Traffic Watch updated your alarm. '
      'Traffic +$extraDelayMinutes min. New wake-up time: $newWakeLabel.';

  final idx = alarms.indexWhere((a) => a.id == activeAlarm!.id);
  if (idx != -1) {
    alarms[idx] = activeAlarm!;
  }

  await AlarmNotificationService.rescheduleAlarm(
    id: _safeNotificationId(activeAlarm!.id),
    oldTime: activeAlarm!.originalWakeTime,
    newTime: newWakeTime,
  );

  notifyListeners();
}

DateTime _dateTimeFromBackendWakeLabel(String label, DateTime baseDate) {
  final parts = label.split(':');

  final hour = int.tryParse(parts[0]) ?? baseDate.hour;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

  return DateTime(
    baseDate.year,
    baseDate.month,
    baseDate.day,
    hour,
    minute,
  );
}
  // ────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ────────────────────────────────────────────────────────────────────────
  Future<void> loadUserProfile() async {
  final prefs = await SharedPreferences.getInstance();
  final savedProfile = prefs.getString('user_profile');

  if (savedProfile == null) {
    hasCompletedOnboarding = false;
    isProfileLoaded = true;
    notifyListeners();
    return;
  }

  final data = jsonDecode(savedProfile) as Map<String, dynamic>;
  userProfile = UserProfileModel.fromJson(data);

  hasCompletedOnboarding = true;
  isProfileLoaded = true;

  _createDefaultAlarmFromProfile();
  _createPlannerTasksFromProfile();
  notifyListeners();
}
void _createPlannerTasksFromProfile() {
  if (userProfile == null) return;

  plannerTasks.clear();

  final now = DateTime.now();

  // Main daily destination task
  plannerTasks.add(
    ScheduleModel(
      id: 'routine_arrival_${DateTime.now().millisecondsSinceEpoch}',
      title: userProfile!.userType == 'Student'
          ? 'Reach College'
          : 'Reach Office',
      description:
          'Travel from ${userProfile!.sourceAddress} to ${userProfile!.destinationAddress}',
      time: DateTime(
        now.year,
        now.month,
        now.day,
        userProfile!.arrivalTime.hour,
        userProfile!.arrivalTime.minute,
      ),
      suggestion: 'Leave on time based on live traffic updates.',
      isUserAdded: true,
      hasReminder: false,
    ),
  );

  // Simple routine text parser
  final routineText = userProfile!.dailyRoutine.trim();

  if (routineText.isNotEmpty) {
    final parts = routineText
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    int index = 0;

    for (final part in parts) {
      final parsedTime = _extractTimeFromText(part);

      plannerTasks.add(
        ScheduleModel(
          id: 'routine_task_${DateTime.now().millisecondsSinceEpoch}_$index',
          title: _cleanRoutineTitle(part),
          description: part,
          time: parsedTime ??
              DateTime(
                now.year,
                now.month,
                now.day,
                18 + (index % 4),
                0,
              ),
          suggestion: 'Auto-added from your saved daily routine.',
          isUserAdded: true,
          hasReminder: false,
        ),
      );

      index++;
    }
  }

  _sortPlannerTasks();
}
DateTime? _extractTimeFromText(String text) {
  final now = DateTime.now();
  final lower = text.toLowerCase();

  final regex = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?');
  final match = regex.firstMatch(lower);

  if (match == null) return null;

  int hour = int.tryParse(match.group(1) ?? '') ?? 0;
  int minute = int.tryParse(match.group(2) ?? '0') ?? 0;
  final period = match.group(3);

  if (period == 'pm' && hour < 12) {
    hour += 12;
  }

  if (period == 'am' && hour == 12) {
    hour = 0;
  }

  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }

  return DateTime(
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
}

String _cleanRoutineTitle(String text) {
  return text
      .replaceAll(RegExp(r'\b\d{1,2}(:\d{2})?\s*(am|pm)?\b',
          caseSensitive: false), '')
      .replaceAll('-', '')
      .trim()
      .isEmpty
      ? 'Routine Task'
      : text
          .replaceAll(RegExp(r'\b\d{1,2}(:\d{2})?\s*(am|pm)?\b',
              caseSensitive: false), '')
          .replaceAll('-', '')
          .trim();
}
Future<void> saveUserProfile(UserProfileModel profile) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString(
    'user_profile',
    jsonEncode(profile.toJson()),
  );

  userProfile = profile;
  hasCompletedOnboarding = true;

  _createDefaultAlarmFromProfile();
  _createPlannerTasksFromProfile();
  notifyListeners();
  await UserSyncService.syncProfileToBackend(profile: profile);
}

Future<void> resetUserProfile() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('user_profile');

  userProfile = null;
  hasCompletedOnboarding = false;
  alarms.clear();
  activeAlarm = null;

  notifyListeners();
}

void _createDefaultAlarmFromProfile() {
  if (userProfile == null) return;

  alarms.clear();

  final tomorrow = DateTime.now().add(const Duration(days: 1));

  final alarm = AlarmModel(
    id: 'default_alarm',
    title: userProfile!.userType == 'Student'
        ? 'College Alarm'
        : 'Office Alarm',
    origin: userProfile!.sourceAddress,
    destination: userProfile!.destinationAddress,
    transportMode: userProfile!.transportMode,
    originalWakeTime: DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      userProfile!.wakeTime.hour,
      userProfile!.wakeTime.minute,
    ),
    arrivalTime: DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      userProfile!.arrivalTime.hour,
      userProfile!.arrivalTime.minute,
    ),
  );

  alarms.add(alarm);
  activeAlarm = alarm;
}
  Future<void> _initializeData() async {
  isLoadingStats = true;
  notifyListeners();

  productivityData = await _screenTimeService.getTodayProductivity();
  _lastProductivityRefreshDate = _dateKey(DateTime.now());

  chatMessages.add({
    'role': 'ai',
    'content':
        'Hello! I\'m OpenClaw, your AI time intelligence agent. '
        'I can help with alarms, productivity, schedule, and meetings.',
  });

  isLoadingStats = false;
  notifyListeners();
}

  // ────────────────────────────────────────────────────────────────────────
  // ALARM MANAGEMENT
  // ────────────────────────────────────────────────────────────────────────

  Future<void> createAlarm(AlarmModel alarm) async {
    alarms.add(alarm);

    if (alarm.isEnabled) {
      await AlarmNotificationService.scheduleAlarm(
        id: _safeNotificationId(alarm.id),
        scheduledTime: alarm.activeTime,
        title: 'TimePilot Alarm',
        body: 'Wake up! Your alarm for ${alarm.title} is ringing.',
      );
    }

    activeAlarm ??= alarm;
    notifyListeners();
  }

  Future<void> updateAlarm(AlarmModel updated) async {
    final idx = alarms.indexWhere((a) => a.id == updated.id);

    if (idx != -1) {
      final oldAlarm = alarms[idx];
      alarms[idx] = updated;

      if (activeAlarm?.id == updated.id) {
        activeAlarm = updated;
      }

      if (oldAlarm.activeTime != updated.activeTime && updated.isEnabled) {
        await AlarmNotificationService.rescheduleAlarm(
          id: _safeNotificationId(updated.id),
          oldTime: oldAlarm.activeTime,
          newTime: updated.activeTime,
        );
      }
    }

    notifyListeners();
  }

  Future<void> deleteAlarm(String alarmId) async {
    await AlarmNotificationService.cancelAlarm(
      _safeNotificationId(alarmId),
    );

    alarms.removeWhere((a) => a.id == alarmId);

    if (activeAlarm?.id == alarmId) {
      activeAlarm = alarms.isNotEmpty ? alarms.first : null;
    }

    notifyListeners();
  }

  Future<void> toggleAlarm(String alarmId) async {
    final idx = alarms.indexWhere((a) => a.id == alarmId);

    if (idx != -1) {
      final alarm = alarms[idx];
      alarm.isEnabled = !alarm.isEnabled;

      if (alarm.isEnabled) {
        await AlarmNotificationService.scheduleAlarm(
          id: _safeNotificationId(alarm.id),
          scheduledTime: alarm.activeTime,
          title: 'TimePilot Alarm',
          body: 'Wake up! Your alarm for ${alarm.title} is ringing.',
        );
      } else {
        await AlarmNotificationService.cancelAlarm(
          _safeNotificationId(alarm.id),
        );
      }

      notifyListeners();
    }
  }

  void setActiveAlarm(String alarmId) {
    activeAlarm = alarms.firstWhere(
      (a) => a.id == alarmId,
      orElse: () => alarms.first,
    );

    notifyListeners();
  }

  Future<void> checkTrafficAndReschedule(BuildContext context) async {
    if (activeAlarm == null) return;

    isCheckingTraffic = true;
    notificationMessage = 'Checking live Google Maps traffic...';
    notifyListeners();

    try {
      final trafficResult = await TrafficApiService.checkTraffic(
        origin: activeAlarm!.origin,
        destination: activeAlarm!.destination,
        transportMode: activeAlarm!.transportMode.label,
      ).timeout(const Duration(seconds: 90));

      final delay = trafficResult.extraDelayMinutes;
      final estimatedTravelTime = trafficResult.trafficDurationMinutes;
      final reason =
          'Google Maps traffic: normal ${trafficResult.normalDurationMinutes}m, current ${trafficResult.trafficDurationMinutes}m.';

      activeAlarm!.trafficDelayMinutes = delay;
      lastTrafficDelayMinutes = delay;
      activeAlarm!.reason = reason;

      if (delay < 5) {
        notificationMessage = 'Traffic is normal. No alarm shift needed. $reason';

        if (context.mounted) {
          _notificationService.showInAppNotification(
            context,
            notificationMessage,
          );
        }

        isCheckingTraffic = false;
        notifyListeners();
        return;
      }

      final newWakeTime =
          activeAlarm!.originalWakeTime.subtract(Duration(minutes: delay));

      activeAlarm!.aiUpdatedWakeTime = newWakeTime;

      activeAlarm!.recommendedLeaveTime =
          activeAlarm!.arrivalTime.subtract(Duration(minutes: estimatedTravelTime));

      await AlarmNotificationService.rescheduleAlarm(
        id: _safeNotificationId(activeAlarm!.id),
        oldTime: activeAlarm!.originalWakeTime,
        newTime: newWakeTime,
      );

      notificationMessage =
          'Live Google Maps traffic detected +$delay min delay. Alarm shifted earlier. $reason';

      final idx = alarms.indexWhere((a) => a.id == activeAlarm!.id);
      if (idx != -1) {
        alarms[idx] = activeAlarm!;
      }

      if (context.mounted) {
        _notificationService.showInAppNotification(
          context,
          notificationMessage,
        );
      }
    } catch (e) {
      notificationMessage =
          'Traffic check failed. Check Render backend URL, Google Maps API key, or Routes API setup. Error: $e';

      if (context.mounted) {
        _notificationService.showInAppNotification(
          context,
          notificationMessage,
        );
      }
    }

    isCheckingTraffic = false;
    notifyListeners();
  }

  Future<void> testAlarmIn5Seconds() async {
    await AlarmNotificationService.showTestAlarm();
  }

  // ────────────────────────────────────────────────────────────────────────
  // CURRENT ACTION ASSISTANT
  // ────────────────────────────────────────────────────────────────────────

  Future<void> generateCurrentActionSuggestion() async {
    isGeneratingCurrentAction = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    final now = DateTime.now();

    final List<ScheduleModel> sourceTasks =
        generatedPlan.isNotEmpty ? generatedPlan : plannerTasks;

    final upcomingTasks = sourceTasks.where((task) {
      final taskMinutes = task.time.hour * 60 + task.time.minute;
      final nowMinutes = now.hour * 60 + now.minute;
      return taskMinutes >= nowMinutes && !task.isCompleted;
    }).toList()
      ..sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });

    if (upcomingTasks.isEmpty) {
      nextActionTask = null;
      currentActionSuggestion =
          'No upcoming task found. Add tasks in Planner to get AI guidance.';
      isGeneratingCurrentAction = false;
      notifyListeners();
      return;
    }

    final nextTask = upcomingTasks.first;
    nextActionTask = nextTask;

    final nextTaskTime = DateTime(
      now.year,
      now.month,
      now.day,
      nextTask.time.hour,
      nextTask.time.minute,
    );

    final minutesLeft = nextTaskTime.difference(now).inMinutes.clamp(0, 1440);
    final productivityScore = productivityData?.productivityScore ?? 0;
    final distractedMinutes = productivityData?.totalWastedMinutes ?? 0;

    String urgencyLine;

    if (minutesLeft <= 10) {
      urgencyLine = 'Start preparing now.';
    } else if (minutesLeft <= 30) {
      urgencyLine = 'Use the next $minutesLeft minutes to prepare calmly.';
    } else {
      urgencyLine = 'You have $minutesLeft minutes, so use this gap wisely.';
    }

    String distractionLine = '';

    if (distractedMinutes >= 60 || productivityScore < 50) {
      distractionLine =
          ' Your distraction time is high today, so avoid social apps until this task is done.';
    } else if (productivityScore >= 80) {
      distractionLine =
          ' Your focus score is strong today, so keep the momentum going.';
    }

    final formattedTime =
        '${nextTask.time.hour > 12 ? nextTask.time.hour - 12 : nextTask.time.hour == 0 ? 12 : nextTask.time.hour}:${nextTask.time.minute.toString().padLeft(2, '0')} ${nextTask.time.hour >= 12 ? 'PM' : 'AM'}';

    currentActionSuggestion =
        'It’s ${now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}. '
        'Your next task is "${nextTask.title}" at $formattedTime. '
        '$urgencyLine$distractionLine';

    isGeneratingCurrentAction = false;
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────────────
  // SCHEDULE PLANNER
  // ────────────────────────────────────────────────────────────────────────

  int _timeOfDayMinutes(DateTime time) {
    return time.hour * 60 + time.minute;
  }

  void _sortPlannerTasks() {
    plannerTasks.sort(
      (a, b) => _timeOfDayMinutes(a.time).compareTo(_timeOfDayMinutes(b.time)),
    );
  }

  void _sortGeneratedPlan() {
    generatedPlan.sort(
      (a, b) => _timeOfDayMinutes(a.time).compareTo(_timeOfDayMinutes(b.time)),
    );
  }

  Future<void> addPlannerTask(ScheduleModel task) async {
    DateTime reminderTime = task.time;

    if (reminderTime.isBefore(DateTime.now())) {
      reminderTime = reminderTime.add(const Duration(days: 1));
      task.time = reminderTime;
    }

    task.hasReminder = true;

    await AlarmNotificationService.scheduleTaskReminder(
      id: task.notificationId,
      scheduledTime: reminderTime,
      title: 'TimePilot Reminder',
      body: task.description.trim().isEmpty
          ? 'Your task is due now: ${task.title}'
          : '${task.title}: ${task.description}',
    );

    plannerTasks.add(task);
    _sortPlannerTasks();

    plannerNotificationMessage =
        'Reminder ON: ${task.title} at ${task.time.hour.toString().padLeft(2, '0')}:${task.time.minute.toString().padLeft(2, '0')}';

    planGenerated = false;
    generatedPlan = [];
    notifyListeners();
  }

  Future<void> deletePlannerTask(String taskId) async {
    final index = plannerTasks.indexWhere((t) => t.id == taskId);

    if (index == -1) return;

    final task = plannerTasks[index];

    if (task.hasReminder) {
      await AlarmNotificationService.cancelTaskReminder(task.notificationId);
    }

    plannerTasks.removeAt(index);
    _sortPlannerTasks();

    planGenerated = false;
    generatedPlan = [];
    notifyListeners();
  }

  void togglePlannerTaskCompleted(String taskId) {
    final plannerIndex = plannerTasks.indexWhere((t) => t.id == taskId);

    if (plannerIndex != -1) {
      plannerTasks[plannerIndex].isCompleted =
          !plannerTasks[plannerIndex].isCompleted;
    }

    final generatedIndex = generatedPlan.indexWhere((t) => t.id == taskId);

    if (generatedIndex != -1) {
      generatedPlan[generatedIndex].isCompleted =
          !generatedPlan[generatedIndex].isCompleted;
    }

    dailyReportSummary = '';
    notifyListeners();
  }

  Future<void> testPlannerReminderIn10Seconds() async {
    await AlarmNotificationService.showTestTaskReminder();
  }

  Future<void> generateAIPlan() async {
    if (plannerTasks.isEmpty) return;

    isGeneratingPlan = true;
    notifyListeners();

    generatedPlan = await openClawAgent.generateSuggestedPlan(plannerTasks);
    _sortGeneratedPlan();

    productivitySuggestions =
        openClawAgent.getProductivitySuggestions(productivityData!);

    suggestedWakeUpTime = '6:30 AM';
    planGenerated = true;

    isGeneratingPlan = false;
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────────────
  // PRODUCTIVITY
  // ────────────────────────────────────────────────────────────────────────

  Future<void> setProductivityMode(String mode) async {
    productivityMode = mode;
    await refreshProductivityData();
  }

  Future<void> checkUsagePermission() async {
    hasUsagePermission = await UsageStatsService.hasUsageAccess();
    print('[TimePilot] Real usage permission: $hasUsagePermission');
    notifyListeners();
  }

  Future<void> grantUsagePermission() async {
    await checkUsagePermission();

    if (hasUsagePermission) {
      await refreshProductivityData();
    } else {
      productivityData = ProductivityModel(
        appUsages: [],
        totalWastedMinutes: 0,
        productiveMinutes: 0,
        productivityScore: 0,
        emotionalNudge:
            'Usage Access is not enabled yet. Open Android settings and allow TimePilot AI.',
      );
      notifyListeners();
    }
  }

  Future<void> refreshProductivityData() async {
    _lastProductivityRefreshDate = _dateKey(DateTime.now());

    if (productivityMode == 'real') {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        productivityData = ProductivityModel(
          appUsages: [],
          totalWastedMinutes: 0,
          productiveMinutes: 0,
          productivityScore: 0,
          emotionalNudge: 'Real usage tracking is only available on Android.',
        );
      } else {
        await checkUsagePermission();

        if (hasUsagePermission) {
          productivityData = await _buildRealProductivityData();
        } else {
          productivityData = ProductivityModel(
            appUsages: [],
            totalWastedMinutes: 0,
            productiveMinutes: 0,
            productivityScore: 0,
            emotionalNudge: 'Waiting for Usage Access...',
          );
        }
      }
    } else {
      productivityData = await _screenTimeService.getTodayProductivity();
    }

    notifyListeners();
  }

  Future<ProductivityModel> _buildRealProductivityData() async {
    usageDebugMessages.clear();

    final realUsage = await UsageStatsService.getTodayUsageStats();

    usageDebugMessages.add('Fetched ${realUsage.length} real apps');

    final colors = <Color>[
      const Color(0xFF2563EB),
      const Color(0xFFEF4444),
      const Color(0xFF16A34A),
      const Color(0xFFF97316),
      const Color(0xFF8B5CF6),
      const Color(0xFF0EA5E9),
      const Color(0xFF22C55E),
      const Color(0xFFEC4899),
    ];

    if (realUsage.isEmpty) {
      return ProductivityModel(
        appUsages: [
          AppUsageModel(
            appName: 'No Real Usage Found',
            durationMinutes: 0,
            color: Colors.grey,
          ),
        ],
        totalWastedMinutes: 0,
        productiveMinutes: 0,
        productivityScore: 0,
        emotionalNudge:
            'Permission is enabled, but no app usage was found yet. Use some apps for a few minutes and tap refresh.',
      );
    }

    final appUsages = <AppUsageModel>[];

    final excludedPackages = {
      'com.google.android.apps.nexuslauncher',
      'com.android.launcher',
      'com.android.launcher3',
      'com.android.systemui',
      'com.android.settings',
      'com.google.android.permissioncontroller',
      'com.android.permissioncontroller',
      'com.google.android.apps.wellbeing',
      'com.google.android.as',
      'com.google.android.as.oss',
      'com.google.android.gms',
      'com.android.vending',
    };

    final excludedNameKeywords = [
      'launcher',
      'settings',
      'permission controller',
      'digital wellbeing',
      'system ui',
      'intelligence',
      'google play services',
      'google play store',
    ];

    int colorIndex = 0;

    for (final item in realUsage) {
      final packageName = item.packageName.toLowerCase();
      final appName = item.appName.toLowerCase();

      final shouldExclude =
          excludedPackages.contains(packageName) ||
          excludedNameKeywords.any((keyword) => appName.contains(keyword)) ||
          packageName.startsWith('android.');

      if (shouldExclude) {
        usageDebugMessages.add('Skipped system app: ${item.appName}');
        continue;
      }

      usageDebugMessages.add('${item.appName}: ${item.durationMinutes} min');

      appUsages.add(
        AppUsageModel(
          appName: item.appName,
          durationMinutes: item.durationMinutes,
          color: colors[colorIndex % colors.length],
        ),
      );

      colorIndex++;
    }

    if (appUsages.isEmpty) {
      return ProductivityModel(
        appUsages: [
          AppUsageModel(
            appName: 'No user apps tracked yet',
            durationMinutes: 0,
            color: Colors.grey,
          ),
        ],
        totalWastedMinutes: 0,
        productiveMinutes: 0,
        productivityScore: 0,
        emotionalNudge:
            'Real usage access is working, but only system apps were detected. Use YouTube, Chrome, Instagram, or WhatsApp for a few minutes and refresh.',
      );
    }

    final wastedKeywords = [
      'instagram',
      'youtube',
      'facebook',
      'tiktok',
      'snapchat',
      'reddit',
      'netflix',
      'twitter',
      'x',
    ];

    final totalMinutes = appUsages.fold<int>(
      0,
      (sum, item) => sum + item.durationMinutes,
    );

    final totalWastedMinutes = appUsages
        .where(
          (item) => wastedKeywords.any(
            (keyword) => item.appName.toLowerCase().contains(keyword),
          ),
        )
        .fold<int>(
          0,
          (sum, item) => sum + item.durationMinutes,
        );

    final productiveMinutes =
        (totalMinutes - totalWastedMinutes).clamp(0, totalMinutes);

    final productivityScore = totalMinutes == 0
        ? 0
        : (100 - ((totalWastedMinutes / totalMinutes) * 100).round())
            .clamp(0, 100);

    final topApp = appUsages.first.appName;

    return ProductivityModel(
      appUsages: appUsages,
      totalWastedMinutes: totalWastedMinutes,
      productiveMinutes: productiveMinutes,
      productivityScore: productivityScore,
      emotionalNudge:
          'Real Android data: Your top app today was $topApp. Total tracked screen time is $totalMinutes minutes.',
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // DAILY REPORT + ENERGY
  // ────────────────────────────────────────────────────────────────────────

  Future<void> generateDailyTimeReport() async {
    isGeneratingDailyReport = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    final List<ScheduleModel> sourceTasks =
        generatedPlan.isNotEmpty ? generatedPlan : plannerTasks;

    final userTasks = sourceTasks.where((task) => task.isUserAdded).toList();

    dailyTotalTasks = userTasks.length;
    dailyCompletedTasks = userTasks.where((task) => task.isCompleted).length;

    dailyCompletionPercent = dailyTotalTasks == 0
        ? 0
        : ((dailyCompletedTasks / dailyTotalTasks) * 100).round();

    final totalScreenMinutes = productivityData?.appUsages.fold<int>(
          0,
          (sum, item) => sum + item.durationMinutes,
        ) ??
        0;

    final screenHours = totalScreenMinutes ~/ 60;
    final screenMinutes = totalScreenMinutes % 60;

    final distractedMinutes = productivityData?.totalWastedMinutes ?? 0;
    final productivityScore = productivityData?.productivityScore ?? 0;

    if (dailyTotalTasks == 0) {
      dailyReportSummary =
          'Add tasks in Planner to generate a meaningful daily time report. '
          'Once tasks are added and marked complete, OpenClaw can compare your plan with your actual screen-time behavior.';
    } else {
      String taskLine;

      if (dailyCompletionPercent >= 80) {
        taskLine =
            'Excellent task execution today. You completed most of what you planned.';
      } else if (dailyCompletionPercent >= 50) {
        taskLine =
            'Good progress, but there is still room to improve your completion rate.';
      } else {
        taskLine =
            'Your completion rate was low today. Tomorrow, reduce the number of tasks and start with the most important one first.';
      }

      String distractionLine;

      if (distractedMinutes >= 60) {
        distractionLine =
            'Your distracted time was high, so avoid opening social apps before completing your first two tasks tomorrow.';
      } else if (distractedMinutes >= 30) {
        distractionLine =
            'Your distraction time was moderate. Try using focus blocks to protect your study/work time.';
      } else {
        distractionLine =
            'Your distraction time was controlled. Keep using reminders and planned breaks.';
      }

      dailyReportSummary =
          'Today you planned $dailyTotalTasks tasks and completed $dailyCompletedTasks. '
          'Your completion rate is $dailyCompletionPercent%. '
          'Your total tracked screen time was ${screenHours}h ${screenMinutes}m, with ${distractedMinutes}m distracted time. '
          'Your productivity score is $productivityScore/100. '
          '$taskLine $distractionLine';
    }

    isGeneratingDailyReport = false;
    notifyListeners();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  void resetDailyDashboardIfNeeded() {
    final today = _todayKey();

    if (_lastDashboardResetDate == today) return;

    _lastDashboardResetDate = today;

    selectedEnergyMood = 'Okay';
    energyRescheduleMessage = '';
    currentActionSuggestion = '';
    nextActionTask = null;
    dailyReportSummary = '';
    dailyTotalTasks = 0;
    dailyCompletedTasks = 0;
    dailyCompletionPercent = 0;

    notifyListeners();
  }

  Future<void> refreshProductivityIfNewDay() async {
    final today = _dateKey(DateTime.now());

    if (_lastProductivityRefreshDate == today && productivityData != null) {
      return;
    }

    _lastProductivityRefreshDate = today;

    productivityData = ProductivityModel(
      appUsages: [],
      totalWastedMinutes: 0,
      productiveMinutes: 0,
      productivityScore: 0,
      emotionalNudge: 'New day started. Refreshing today’s screen-time data...',
    );

    notifyListeners();

    await refreshProductivityData();
  }

  Future<void> setEnergyMood(String mood) async {
    selectedEnergyMood = mood;
    energyRescheduleMessage = '';

    if (mood == 'Low') {
      await _shiftUpcomingTasksForLowEnergy();
    } else if (mood == 'High') {
      energyRescheduleMessage =
          'High energy detected. This is a good time to start your hardest task or deep work block.';
    } else {
      energyRescheduleMessage =
          'Balanced energy. Continue with your next planned task.';
    }

    notifyListeners();
  }

  Future<void> _shiftUpcomingTasksForLowEnergy() async {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final upcomingPlannerTasks = plannerTasks.where((task) {
      final taskMinutes = task.time.hour * 60 + task.time.minute;
      return !task.isCompleted && taskMinutes >= nowMinutes;
    }).toList();

    if (upcomingPlannerTasks.isEmpty) {
      energyRescheduleMessage =
          'Low energy mode activated. No upcoming tasks were found to reschedule. Take a 15-minute rest and add lighter tasks if needed.';
      return;
    }

    for (final task in upcomingPlannerTasks) {
      if (task.hasReminder) {
        await AlarmNotificationService.cancelTaskReminder(task.notificationId);
      }

      task.time = task.time.add(const Duration(minutes: 30));
      task.suggestion =
          'Low energy adjustment: take rest first, then start this task calmly.';

      if (task.hasReminder) {
        await AlarmNotificationService.scheduleTaskReminder(
          id: task.notificationId,
          scheduledTime: task.time,
          title: 'TimePilot Reminder',
          body: task.description.trim().isEmpty
              ? 'Your rescheduled task is due now: ${task.title}'
              : '${task.title}: ${task.description}',
        );
      }
    }

    _sortPlannerTasks();

    generatedPlan = [];
    planGenerated = false;
    currentActionSuggestion = '';
    nextActionTask = null;

    energyRescheduleMessage =
        'Low energy mode activated. I shifted your upcoming tasks by 30 minutes and rescheduled reminders. Take a short rest, drink water, and restart with the easiest task first.';
  }

  // ────────────────────────────────────────────────────────────────────────
  // MEETING ASSISTANT
  // ────────────────────────────────────────────────────────────────────────

  void setMeetingInputText(String text) {
    meetingInputText = text;
    notifyListeners();
  }

  Future<void> generateMeetingBrief({
    required String inputText,
    String title = '',
    String time = '',
  }) async {
    if (inputText.trim().isEmpty) return;

    meetingInputText = inputText;
    isGeneratingBrief = true;
    notifyListeners();

    meetingBrief = await openClawAgent.generateMeetingBrief(
      inputText: inputText,
      meetingTitle: title,
      meetingTime: time,
    );

    isGeneratingBrief = false;
    notifyListeners();
  }

  // ────────────────────────────────────────────────────────────────────────
  // CHAT
  // ────────────────────────────────────────────────────────────────────────

  Map<String, dynamic>? _getNextUpcomingTaskPayload() {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    final sourceTasks = generatedPlan.isNotEmpty ? generatedPlan : plannerTasks;

    if (sourceTasks.isEmpty) return null;

    final pendingTasks = sourceTasks.where((task) => !task.isCompleted).toList();

    if (pendingTasks.isEmpty) return null;

    final upcomingToday = pendingTasks.where((task) {
      final taskMinutes = task.time.hour * 60 + task.time.minute;
      return taskMinutes >= nowMinutes;
    }).toList()
      ..sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });

    final sortedAll = pendingTasks
      ..sort((a, b) {
        final aMinutes = a.time.hour * 60 + a.time.minute;
        final bMinutes = b.time.hour * 60 + b.time.minute;
        return aMinutes.compareTo(bMinutes);
      });

    final task = upcomingToday.isNotEmpty ? upcomingToday.first : sortedAll.first;

    final taskMinutes = task.time.hour * 60 + task.time.minute;
    final isTomorrow = taskMinutes < nowMinutes;

    return {
      'title': task.title,
      'description': task.description,
      'time': task.time.toIso8601String(),
      'timeLabel':
          '${task.time.hour > 12 ? task.time.hour - 12 : task.time.hour == 0 ? 12 : task.time.hour}:${task.time.minute.toString().padLeft(2, '0')} ${task.time.hour >= 12 ? 'PM' : 'AM'}',
      'isCompleted': task.isCompleted,
      'suggestion': task.suggestion,
      'dayLabel': isTomorrow ? 'tomorrow' : 'today',
    };
  }

  DateTime _dateTimeFromTimeLabel(String timeLabel) {
    final now = DateTime.now();
    final parts = timeLabel.split(':');

    final hour = int.tryParse(parts[0]) ?? now.hour;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    return scheduledTime;
  }

  Future<String?> _handleOpenClawAction(Map<String, dynamic>? action) async {
    if (action == null) return null;

    final type = action['type']?.toString();

    if (type == 'create_task') {
      final title = action['title']?.toString().trim();
      final description = action['description']?.toString() ?? '';
      final timeLabel = action['time']?.toString();

      if (title == null || title.isEmpty || timeLabel == null) {
        return 'I understood the reminder request, but the task title or time was missing.';
      }

      final scheduledTime = _dateTimeFromTimeLabel(timeLabel);

      await addPlannerTask(
        ScheduleModel(
          id: 'task_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          description: description,
          time: scheduledTime,
          isUserAdded: true,
          hasReminder: true,
        ),
      );

      return 'Reminder created: $title at ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}.';
    }

    if (type == 'create_alarm') {
      final title = action['title']?.toString() ?? 'OpenClaw Alarm';
      final timeLabel = action['time']?.toString();

      if (timeLabel == null) {
        return 'I understood the alarm request, but the time was missing.';
      }

      final alarmTime = _dateTimeFromTimeLabel(timeLabel);

      await createAlarm(
        AlarmModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          origin: 'Whitefield, Bengaluru',
          destination: 'MG Road, Bengaluru',
          transportMode: TransportMode.car,
          originalWakeTime: alarmTime,
          arrivalTime: alarmTime.add(const Duration(hours: 2)),
          isEnabled: true,
        ),
      );

      return 'Alarm created for ${alarmTime.hour.toString().padLeft(2, '0')}:${alarmTime.minute.toString().padLeft(2, '0')}.';
    }

    return null;
  }

  Future<void> sendChatMessage(String message) async {
    chatMessages.add({'role': 'user', 'content': message});
    isChatLoading = true;
    notifyListeners();

    final now = DateTime.now();

    final contextPayload = {
      'currentDeviceTime': {
        'iso': now.toIso8601String(),
        'hour': now.hour,
        'minute': now.minute,
        'label':
            '${now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}',
      },
      'nextUpcomingTask': _getNextUpcomingTaskPayload(),
      'activeAlarm': activeAlarm == null
          ? null
          : {
              'title': activeAlarm!.title,
              'origin': activeAlarm!.origin,
              'destination': activeAlarm!.destination,
              'transportMode': activeAlarm!.transportMode.label,
              'activeTime': activeAlarm!.activeTime.toIso8601String(),
              'originalWakeTime': activeAlarm!.originalWakeTime.toIso8601String(),
              'trafficDelayMinutes': activeAlarm!.trafficDelayMinutes,
              'reason': activeAlarm!.reason,
            },
      'plannerTasks': plannerTasks
          .map(
            (task) => {
              'title': task.title,
              'description': task.description,
              'time': task.time.toIso8601String(),
              'isCompleted': task.isCompleted,
            },
          )
          .toList(),
      'generatedPlan': generatedPlan
          .map(
            (task) => {
              'title': task.title,
              'description': task.description,
              'time': task.time.toIso8601String(),
              'suggestion': task.suggestion,
              'isCompleted': task.isCompleted,
            },
          )
          .toList(),
      'productivity': productivityData == null
          ? null
          : {
              'score': productivityData!.productivityScore,
              'distractedMinutes': productivityData!.totalWastedMinutes,
              'productiveMinutes': productivityData!.productiveMinutes,
              'apps': productivityData!.appUsages
                  .map(
                    (app) => {
                      'appName': app.appName,
                      'durationMinutes': app.durationMinutes,
                    },
                  )
                  .toList(),
            },
      'meetingBrief': meetingBrief == null
          ? null
          : {
              'title': meetingBrief!.title,
              'summary': meetingBrief!.summary,
              'talkingPoints': meetingBrief!.talkingPoints,
              'preparationScore': meetingBrief!.preparationScore,
            },
      'dailyReport': {
        'summary': dailyReportSummary,
        'totalTasks': dailyTotalTasks,
        'completedTasks': dailyCompletedTasks,
        'completionPercent': dailyCompletionPercent,
      },
    };

    final response = await OpenClawApiService.askOpenClaw(
      message: message,
      context: contextPayload,
    );

    final actionResult = await _handleOpenClawAction(response.action);

    chatMessages.add({
      'role': 'ai',
      'content': actionResult == null
          ? response.reply
          : '${response.reply}\n\n$actionResult',
    });

    isChatLoading = false;
    notifyListeners();
  }

  // Dashboard backward compatibility
  List<ScheduleModel> get todaySchedule =>
      planGenerated ? generatedPlan : plannerTasks;

  MeetingModel? get nextMeeting => meetingBrief;
}