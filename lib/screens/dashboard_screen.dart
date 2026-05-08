import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state_provider.dart';
import '../models/schedule_model.dart';
import '../widgets/theme_toggle_widget.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int index)? onNavigate;

  const DashboardScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedMood = 'Okay';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppStateProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = theme.colorScheme.onSurface;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateProvider>().resetDailyDashboardIfNeeded();
    });

    if (state.isLoadingStats) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final alarmTime = state.activeAlarm != null
        ? DateFormat.jm().format(state.activeAlarm!.activeTime)
        : "No alarm";

    final score = state.productivityData?.productivityScore ?? 0;
    final totalScreenMinutes = state.productivityData?.appUsages.fold<int>(
          0,
          (sum, app) => sum + app.durationMinutes,
        ) ??
        0;

    final distractedMinutes = state.productivityData?.totalWastedMinutes ?? 0;
    final productiveMinutes = state.productivityData?.productiveMinutes ?? 0;

    final tasks = [...state.todaySchedule]
      ..sort((a, b) => _minutesOfDay(a.time).compareTo(_minutesOfDay(b.time)));

    final completedTasks = tasks.where((task) => task.isCompleted).length;
    final totalTasks = tasks.length;
    final completionPercent =
        totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    final nextTask = _getNextTask(tasks);
    final usefulTimeLeft = _calculateUsefulTimeLeft(
      totalScreenMinutes: totalScreenMinutes,
      distractedMinutes: distractedMinutes,
    );

    final timeCoins = completedTasks * 20 + (score ~/ 10) * 5;
    final streakDays = completedTasks > 0 ? 3 : 0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.bolt, color: const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Text(
              "Chronova",
              style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          const ThemeToggleWidget(),
          const SizedBox(width: 8),
          _HoverGlassButton(
            borderRadius: BorderRadius.circular(50),
            glowColor: const Color(0xFF2563EB),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE0ECFF),
              child: Icon(Icons.person, color: Color(0xFF2563EB)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Good afternoon, Abhishek Kumar! 👋",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: primaryText,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Here’s your smart time intelligence brief.",
              style: TextStyle(fontSize: 16, color: secondaryText),
            ),
            const SizedBox(height: 22),

            _ProductivityHero(score: score),

            const SizedBox(height: 18),

            _QuickActionsRow(
              onAddTask: () => _goToTabOrSnack(context, 2, "Open Planner to add task"),
              onSetAlarm: () => _goToTabOrSnack(context, 1, "Open Alarm to set alarm"),
              onFocus: () => _goToTabOrSnack(context, 3, "Open Focus to start tracking"),
              onAskAI: () => _goToTabOrSnack(context, 5, "Open AI Chat"),
              onNavigate: widget.onNavigate,
            ),

            const SizedBox(height: 18),

            _TimeWalletCard(
              usefulTimeLeft: usefulTimeLeft,
              totalScreenMinutes: totalScreenMinutes,
              distractedMinutes: distractedMinutes,
              productiveMinutes: productiveMinutes,
            ),

            const SizedBox(height: 18),

            _NextActionMiniCard(
              nextTask: nextTask,
              onAskOpenClaw: state.isGeneratingCurrentAction
                  ? null
                  : () => state.generateCurrentActionSuggestion(),
            ),

            const SizedBox(height: 18),

            _DailyProgressAndCoinsCard(
              completedTasks: completedTasks,
              totalTasks: totalTasks,
              progress: completionPercent,
              streakDays: streakDays,
              timeCoins: timeCoins,
            ),

            const SizedBox(height: 18),

            _MoodCheckInCard(
  selectedMood: state.selectedEnergyMood,
  energyMessage: state.energyRescheduleMessage,
  onMoodSelected: (mood) {
    state.setEnergyMood(mood);
  },
),

            const SizedBox(height: 18),

            _LiveTimelineCard(tasks: tasks),

            const SizedBox(height: 18),

            _RegretForecastCard(
              nextTask: nextTask,
              distractedMinutes: distractedMinutes,
            ),

            const SizedBox(height: 18),

            _GlassCard(
              glowColor: const Color(0xFF2563EB),
              child: Row(
                children: [
                  const _IconBox(
                    icon: Icons.alarm,
                    color: Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Active Alarm",
                          style: TextStyle(color: Colors.black54),
                        ),
                        Text(
                          alarmTime,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (state.activeAlarm != null &&
                            state.activeAlarm!.trafficDelayMinutes > 0)
                          Text(
                            "Shifted due to ${state.activeAlarm!.trafficDelayMinutes}m traffic",
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.black38,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _GlassCard(
              glowColor: const Color(0xFF7C3AED),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF7C3AED),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "What should I do now?",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.currentActionSuggestion.isEmpty
                        ? "Ask OpenClaw to analyze your planner, focus score, and next task."
                        : state.currentActionSuggestion,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      height: 1.4,
                      fontSize: 14,
                    ),
                  ),
                  if (state.nextActionTask != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: Color(0xFF7C3AED),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Next: ${state.nextActionTask!.title} at ${DateFormat.jm().format(state.nextActionTask!.time)}",
                              style: const TextStyle(
                                color: Color(0xFF5B21B6),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: state.isGeneratingCurrentAction
                          ? null
                          : () => state.generateCurrentActionSuggestion(),
                      icon: state.isGeneratingCurrentAction
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.psychology_alt_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        state.isGeneratingCurrentAction
                            ? "OpenClaw thinking..."
                            : "Ask OpenClaw",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _GlassCard(
              glowColor: const Color(0xFF10B981),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.assessment_rounded,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Daily Time Intelligence Report",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (state.dailyReportSummary.isEmpty)
                    const Text(
                      "Generate your end-of-day report using planner tasks, completed work, and screen-time data.",
                      style: TextStyle(
                        color: Color(0xFF374151),
                        height: 1.4,
                        fontSize: 14,
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _ReportMiniStat(
                            title:
                                "${state.dailyCompletedTasks}/${state.dailyTotalTasks}",
                            subtitle: "Tasks done",
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ReportMiniStat(
                            title: "${state.dailyCompletionPercent}%",
                            subtitle: "Completion",
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ReportMiniStat(
                            title:
                                "${state.productivityData?.productivityScore ?? 0}/100",
                            subtitle: "Focus score",
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.dailyReportSummary,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        height: 1.45,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: state.isGeneratingDailyReport
                          ? null
                          : () => state.generateDailyTimeReport(),
                      icon: state.isGeneratingDailyReport
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.auto_graph_rounded,
                              color: Colors.white,
                            ),
                      label: Text(
                        state.isGeneratingDailyReport
                            ? "Generating report..."
                            : "Generate Report",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.calendar_month,
                    title: totalTasks.toString(),
                    subtitle: "Tasks",
                    color: const Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.task_alt,
                    title: completedTasks.toString(),
                    subtitle: "Done",
                    color: const Color(0xFF16A34A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.timer,
                    title: _formatMinutes(productiveMinutes),
                    subtitle: "Focus Time",
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            _GlassCard(
              glowColor: const Color(0xFF2563EB),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "AI Suggestions for You",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 14),
                  _SuggestionTile(
                    icon: Icons.wb_sunny,
                    title: "Best focus time today",
                    subtitle: "9:00 AM - 11:00 AM",
                    color: Color(0xFFF59E0B),
                  ),
                  _SuggestionTile(
                    icon: Icons.traffic,
                    title: "Traffic alert",
                    subtitle: "Heavy traffic on your route in 25m",
                    color: Color(0xFFEF4444),
                  ),
                  _SuggestionTile(
                    icon: Icons.coffee,
                    title: "Take a short break",
                    subtitle: "You’ve been focused for 90m",
                    color: Color(0xFF2563EB),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _goToTabOrSnack(BuildContext context, int index, String message) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(index);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

int _minutesOfDay(DateTime time) {
  return time.hour * 60 + time.minute;
}

ScheduleModel? _getNextTask(List<ScheduleModel> tasks) {
  if (tasks.isEmpty) return null;

  final now = DateTime.now();
  final nowMinutes = _minutesOfDay(now);

  final pendingTasks = tasks.where((task) => !task.isCompleted).toList();

  if (pendingTasks.isEmpty) return null;

  final upcomingToday = pendingTasks.where((task) {
    return _minutesOfDay(task.time) >= nowMinutes;
  }).toList()
    ..sort((a, b) => _minutesOfDay(a.time).compareTo(_minutesOfDay(b.time)));

  if (upcomingToday.isNotEmpty) return upcomingToday.first;

  pendingTasks.sort(
    (a, b) => _minutesOfDay(a.time).compareTo(_minutesOfDay(b.time)),
  );

  return pendingTasks.first;
}

int _calculateUsefulTimeLeft({
  required int totalScreenMinutes,
  required int distractedMinutes,
}) {
  const wakingMinutes = 16 * 60;
  final usefulLeft = wakingMinutes - totalScreenMinutes - distractedMinutes;
  return usefulLeft.clamp(0, wakingMinutes);
}

String _formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;

  if (h <= 0) return "${m}m";
  return "${h}h ${m}m";
}

String _formatTaskTime(DateTime time) {
  return DateFormat.jm().format(time);
}

String _minutesUntilText(DateTime taskTime) {
  final now = DateTime.now();
  DateTime target = DateTime(
    now.year,
    now.month,
    now.day,
    taskTime.hour,
    taskTime.minute,
  );

  if (target.isBefore(now)) {
    target = target.add(const Duration(days: 1));
  }

  final diff = target.difference(now).inMinutes;

  if (diff < 1) return "starting now";
  if (diff < 60) return "starts in ${diff}m";

  final h = diff ~/ 60;
  final m = diff % 60;

  if (m == 0) return "starts in ${h}h";
  return "starts in ${h}h ${m}m";
}

class _ProductivityHero extends StatelessWidget {
  final int score;

  const _ProductivityHero({
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverGlassButton(
      glowColor: const Color(0xFF7C3AED),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF2563EB),
              Color(0xFF7C3AED),
            ],
          ),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_graph,
              size: 46,
              color: Colors.white,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Productivity Score",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    "$score/100",
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    "▲ 8% from yesterday",
                    style: TextStyle(color: Color(0xFFBBF7D0)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onSetAlarm;
  final VoidCallback onFocus;
  final VoidCallback onAskAI;
  final void Function(int index)? onNavigate;

  const _QuickActionsRow({
    required this.onAddTask,
    required this.onSetAlarm,
    required this.onFocus,
    required this.onAskAI,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_task_rounded,
            label: "Add Task",
            color: const Color(0xFF7C3AED),
            onTap: onAddTask,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.alarm_add_rounded,
            label: "Set Alarm",
            color: const Color(0xFF2563EB),
            onTap: onSetAlarm,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.auto_awesome_rounded,
            label: "Ask AI",
            color: const Color(0xFF10B981),
            onTap: onAskAI,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverGlassButton(
      onTap: onTap,
      glowColor: color,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.95)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeWalletCard extends StatelessWidget {
  final int usefulTimeLeft;
  final int totalScreenMinutes;
  final int distractedMinutes;
  final int productiveMinutes;

  const _TimeWalletCard({
    required this.usefulTimeLeft,
    required this.totalScreenMinutes,
    required this.distractedMinutes,
    required this.productiveMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      glowColor: const Color(0xFF2563EB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              _SmallGradientIcon(
                icon: Icons.account_balance_wallet_rounded,
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              ),
              SizedBox(width: 10),
              Text(
                "Time Wallet",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatMinutes(usefulTimeLeft),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "useful time balance left today",
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _WalletPill(
                  label: "Screen",
                  value: _formatMinutes(totalScreenMinutes),
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WalletPill(
                  label: "Distracted",
                  value: _formatMinutes(distractedMinutes),
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WalletPill(
                  label: "Focused",
                  value: _formatMinutes(productiveMinutes),
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _WalletPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActionMiniCard extends StatelessWidget {
  final ScheduleModel? nextTask;
  final VoidCallback? onAskOpenClaw;

  const _NextActionMiniCard({
    required this.nextTask,
    required this.onAskOpenClaw,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      glowColor: const Color(0xFF7C3AED),
      child: Row(
        children: [
          const _SmallGradientIcon(
            icon: Icons.near_me_rounded,
            colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: nextTask == null
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Next Action",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "No upcoming task — add one in Planner",
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Next Action",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextTask!.title,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        "${_formatTaskTime(nextTask!.time)} • ${_minutesUntilText(nextTask!.time)}",
                        style: const TextStyle(
                          color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
          _HoverGlassButton(
            onTap: onAskOpenClaw,
            glowColor: const Color(0xFF7C3AED),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.psychology_alt_rounded,
                color: Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyProgressAndCoinsCard extends StatelessWidget {
  final int completedTasks;
  final int totalTasks;
  final double progress;
  final int streakDays;
  final int timeCoins;

  const _DailyProgressAndCoinsCard({
    required this.completedTasks,
    required this.totalTasks,
    required this.progress,
    required this.streakDays,
    required this.timeCoins,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      glowColor: const Color(0xFFF97316),
      child: Row(
        children: [
          SizedBox(
            height: 82,
            width: 82,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 78,
                  width: 78,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: const Color(0xFFF3F4F6),
                    color: const Color(0xFF10B981),
                  ),
                ),
                Text(
                  "${(progress * 100).round()}%",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today’s Progress",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "$completedTasks/$totalTasks tasks completed",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TinyBadge(
                      text: "🔥 $streakDays-day streak",
                      color: const Color(0xFFF97316),
                    ),
                    _TinyBadge(
                      text: "🪙 $timeCoins TimeCoins",
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodCheckInCard extends StatelessWidget {
  final String selectedMood;
  final String energyMessage;
  final void Function(String mood) onMoodSelected;

  const _MoodCheckInCard({
    required this.selectedMood,
    required this.energyMessage,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    final moods = [
      ("😫", "Low"),
      ("🙂", "Okay"),
      ("🚀", "High"),
    ];

    String defaultMessage;

    if (selectedMood == "Low") {
      defaultMessage =
          "Low energy mode. TimePilot will protect your day by shifting upcoming tasks and suggesting a short rest.";
    } else if (selectedMood == "High") {
      defaultMessage =
          "Great time for deep work. Start your hardest task before distractions enter.";
    } else {
      defaultMessage =
          "Balanced energy. Continue with your next planned task.";
    }

    return _GlassCard(
      glowColor: const Color(0xFF10B981),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              _SmallGradientIcon(
                icon: Icons.favorite_rounded,
                colors: [Color(0xFF10B981), Color(0xFF2563EB)],
              ),
              SizedBox(width: 10),
              Text(
                "Energy Check-in",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "How’s your energy right now?",
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Row(
            children: moods.map((mood) {
              final active = selectedMood == mood.$2;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onMoodSelected(mood.$2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF10B981)
                              : Colors.white,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            mood.$1,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            mood.$2,
                            style: TextStyle(
                              color: active
                                  ? const Color(0xFF047857)
                                  : Colors.black54,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            energyMessage.isEmpty ? defaultMessage : energyMessage,
            style: const TextStyle(
              color: Color(0xFF374151),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveTimelineCard extends StatelessWidget {
  final List<ScheduleModel> tasks;

  const _LiveTimelineCard({
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.take(5).toList();

    return _GlassCard(
      glowColor: const Color(0xFF2563EB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              _SmallGradientIcon(
                icon: Icons.timeline_rounded,
                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
              ),
              SizedBox(width: 10),
              Text(
                "Live Day Timeline",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (visibleTasks.isEmpty)
            const Text(
              "No tasks yet. Add tasks in Planner to build your timeline.",
              style: TextStyle(color: Colors.black54),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: visibleTasks.map((task) {
                  final active = !task.isCompleted &&
                      _minutesOfDay(task.time) >=
                          _minutesOfDay(DateTime.now());

                  return _TimelineNode(
                    title: task.title,
                    time: _formatTaskTime(task.time),
                    active: active,
                    completed: task.isCompleted,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  final String title;
  final String time;
  final bool active;
  final bool completed;

  const _TimelineNode({
    required this.title,
    required this.time,
    required this.active,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? const Color(0xFF10B981)
        : active
            ? const Color(0xFF7C3AED)
            : const Color(0xFF94A3B8);

    return Row(
      children: [
        Column(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.14),
                border: Border.all(color: color.withOpacity(0.45)),
              ),
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle,
                color: color,
                size: completed ? 20 : 12,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 92,
              child: Column(
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(
          width: 28,
          height: 2,
          color: color.withOpacity(0.25),
        ),
      ],
    );
  }
}

class _RegretForecastCard extends StatelessWidget {
  final ScheduleModel? nextTask;
  final int distractedMinutes;

  const _RegretForecastCard({
    required this.nextTask,
    required this.distractedMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final title = nextTask?.title ?? "your next task";

    return _GlassCard(
      glowColor: const Color(0xFFEF4444),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              _SmallGradientIcon(
                icon: Icons.warning_amber_rounded,
                colors: [Color(0xFFEF4444), Color(0xFFF97316)],
              ),
              SizedBox(width: 10),
              Text(
                "Regret Forecast",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "If you scroll for 30 minutes now, $title may shift later and your sleep/focus window can shrink.",
            style: const TextStyle(
              color: Color(0xFF374151),
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4E6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.trending_down_rounded,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    distractedMinutes > 0
                        ? "You already have ${distractedMinutes}m distracted time today. Protect your next block."
                        : "No major distracted time detected yet. Keep it that way.",
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverGlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color glowColor;

  const _HoverGlassButton({
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(26)),
    this.glowColor = const Color(0xFF2563EB),
  });

  @override
  State<_HoverGlassButton> createState() => _HoverGlassButtonState();
}

class _HoverGlassButtonState extends State<_HoverGlassButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(hover ? 1.018 : 1.0),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(hover ? 0.22 : 0.0),
                blurRadius: hover ? 28 : 0,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color glowColor;

  const _GlassCard({
    required this.child,
    this.onTap,
    this.glowColor = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _HoverGlassButton(
      onTap: onTap,
      glowColor: glowColor,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A).withOpacity(0.94) : Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.92)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.16 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverGlassButton(
      glowColor: color,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 54,
        width: 54,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.75)),
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}

class _SmallGradientIcon extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;

  const _SmallGradientIcon({
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: colors),
      ),
      child: Icon(icon, color: Colors.white, size: 19),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _TinyBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      glowColor: color,
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMiniStat extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _ReportMiniStat({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SuggestionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverGlassButton(
      glowColor: color,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            _IconBox(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}