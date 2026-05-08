import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import '../providers/app_state_provider.dart';
import '../widgets/theme_toggle_widget.dart';

class ProductivityScreen extends StatelessWidget {
  const ProductivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = theme.colorScheme.onSurface;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;
    final surfaceFill = isDark ? const Color(0xFF111827).withOpacity(0.92) : const Color(0xFFF4F7FF);

    final state = context.watch<AppStateProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateProvider>().refreshProductivityIfNewDay();
    });
    final data = state.productivityData;
    final isDemo = state.productivityMode == 'demo';

    if (data == null) return const Center(child: CircularProgressIndicator());

    final totalMinutes = data.appUsages.fold<int>(0, (sum, item) => sum + item.durationMinutes);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final statusText = isDemo
        ? "📊 Demo Data — not real usage"
        : state.hasUsagePermission
            ? (totalMinutes > 0
                ? "🟢 Live tracking — today's usage is live"
                : "🟡 Live tracking enabled — no recorded usage yet")
            : "⚠️ Usage permission required for live tracking";
    final statusTextColor = isDemo ? const Color(0xFF92400E) : const Color(0xFF166534);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Focus Intelligence', style: TextStyle(fontWeight: FontWeight.w900, color: primaryText)),
        centerTitle: true, backgroundColor: Colors.transparent, elevation: 0,
        actions: const [ThemeToggleWidget()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Mode toggle card
          _GlassCard(child: Row(children: [
            _IconBubble(icon: Icons.science_rounded, color: isDemo ? const Color(0xFFF97316) : const Color(0xFF16A34A)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isDemo ? "Demo Mode" : "Real Mode", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text(isDemo ? "Showing mock screen-time data" : "Reading real Android usage data",
                style: TextStyle(color: secondaryText, fontSize: 13)),
            ])),
            Switch(
              value: !isDemo,
              activeThumbColor: const Color(0xFF16A34A),
              onChanged: (val) async => await state.setProductivityMode(val ? 'real' : 'demo'),
            ),
          ])),

          const SizedBox(height: 14),

          // Real mode placeholder
          if (!isDemo && !state.hasUsagePermission) ...[
            _GlassCard(child: Column(children: [
              const Icon(Icons.android_rounded, size: 48, color: Color(0xFF16A34A)),
              const SizedBox(height: 12),
              Text("Real Android Usage Access", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: primaryText)),
              const SizedBox(height: 8),
              Text(
                "To analyze real app usage, TimePilot needs Usage Access permission on Android. "
                "Real Android UsageStats integration will read app usage after permission is granted.",
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryText, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () {
                  if (defaultTargetPlatform == TargetPlatform.android) {
                    const intent = AndroidIntent(
                      action: 'android.settings.USAGE_ACCESS_SETTINGS',
                      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                    );
                    intent.launch();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Usage access is only available on Android.')),
                    );
                  }
                },
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
                label: const Text("Grant Usage Access", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              )),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => state.grantUsagePermission(),
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF16A34A)),
                label: const Text("Refresh Permission Status", style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                child: const Text("⚠️ Not available on macOS/web — Android only", style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
              ),
            ])),
            const SizedBox(height: 80),
          ],

          // Demo mode content or Real Mode Data
          if (isDemo || (!isDemo && state.hasUsagePermission)) ...[
            // Demo/Real badge
            Center(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: isDemo ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(14)),
              child: Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusTextColor)),
            )),

            const SizedBox(height: 14),

            // Hero score card
            Container(
              width: double.infinity, padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF7C3AED)]),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.28), blurRadius: 28, offset: const Offset(0, 14))],
              ),
              child: Row(children: [
                const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 54),
                const SizedBox(width: 18),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Productivity Score", style: TextStyle(color: Colors.white70)),
                  Text("${data.productivityScore}/100", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                  Text("Total screen time: ${hours}h ${minutes}m", style: const TextStyle(color: Colors.white70)),
                ])),
              ]),
            ),

            const SizedBox(height: 18),

            Row(children: [
              Expanded(child: _MiniStat(icon: Icons.phone_iphone_rounded, title: "${hours}h ${minutes}m", subtitle: "Screen Time", color: const Color(0xFF2563EB))),
              const SizedBox(width: 12),
              Expanded(child: _MiniStat(icon: Icons.trending_down_rounded, title: "${data.totalWastedMinutes}m", subtitle: "Distracted", color: const Color(0xFFEF4444))),
              const SizedBox(width: 12),
              Expanded(child: _MiniStat(icon: Icons.menu_book_rounded, title: "${data.productiveMinutes}m", subtitle: "Productive", color: const Color(0xFF16A34A))),
            ]),

            const SizedBox(height: 20),

            _GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Screen Time Breakdown", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryText)),
              const SizedBox(height: 8),
              Text("See where your attention went today.", style: TextStyle(color: secondaryText)),
              const SizedBox(height: 24),
              SizedBox(height: 230, child: PieChart(PieChartData(
                sectionsSpace: 4, centerSpaceRadius: 58,
                sections: data.appUsages.map((usage) => PieChartSectionData(
                  color: usage.color, value: usage.durationMinutes.toDouble(),
                  title: '${usage.durationMinutes}m', radius: 64,
                  titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                )).toList(),
              ))),
              const SizedBox(height: 22),
              Wrap(spacing: 12, runSpacing: 12, children: data.appUsages.map((usage) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: usage.color.withOpacity(0.10), borderRadius: BorderRadius.circular(18), border: Border.all(color: usage.color.withOpacity(0.18))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: usage.color, shape: BoxShape.circle)),
                  const SizedBox(width: 7),
                  Text(usage.appName, style: TextStyle(fontWeight: FontWeight.w700, color: usage.color)),
                ]),
              )).toList()),
            ])),

            const SizedBox(height: 18),

            _GlassCard(child: Row(children: [
              const _IconBubble(icon: Icons.psychology_alt_rounded, color: Color(0xFF7C3AED)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("OpenClaw Insight", style: TextStyle(fontWeight: FontWeight.w900, color: primaryText, fontSize: 17)),
                const SizedBox(height: 6),
                Text(data.emotionalNudge, style: TextStyle(color: secondaryText, height: 1.35)),
              ])),
            ])),

            const SizedBox(height: 18),

            if (!kReleaseMode && state.usageDebugMessages.isNotEmpty) _GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Debug: Raw Usage Data", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
              const SizedBox(height: 10),
              ...state.usageDebugMessages.take(6).map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(msg, style: TextStyle(fontSize: 12, color: secondaryText)),
              )),
              if (state.usageDebugMessages.length > 6)
                Text('More debug lines available in logs.', style: TextStyle(fontSize: 12, color: secondaryText.withOpacity(0.8))),
            ])),

            if (!kReleaseMode && state.usageDebugMessages.isNotEmpty) const SizedBox(height: 18),

            _GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("AI Focus Recommendations", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: primaryText)),
              const SizedBox(height: 14),
              const _RecTile(icon: Icons.lock_clock_rounded, title: "Lock distraction apps", subtitle: "Block Instagram & YouTube during study time.", color: Color(0xFFEF4444)),
              const _RecTile(icon: Icons.timer_rounded, title: "Try a 45-minute focus sprint", subtitle: "Best time suggested: 9:00 AM - 10:00 AM.", color: Color(0xFF2563EB)),
              const _RecTile(icon: Icons.emoji_events_rounded, title: "Reward after completion", subtitle: "Use entertainment only after your tasks.", color: Color(0xFFF97316)),
            ])),          ],

          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A).withOpacity(0.94) : Colors.white.withOpacity(0.84),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.9)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.12 : 0.06), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: child,
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color color;
  const _MiniStat({required this.icon, required this.title, required this.subtitle, required this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _GlassCard(child: Column(children: [
      _IconBubble(icon: icon, color: color),
      const SizedBox(height: 8),
      Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.colorScheme.onSurface)),
      Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
    ]));
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon; final Color color;
  const _IconBubble({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(height: 48, width: 48,
      decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(18)),
      child: Icon(icon, color: color));
  }
}

class _RecTile extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color color;
  const _RecTile({required this.icon, required this.title, required this.subtitle, required this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [
      _IconBubble(icon: icon, color: color),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
        Text(subtitle, style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
      ])),
    ]));
  }
}