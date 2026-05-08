import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state_provider.dart';
import '../models/schedule_model.dart';
import '../widgets/theme_toggle_widget.dart';

class SchedulePlannerScreen extends StatefulWidget {
  const SchedulePlannerScreen({super.key});

  @override
  State<SchedulePlannerScreen> createState() => _SchedulePlannerScreenState();
}

class _SchedulePlannerScreenState extends State<SchedulePlannerScreen> {
  final TextEditingController _taskCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  TimeOfDay _taskTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _taskCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  DateTime _buildScheduledDateTime() {
    final now = DateTime.now();

    DateTime selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _taskTime.hour,
      _taskTime.minute,
    );

    if (selectedDateTime.isBefore(now)) {
      selectedDateTime = selectedDateTime.add(const Duration(days: 1));
    }

    return selectedDateTime;
  }
String _daySectionLabel(DateTime time) {
  final hour = time.hour;

  if (hour >= 5 && hour < 12) return 'Morning';
  if (hour >= 12 && hour < 17) return 'Afternoon';
  if (hour >= 17 && hour < 21) return 'Evening';
  return 'Night';
}

List<Widget> _buildSectionedTaskList({
  required List<ScheduleModel> tasks,
  required Widget Function(ScheduleModel task) itemBuilder,
}) {
  int timeOnlyMinutes(DateTime time) {
    return time.hour * 60 + time.minute;
  }

  final sortedTasks = [...tasks]
    ..sort(
      (a, b) => timeOnlyMinutes(a.time).compareTo(timeOnlyMinutes(b.time)),
    );

  final widgets = <Widget>[];
  String? lastSection;

  for (final task in sortedTasks) {
    final section = _daySectionLabel(task.time);

    if (section != lastSection) {
      widgets.add(_SectionHeader(title: section));
      lastSection = section;
    }

    widgets.add(itemBuilder(task));
  }

  return widgets;
}
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = theme.colorScheme.onSurface;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;
    final cardSurface = isDark ? const Color(0xFF0F172A).withOpacity(0.94) : Colors.white.withOpacity(0.86);

    final state = context.watch<AppStateProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'AI Schedule Planner',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: primaryText,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [ThemeToggleWidget()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF2563EB),
                    Color(0xFF7C3AED),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    state.planGenerated
                        ? "Your AI-optimized plan is ready!"
                        : "Plan your tomorrow with AI",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.plannerTasks.isEmpty
                        ? "Add tasks below, then tap Generate AI Plan."
                        : "${state.plannerTasks.length} tasks added. ${state.planGenerated ? '${state.generatedPlan.length} events scheduled.' : 'Ready to generate plan!'}",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  if (state.suggestedWakeUpTime.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "☀️ Suggested wake-up: ${state.suggestedWakeUpTime}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 18),
            
            // Add task input
            _GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Add Task",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _taskCtrl,
                    decoration: InputDecoration(
                      hintText: "e.g. College lecture, Gym, Study...",
                      prefixIcon: const Icon(Icons.task_alt_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F7FF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "Brief description, e.g. revise DBMS joins...",
                      prefixIcon: const Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F7FF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _taskTime,
                            );

                            if (t != null) {
                              setState(() => _taskTime = t);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F7FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 20,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _taskTime.format(context),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
  if (_taskCtrl.text.trim().isEmpty) return;

  final taskTitle = _taskCtrl.text.trim();
  final taskDescription = _descCtrl.text.trim();
  final scheduledTime = _buildScheduledDateTime();

  await state.addPlannerTask(
    ScheduleModel(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: taskTitle,
      description: taskDescription,
      time: scheduledTime,
      isUserAdded: true,
      hasReminder: true,
    ),
  );

  final delay = scheduledTime.difference(DateTime.now());

  if (delay.inSeconds > 0 && delay.inHours < 12) {
    Future.delayed(delay, () {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            taskDescription.isEmpty
                ? 'TimePilot Reminder: $taskTitle'
                : 'TimePilot Reminder: $taskTitle — $taskDescription',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    });
  }

  _taskCtrl.clear();
  _descCtrl.clear();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder scheduled for ${DateFormat.jm().format(scheduledTime)}',
        ),
      ),
    );
  }
},
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Add",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            TextButton.icon(
              onPressed: () async {
  await state.testPlannerReminderIn10Seconds();

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Instant test sent. Scheduled reminder will appear in 10 seconds.',
        ),
      ),
    );
  }

  Future.delayed(const Duration(seconds: 10), () {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'TimePilot Reminder: This is your scheduled planner reminder.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  });
},
              icon: const Icon(Icons.notifications_active_rounded),
              label: const Text('Test reminder in 10 seconds'),
            ),

            const SizedBox(height: 14),

            // User tasks
            if (state.plannerTasks.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Your Tasks",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "User Entered",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._buildSectionedTaskList(
  tasks: state.plannerTasks,
  itemBuilder: (task) => _TaskTile(
    task: task,
    onDelete: () => state.deletePlannerTask(task.id),
    onToggleCompleted: () => state.togglePlannerTaskCompleted(task.id),
  ),
),
              const SizedBox(height: 14),

              // Generate AI Plan button
              GestureDetector(
                onTap:
                    state.isGeneratingPlan ? null : () => state.generateAIPlan(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1E3A8A),
                        Color(0xFF2563EB),
                        Color(0xFF7C3AED),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.25),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      state.isGeneratingPlan
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                            ),
                      const SizedBox(width: 10),
                      Text(
                        state.isGeneratingPlan
                            ? "Generating..."
                            : "Generate AI Plan",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // AI generated plan
            if (state.planGenerated && state.generatedPlan.isNotEmpty) ...[
              const SizedBox(height: 22),
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "AI Optimized Schedule",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "AI Generated",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._buildSectionedTaskList(
  tasks: state.generatedPlan,
  itemBuilder: (item) {
    final index = state.generatedPlan.indexOf(item);

    return _TimelineItem(
      time: DateFormat.jm().format(item.time),
      title: item.title,
      suggestion: item.suggestion,
      isLast: index == state.generatedPlan.length - 1,
      index: index,
      isUserTask: item.isUserAdded,
    );
    
  },
),

              if (state.productivitySuggestions.isNotEmpty) ...[
                const SizedBox(height: 14),
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "💡 AI Suggestions",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...state.productivitySuggestions.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "•  ",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // Empty state
            if (state.plannerTasks.isEmpty) ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 64,
                      color: Colors.black.withOpacity(0.15),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "No tasks yet",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Add tomorrow's tasks above to get started",
                      style: TextStyle(color: Colors.black26),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final ScheduleModel task;
  final VoidCallback onDelete;
final VoidCallback onToggleCompleted;

  const _TaskTile({
  required this.task,
  required this.onDelete,
  required this.onToggleCompleted,
});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.92) : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Checkbox(
      value: task.isCompleted,
      activeColor: const Color(0xFF10B981),
      onChanged: (_) => onToggleCompleted(),
    ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              DateFormat.jm().format(task.time),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
  task.title,
  style: TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 15,
    decoration: task.isCompleted
        ? TextDecoration.lineThrough
        : TextDecoration.none,
    color: task.isCompleted
        ? (isDark ? Colors.white54 : Colors.black45)
        : (isDark ? Colors.white : Colors.black87),
  ),
),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    task.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
                if (task.hasReminder) ...[
                  const SizedBox(height: 4),
                  const Text(
                    "🔔 Reminder ON",
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_rounded,
              size: 20,
              color: Color(0xFFEF4444),
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String time;
  final String title;
  final String suggestion;
  final bool isLast;
  final bool isUserTask;
  final int index;

  const _TimelineItem({
    required this.time,
    required this.title,
    required this.suggestion,
    required this.isLast,
    required this.index,
    this.isUserTask = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFF10B981),
      const Color(0xFFF97316),
      const Color(0xFFEF4444),
      const Color(0xFF0EA5E9),
    ];

    final color = colors[index % colors.length];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 80,
                color: color.withOpacity(0.18),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUserTask
                  ? const Color(0xFFEFF6FF)
                  : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isUserTask
                    ? const Color(0xFF2563EB).withOpacity(0.2)
                    : Colors.white,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          if (isUserTask)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "You",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          if (!isUserTask)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "AI",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (suggestion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          suggestion,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  IconData get icon {
    switch (title) {
      case 'Morning':
        return Icons.wb_sunny_rounded;
      case 'Afternoon':
        return Icons.wb_twilight_rounded;
      case 'Evening':
        return Icons.nightlight_round;
      default:
        return Icons.bedtime_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}