import 'dart:math';
import '../models/alarm_model.dart';
import '../models/schedule_model.dart';
import '../models/meeting_model.dart';
import '../models/productivity_model.dart';

/// MockOpenClawAgent — simulates the OpenClaw AI agent layer.
///
/// PRODUCTION REPLACEMENT:
/// Replace HTTP calls in each method with real backend calls to OpenClaw API.
/// The method signatures remain the same for easy swapping.
class MockOpenClawAgent {
  final Random _random = Random();

  // ──────────────────────────────────────────────────────────────────────────
  // ALARM INTELLIGENCE
  // ──────────────────────────────────────────────────────────────────────────

  /// Evaluate whether an alarm adjustment is needed given a traffic delay.
  Future<Map<String, dynamic>> evaluateAlarmAdjustment(
    AlarmModel currentAlarm,
    int trafficDelayMinutes,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    if (trafficDelayMinutes > 10) {
      final DateTime newTime = currentAlarm.originalWakeTime
          .subtract(Duration(minutes: trafficDelayMinutes));

      final String modeLabel = currentAlarm.transportMode.label;
      final String dest = currentAlarm.destination.isNotEmpty
          ? currentAlarm.destination
          : 'your destination';

      final String reason =
          'Heavy $modeLabel traffic detected towards $dest. '
          'Your alarm was shifted earlier by $trafficDelayMinutes minutes to keep you on time.';

      final String notification =
          '⏰ Wake-up moved to ${_formatTime(newTime)} — '
          '$trafficDelayMinutes min $modeLabel delay on route to $dest.';

      return {
        'requiresAdjustment': true,
        'newTime': newTime,
        'reason': reason,
        'notificationPreview': notification,
      };
    }

    return {'requiresAdjustment': false};
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SCHEDULE PLANNER
  // ──────────────────────────────────────────────────────────────────────────

  /// Generate an AI-optimized schedule from user's raw task list.
  ///
  /// PRODUCTION: Send tasks to OpenClaw backend, which uses GPT/Gemini
  /// to create an optimal ordering with time blocks and reminders.
  Future<List<ScheduleModel>> generateSuggestedPlan(
    List<ScheduleModel> userTasks,
  ) async {
    await Future.delayed(const Duration(seconds: 1));

    final List<ScheduleModel> plan = [];
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    plan.add(ScheduleModel(
      id: 'ai_wakeup',
      title: '☀️ Wake Up & Morning Routine',
      time: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 6, 30),
      suggestion: 'AI suggests early start for a productive day',
      isUserAdded: false,
      hasReminder: true,
    ));
    plan.add(ScheduleModel(
      id: 'ai_breakfast',
      title: '☕ Breakfast & Review Plan',
      time: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 7, 0),
      suggestion: 'Fuel up before the day starts',
      isUserAdded: false,
    ));

    // Sort user tasks by time, then insert them with AI breaks
    final sorted = List<ScheduleModel>.from(userTasks)
      ..sort((a, b) => a.time.compareTo(b.time));

    for (int i = 0; i < sorted.length; i++) {
      final t = sorted[i];
      plan.add(ScheduleModel(
        id: t.id,
        title: t.title,
        time: t.time,
        suggestion: _aiSuggestionForTask(t.title, i),
        isUserAdded: true,
        hasReminder: true,
      ));

      // Insert AI-generated breaks between tasks
      if (i < sorted.length - 1) {
        final breakTime = t.time.add(const Duration(minutes: 30));
        if (breakTime.isBefore(sorted[i + 1].time)) {
          plan.add(ScheduleModel(
            id: 'ai_break_$i',
            title: '🧘 Short Break',
            time: breakTime,
            suggestion: 'Stay hydrated — 5 min reset improves focus by 20%',
            isUserAdded: false,
          ));
        }
      }
    }

    plan.add(ScheduleModel(
      id: 'ai_windup',
      title: '🌙 Wind Down & Review',
      time: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 22, 0),
      suggestion: 'Review what you accomplished today',
      isUserAdded: false,
    ));

    return plan;
  }

  /// Get productivity suggestions based on screen time data.
  List<String> getProductivitySuggestions(ProductivityModel data) {
    final List<String> suggestions = [];
    for (final app in data.appUsages) {
      if (app.durationMinutes > 60) {
        suggestions.add(
          'You spent ${app.durationMinutes}m on ${app.appName}. '
          'Consider setting a ${app.durationMinutes ~/ 2}m daily limit.',
        );
      }
    }
    if (data.productivityScore < 50) {
      suggestions.add(
          'Your productivity score is low. Try a 45-min focus sprint with all notifications off.');
    }
    if (suggestions.isEmpty) {
      suggestions.add(
          'Great focus today! Keep it up with short 5-min breaks every 45 minutes.');
    }
    return suggestions;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MEETING ASSISTANT
  // ──────────────────────────────────────────────────────────────────────────

  /// Generate a full meeting brief from raw user input text.
  ///
  /// PRODUCTION: Send inputText to OpenClaw/GPT backend which reads
  /// email content, calendar data, and generates contextual brief.
  Future<MeetingModel> generateMeetingBrief({
    required String inputText,
    String meetingTitle = '',
    String meetingTime = '',
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    final title =
        meetingTitle.isNotEmpty ? meetingTitle : _extractTitle(inputText);
    final prepScore = 60 + _random.nextInt(35); // 60–94

    final summary = _summarize(inputText);
    final points = _extractTalkingPoints(inputText);
    final questions = _generateQuestions(inputText);

    return MeetingModel(
      title: title,
      time: DateTime.now().add(const Duration(hours: 2)),
      location: 'Meeting Room / Virtual',
      relatedFile:
          'meeting_brief_${DateTime.now().millisecondsSinceEpoch}.md',
      summary: summary,
      talkingPoints: points,
      questionsToExpect: questions,
      confidenceScore: prepScore,
      preparationScore: prepScore,
      inputText: inputText,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CONTEXT-AWARE CHAT
  // ──────────────────────────────────────────────────────────────────────────

  /// Generate a context-aware chat response using all available app state.
  ///
  /// PRODUCTION: Send full context payload to OpenClaw secure backend endpoint.
  Future<String> getChatResponse(
    String query, {
    AlarmModel? activeAlarm,
    List<ScheduleModel>? plannerTasks,
    List<ScheduleModel>? generatedPlan,
    MeetingModel? meetingBrief,
    ProductivityModel? productivityData,
    String productivityMode = 'demo',
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final q = query.toLowerCase().trim();

    // ── Alarm / Traffic context ──
    if (q.contains('alarm') ||
        q.contains('wake') ||
        q.contains('traffic') ||
        (q.contains('why') && q.contains('changed'))) {
      if (activeAlarm != null && activeAlarm.trafficDelayMinutes > 0) {
        return '⏰ Your alarm was moved from '
            '${_formatTime(activeAlarm.originalWakeTime)} → '
            '${_formatTime(activeAlarm.activeTime)} because of '
            '${activeAlarm.trafficDelayMinutes} min ${activeAlarm.transportMode.label} '
            'traffic delay towards "${activeAlarm.destination}". '
            'In production, I\'ll use Google Maps live data for real accuracy.';
      }
      return '⏰ Your alarm is set. No significant traffic delay yet. '
          'Tap "Check Traffic Now" on the Alarm tab to get a live check.';
    }

    // ── Schedule / Plan context ──
    if (q.contains('plan') ||
        q.contains('tomorrow') ||
        q.contains('schedule') ||
        q.contains('task')) {
      if (plannerTasks != null && plannerTasks.isNotEmpty) {
        final taskNames = plannerTasks.map((t) => t.title).join(', ');
        if (generatedPlan != null && generatedPlan.isNotEmpty) {
          return '📅 Your AI-optimized plan for tomorrow has '
              '${generatedPlan.length} events. Tasks: $taskNames. '
              'Suggested wake-up: 6:30 AM. Reminders set for each task!';
        }
        return '📅 You have ${plannerTasks.length} tasks logged: $taskNames. '
            'Tap "Generate AI Plan" and I\'ll create an optimized timeline!';
      }
      return '📅 No tasks added yet. Go to Planner, add your tasks, '
          'then I\'ll generate a smart schedule with optimal time blocks.';
    }

    // ── Meeting context ──
    if (q.contains('meeting') ||
        q.contains('brief') ||
        q.contains('presentation')) {
      if (meetingBrief != null && meetingBrief.summary.isNotEmpty) {
        return '👥 Meeting "${meetingBrief.title}" brief is ready! '
            'Prep score: ${meetingBrief.preparationScore}/100. '
            'Focus on: ${meetingBrief.talkingPoints.isNotEmpty ? meetingBrief.talkingPoints.first : "your notes"}. '
            'Check the Meeting tab for all talking points & expected questions.';
      }
      return '👥 No brief yet. Go to Meeting Assistant, paste your email/text, '
          'and I\'ll generate a full brief with 5 talking points!';
    }

    // ── Screen time / Productivity context ──
    if (q.contains('screen') ||
        q.contains('focus') ||
        q.contains('productive') ||
        q.contains('distract')) {
      if (productivityData != null) {
        final mode =
            productivityMode == 'demo' ? '📊 Demo Data:' : '📊 Real Data:';
        return '$mode Productivity score ${productivityData.productivityScore}/100. '
            'Most time: ${productivityData.appUsages.isNotEmpty ? productivityData.appUsages.first.appName : "social apps"}. '
            '${productivityData.emotionalNudge}';
      }
      return '📊 Check the Focus tab for screen time breakdown and AI productivity tips!';
    }

    // ── General TimePilot response ──
    final responses = [
      'I\'m OpenClaw, the AI powering TimePilot! Ask me about alarms, traffic, schedule, meetings, or productivity.',
      'Try: "why did my alarm change?", "plan my tomorrow", "meeting brief", or "focus stats".',
      'I analyze traffic, schedule, screen time, and meetings for complete time intelligence. How can I help?',
      'TimePilot uses mock data for this MVP. In production, I\'ll connect to Google Maps, Gmail, and real usage stats.',
    ];
    return responses[_random.nextInt(responses.length)];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _aiSuggestionForTask(String title, int index) {
    final suggestions = [
      'Stay focused — mute notifications during this block',
      'Hydrate before starting this task',
      'Review notes 5 min before this begins',
      'Good energy window — ideal for deep work',
      'Take a 2-min stretch before this session',
    ];
    return suggestions[index % suggestions.length];
  }

  String _extractTitle(String text) {
    if (text.trim().isEmpty) return 'New Meeting Brief';
    final words = text.trim().split(' ').take(5).join(' ');
    return words;
  }

  String _summarize(String text) {
    if (text.isEmpty) {
      return 'No input provided. Please paste your meeting email or description.';
    }
    if (text.length < 80) {
      return 'Meeting context: "$text". Consider adding more details for a richer brief.';
    }
    final preview = text.substring(0, text.length.clamp(0, 100));
    return 'AI Summary: This meeting covers "$preview..." — '
        'Key topics include project updates, action items, and next steps. '
        'Prepare supporting data and be ready for Q&A on recent progress.';
  }

  List<String> _extractTalkingPoints(String text) {
    final defaults = [
      'Open with a clear agenda overview and expected outcomes.',
      'Present current progress with supporting metrics or examples.',
      'Highlight key blockers and propose solutions proactively.',
      'Align on next steps and assign clear ownership for each action item.',
      'Close with a summary of decisions made and follow-up timeline.',
    ];
    if (text.length > 50) {
      final preview = text.substring(0, 40);
      return [
        'Address the main topic: "$preview..."',
        ...defaults.sublist(1),
      ];
    }
    return defaults;
  }

  List<String> _generateQuestions(String text) {
    return [
      'What is the current status of the project or initiative?',
      'What are the main risks or blockers you foresee?',
      'How does this align with the overall timeline and goals?',
      'What resources or support do you need to move forward?',
      'What is the expected outcome or decision from this meeting?',
    ];
  }
}
