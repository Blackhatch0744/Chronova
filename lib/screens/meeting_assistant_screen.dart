import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state_provider.dart';
import '../widgets/theme_toggle_widget.dart';

class MeetingAssistantScreen extends StatefulWidget {
  const MeetingAssistantScreen({super.key});
  @override
  State<MeetingAssistantScreen> createState() => _MeetingAssistantScreenState();
}

class _MeetingAssistantScreenState extends State<MeetingAssistantScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _timeCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = theme.colorScheme.onSurface;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;
    final fillColor = isDark ? const Color(0xFF111827).withOpacity(0.92) : const Color(0xFFF4F7FF);

    final state = context.watch<AppStateProvider>();
    final meeting = state.meetingBrief;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Meeting Assistant', style: TextStyle(fontWeight: FontWeight.w900, color: primaryText)),
        centerTitle: true, backgroundColor: Colors.transparent, elevation: 0,
        actions: const [ThemeToggleWidget()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Input section
          _GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Generate Meeting Brief", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(10)),
              child: const Text("Paste your email or meeting details below", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: "Meeting Title (optional)",
                hintText: "e.g. Project Review with Dr. Smith",
                prefixIcon: const Icon(Icons.title_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: fillColor,
                labelStyle: TextStyle(color: secondaryText),
                hintStyle: TextStyle(color: secondaryText.withOpacity(0.7)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _timeCtrl,
              decoration: InputDecoration(
                labelText: "Meeting Time (optional)",
                hintText: "e.g. 3:00 PM",
                prefixIcon: const Icon(Icons.access_time_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: fillColor,
                labelStyle: TextStyle(color: secondaryText),
                hintStyle: TextStyle(color: secondaryText.withOpacity(0.7)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _inputCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "Email / Meeting Text *",
                hintText: "Paste the email content or meeting description here...",
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: fillColor,
                labelStyle: TextStyle(color: secondaryText),
                hintStyle: TextStyle(color: secondaryText.withOpacity(0.7)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
              onPressed: state.isGeneratingBrief ? null : () {
                if (_inputCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text("Please paste some meeting text first."),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                  return;
                }
                state.generateMeetingBrief(
                  inputText: _inputCtrl.text.trim(),
                  title: _titleCtrl.text.trim(),
                  time: _timeCtrl.text.trim(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: state.isGeneratingBrief
                  ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 12),
                      Text("Generating Brief...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    ])
                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Text("Generate Meeting Brief", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    ]),
            )),
          ])),

          const SizedBox(height: 18),

          // No brief yet
          if (meeting == null && !state.isGeneratingBrief)
            Center(child: Column(children: [
              const SizedBox(height: 30),
              Icon(Icons.groups_rounded, size: 64, color: isDark ? Colors.white.withOpacity(0.20) : Colors.black.withOpacity(0.15)),
              const SizedBox(height: 12),
              Text("No brief generated yet", style: TextStyle(fontSize: 18, color: secondaryText.withOpacity(0.92), fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text("Paste your meeting email above to get started", style: TextStyle(color: secondaryText.withOpacity(0.66))),
            ])),

          // Brief results
          if (meeting != null) ...[
            // Hero card
            Container(
              width: double.infinity, padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF7C3AED)]),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.28), blurRadius: 28, offset: const Offset(0, 14))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.groups_rounded, color: Colors.white, size: 48),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                    child: Text("Prep: ${meeting.preparationScore}/100", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(meeting.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.15)),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.access_time_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(DateFormat.jm().format(meeting.time), style: const TextStyle(color: Colors.white)),
                  const SizedBox(width: 14),
                  const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(meeting.location, style: const TextStyle(color: Colors.white))),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                  child: const Text("AI Generated — Mock Data", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // Stats row
            Row(children: [
              Expanded(child: _MiniStat(icon: Icons.summarize_rounded, title: "AI", subtitle: "Brief ready", color: const Color(0xFF7C3AED))),
              const SizedBox(width: 12),
              Expanded(child: _MiniStat(icon: Icons.checklist_rounded, title: "${meeting.talkingPoints.length}", subtitle: "Talking pts", color: const Color(0xFF2563EB))),
              const SizedBox(width: 12),
              Expanded(child: _MiniStat(icon: Icons.quiz_rounded, title: "${meeting.questionsToExpect.length}", subtitle: "Questions", color: const Color(0xFF16A34A))),
            ]),

            const SizedBox(height: 14),

            // Summary
            _GlassCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _IconBubble(icon: Icons.auto_awesome_rounded, color: const Color(0xFF7C3AED)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("AI Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED))),
                const SizedBox(height: 8),
                Text(meeting.summary, style: const TextStyle(height: 1.45, color: Color(0xFF111827))),
              ])),
            ])),

            const SizedBox(height: 14),

            // Talking points
            _GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Key Talking Points", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryText)),
              const SizedBox(height: 14),
              ...meeting.talkingPoints.asMap().entries.map((entry) => _PointTile(index: entry.key + 1, text: entry.value, isQuestion: false)),
            ])),

            const SizedBox(height: 14),

            // Expected questions
            _GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _IconBubble(icon: Icons.quiz_rounded, color: const Color(0xFF16A34A)),
                const SizedBox(width: 12),
                Text("Questions You May Be Asked", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: primaryText)),
              ]),
              const SizedBox(height: 14),
              ...meeting.questionsToExpect.asMap().entries.map((entry) => _PointTile(index: entry.key + 1, text: entry.value, isQuestion: true)),
            ])),

            const SizedBox(height: 14),

            // Prep score card
            _GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Preparation Score", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: meeting.preparationScore / 100,
                    minHeight: 12,
                    backgroundColor: Colors.black.withOpacity(0.07),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      meeting.preparationScore > 75 ? const Color(0xFF16A34A) : meeting.preparationScore > 50 ? const Color(0xFFF97316) : const Color(0xFFEF4444),
                    ),
                  ),
                )),
                const SizedBox(width: 12),
                Text("${meeting.preparationScore}/100", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ]),
              const SizedBox(height: 8),
              Text(
                meeting.preparationScore > 75 ? "✅ You are well prepared for this meeting!" : meeting.preparationScore > 50 ? "⚠️ Review talking points before joining." : "❌ More preparation recommended.",
                style: TextStyle(color: meeting.preparationScore > 75 ? const Color(0xFF16A34A) : meeting.preparationScore > 50 ? const Color(0xFFF97316) : const Color(0xFFEF4444), fontWeight: FontWeight.w600),
              ),
            ])),
          ],

          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

class _PointTile extends StatelessWidget {
  final int index; final String text; final bool isQuestion;
  const _PointTile({required this.index, required this.text, required this.isQuestion});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = theme.colorScheme.onSurface;
    final colors = [const Color(0xFF2563EB), const Color(0xFF7C3AED), const Color(0xFF16A34A), const Color(0xFFF97316), const Color(0xFFEF4444)];
    final color = isQuestion ? const Color(0xFF16A34A) : colors[(index - 1) % colors.length];
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 28, width: 28, alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(9)),
        child: Text("$index", style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13))),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: TextStyle(height: 1.35, fontWeight: FontWeight.w600, color: primaryText))),
    ]));
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon; final String title, subtitle; final Color color;
  const _MiniStat({required this.icon, required this.title, required this.subtitle, required this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;
    return _GlassCard(child: Column(children: [
      _IconBubble(icon: icon, color: color),
      const SizedBox(height: 8),
      Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: primaryText)),
      Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: secondaryText)),
    ]));
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