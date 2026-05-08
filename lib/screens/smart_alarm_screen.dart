import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state_provider.dart';
import '../models/alarm_model.dart';
import '../widgets/theme_toggle_widget.dart';
import 'dart:async';
class SmartAlarmScreen extends StatefulWidget {
  const SmartAlarmScreen({super.key});

  @override
  State<SmartAlarmScreen> createState() => _SmartAlarmScreenState();
}

class _SmartAlarmScreenState extends State<SmartAlarmScreen> {
  Timer? _autoTrafficTimer;

  @override
  void initState() {
    super.initState();

    // Runs once shortly after screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppStateProvider>().autoCheckTrafficIfDue(context);
    });

    // Then checks every 1 minute while Smart Alarm screen is open.
    _autoTrafficTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;
        context.read<AppStateProvider>().autoCheckTrafficIfDue(context);
      },
    );
  }

  @override
  void dispose() {
    _autoTrafficTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppStateProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final surfaceText = theme.colorScheme.onSurface;
    final secondaryText = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text("Smart Alarm", style: TextStyle(color: surfaceText, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: const [ThemeToggleWidget()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAlarmDialog(context),
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add_alarm_rounded, color: Colors.white),
        label: const Text("New Alarm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: state.alarms.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm_off_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text("No alarms yet", style: TextStyle(fontSize: 18, color: secondaryText)),
                  const SizedBox(height: 8),
                  Text("Tap + to create your first smart alarm", style: TextStyle(color: secondaryText.withOpacity(0.8))),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  // Active alarm hero card
                  if (state.activeAlarm != null) _ActiveAlarmHero(alarm: state.activeAlarm!),
                  const SizedBox(height: 14),

                  // Action buttons row
                  if (state.activeAlarm != null) ...[
                    Row(children: [
                      Expanded(child: _ActionBtn(icon: Icons.traffic_rounded, label: "Check Traffic", color: const Color(0xFFF97316),
                        isLoading: state.isCheckingTraffic,
                        onTap: () => state.checkTrafficAndReschedule(context))),
                      const SizedBox(width: 10),
                      Expanded(child: _ActionBtn(icon: Icons.notifications_rounded, label: "Test Alarm", color: const Color(0xFF7C3AED),
                        onTap: () => state.testAlarmIn5Seconds())),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // Alarm details card
                  if (state.activeAlarm != null) _AlarmDetailsCard(alarm: state.activeAlarm!),
                  const SizedBox(height: 14),

                  // Notification preview
                  if (state.notificationMessage.isNotEmpty)
                    _GlassCard(child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF7C3AED)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("Notification Preview", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black45)),
                        const SizedBox(height: 4),
                        Text(state.notificationMessage, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ])),
                    ])),

                  const SizedBox(height: 14),

                  // All alarms list
                  if (state.alarms.length > 1) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("All Alarms", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ...state.alarms.map((a) => _AlarmListTile(
                    alarm: a,
                    isActive: a.id == state.activeAlarm?.id,
                    onTap: () => state.setActiveAlarm(a.id),
                    onToggle: () => state.toggleAlarm(a.id),
                    onDelete: () => state.deleteAlarm(a.id),
                    onEdit: () => _showEditAlarmDialog(context, a),
                  )),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  void _showCreateAlarmDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    TimeOfDay wakeTime = const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay arrivalTime = const TimeOfDay(hour: 9, minute: 0);
    TransportMode mode = TransportMode.car;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 24, left: 20, right: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text("Create Smart Alarm", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: "Alarm Title",
                hintText: "e.g. Morning Alarm",
                prefixIcon: const Icon(Icons.title),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: isDark ? const Color(0xFF111827).withOpacity(0.9) : const Color(0xFFF4F7FF),
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: destCtrl,
              decoration: InputDecoration(
                labelText: "Destination",
                hintText: "e.g. College, Office...",
                prefixIcon: const Icon(Icons.location_on_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: isDark ? const Color(0xFF111827).withOpacity(0.9) : const Color(0xFFF4F7FF),
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _TimePickerTile(label: "Wake-up", time: wakeTime, onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: wakeTime);
                if (t != null) setModalState(() => wakeTime = t);
              })),
              const SizedBox(width: 12),
              Expanded(child: _TimePickerTile(label: "Arrival", time: arrivalTime, onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: arrivalTime);
                if (t != null) setModalState(() => arrivalTime = t);
              })),
            ]),
            const SizedBox(height: 14),
            const Align(alignment: Alignment.centerLeft, child: Text("Transport Mode", style: TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            Row(children: TransportMode.values.map((m) {
              final selected = m == mode;
              return Expanded(child: GestureDetector(
                onTap: () => setModalState(() => mode = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF2563EB) : const Color(0xFFF4F7FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? const Color(0xFF2563EB) : Colors.black12),
                  ),
                  child: Column(children: [
                    Text(m.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(m.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.black54)),
                  ]),
                ),
              ));
            }).toList()),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () async {
                final tomorrow = DateTime.now().add(const Duration(days: 1));
                final alarm = AlarmModel(
  id: 'alarm_${DateTime.now().millisecondsSinceEpoch}',
  title: titleCtrl.text.trim().isEmpty ? 'Alarm' : titleCtrl.text.trim(),
  origin: 'Whitefield, Bengaluru',
  destination: destCtrl.text.trim().isEmpty ? 'MG Road, Bengaluru' : destCtrl.text.trim(),
                  transportMode: mode,
                  originalWakeTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, wakeTime.hour, wakeTime.minute),
                  arrivalTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, arrivalTime.hour, arrivalTime.minute),
                );
                await context.read<AppStateProvider>().createAlarm(alarm);
                Navigator.pop(ctx);
              },
              child: const Text("Create Alarm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            )),
            const SizedBox(height: 10),
          ])),
        );
      }),
    );
  }

  void _showEditAlarmDialog(BuildContext context, AlarmModel alarm) {
    final titleCtrl = TextEditingController(text: alarm.title);
    final destCtrl = TextEditingController(text: alarm.destination);
    TimeOfDay wakeTime = TimeOfDay(hour: alarm.originalWakeTime.hour, minute: alarm.originalWakeTime.minute);
    TimeOfDay arrivalTime = TimeOfDay(hour: alarm.arrivalTime.hour, minute: alarm.arrivalTime.minute);
    TransportMode mode = alarm.transportMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 24, left: 20, right: 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text("Edit Alarm", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: "Alarm Title", prefixIcon: const Icon(Icons.title), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: const Color(0xFFF4F7FF))),
            const SizedBox(height: 14),
            TextField(controller: destCtrl, decoration: InputDecoration(labelText: "Destination", prefixIcon: const Icon(Icons.location_on_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: const Color(0xFFF4F7FF))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _TimePickerTile(label: "Wake-up", time: wakeTime, onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: wakeTime);
                if (t != null) setModalState(() => wakeTime = t);
              })),
              const SizedBox(width: 12),
              Expanded(child: _TimePickerTile(label: "Arrival", time: arrivalTime, onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: arrivalTime);
                if (t != null) setModalState(() => arrivalTime = t);
              })),
            ]),
            const SizedBox(height: 14),
            Row(children: TransportMode.values.map((m) {
              final selected = m == mode;
              return Expanded(child: GestureDetector(
                onTap: () => setModalState(() => mode = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF2563EB) : const Color(0xFFF4F7FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? const Color(0xFF2563EB) : Colors.black12),
                  ),
                  child: Column(children: [
                    Text(m.icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 4),
                    Text(m.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.black54)),
                  ]),
                ),
              ));
            }).toList()),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: () async {
                final tomorrow = DateTime.now().add(const Duration(days: 1));
                final updatedAlarm = AlarmModel(
  id: alarm.id,
  title: titleCtrl.text.trim().isEmpty ? 'Alarm' : titleCtrl.text.trim(),
  origin: alarm.origin,
  destination: destCtrl.text.trim().isEmpty ? 'MG Road, Bengaluru' : destCtrl.text.trim(),
                  transportMode: mode,
                  originalWakeTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, wakeTime.hour, wakeTime.minute),
                  arrivalTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, arrivalTime.hour, arrivalTime.minute),
                  aiUpdatedWakeTime: null,
                  trafficDelayMinutes: 0,
                  reason: '',
                  createdAt: alarm.createdAt,
                );
                await context.read<AppStateProvider>().updateAlarm(updatedAlarm);
                Navigator.pop(ctx);
              },
              child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            )),
            const SizedBox(height: 10),
          ])),
        );
      }),
    );
  }
}

// ── Widgets ──

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimePickerTile({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827).withOpacity(0.92) : const Color(0xFFF4F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        ),
        child: Row(children: [
          const Icon(Icons.access_time_rounded, size: 20, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black45, fontWeight: FontWeight.w600)),
            Text(time.format(context), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
        ]),
      ),
    );
  }
}

class _ActiveAlarmHero extends StatelessWidget {
  final AlarmModel alarm;
  const _ActiveAlarmHero({required this.alarm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF7C3AED)]),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.28), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Icon(Icons.alarm_rounded, size: 48, color: Colors.white),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
            child: Text("${alarm.transportMode.icon} ${alarm.transportMode.label}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(alarm.trafficDelayMinutes > 0 ? "AI adjusted your wake-up time" : "Your wake-up alarm", style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(DateFormat.jm().format(alarm.activeTime), style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
          child: Text("Original: ${DateFormat.jm().format(alarm.originalWakeTime)}  •  📍 ${alarm.destination}", style: const TextStyle(color: Colors.white)),
        ),
      ]),
    );
  }
}

class _AlarmDetailsCard extends StatelessWidget {
  final AlarmModel alarm;
  const _AlarmDetailsCard({required this.alarm});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Alarm Details", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      _DetailRow(icon: Icons.title, label: "Title", value: alarm.title, color: const Color(0xFF2563EB)),
      _DetailRow(icon: Icons.schedule_rounded, label: "Original Wake Time", value: DateFormat.jm().format(alarm.originalWakeTime), color: const Color(0xFF2563EB)),
      if (alarm.aiUpdatedWakeTime != null)
        _DetailRow(icon: Icons.auto_awesome_rounded, label: "AI Updated Wake Time", value: DateFormat.jm().format(alarm.aiUpdatedWakeTime!), color: const Color(0xFF7C3AED)),
      _DetailRow(icon: Icons.location_on_rounded, label: "Destination", value: alarm.destination, color: const Color(0xFF16A34A)),
      _DetailRow(icon: Icons.flag_rounded, label: "Arrival Time", value: DateFormat.jm().format(alarm.arrivalTime), color: const Color(0xFFF97316)),
      _DetailRow(icon: Icons.traffic_rounded, label: "Traffic Delay", value: "${alarm.trafficDelayMinutes} min", color: const Color(0xFFEF4444)),
      _DetailRow(icon: Icons.directions_rounded, label: "Transport", value: "${alarm.transportMode.icon} ${alarm.transportMode.label}", color: const Color(0xFF0EA5E9)),
      if (alarm.recommendedLeaveTime != null)
        _DetailRow(icon: Icons.departure_board_rounded, label: "Recommended Leave Time", value: DateFormat.jm().format(alarm.recommendedLeaveTime!), color: const Color(0xFF8B5CF6)),
      if (alarm.reason.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFEEF0), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.redAccent.withOpacity(0.2))),
          child: Row(children: [
            const Icon(Icons.info_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Expanded(child: Text(alarm.reason, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600, fontSize: 13))),
          ]),
        ),
      ],
    ]));
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color;
  const _DetailRow({required this.icon, required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
      Container(height: 36, width: 36, decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 13))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    ]));
  }
}

class _AlarmListTile extends StatelessWidget {
  final AlarmModel alarm; final bool isActive; final VoidCallback onTap; final VoidCallback onToggle; final VoidCallback onDelete; final VoidCallback onEdit;
  const _AlarmListTile({required this.alarm, required this.isActive, required this.onTap, required this.onToggle, required this.onDelete, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEDE9FE) : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? const Color(0xFF7C3AED).withOpacity(0.3) : Colors.white),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alarm.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: alarm.isEnabled ? const Color(0xFF111827) : Colors.black38)),
            Text(DateFormat.jm().format(alarm.activeTime), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: alarm.isEnabled ? const Color(0xFF111827) : Colors.black38)),
            Text("📍 ${alarm.destination}  •  ${alarm.transportMode.icon}", style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          const Spacer(),
          IconButton(icon: const Icon(Icons.edit_rounded, size: 20), color: const Color(0xFF2563EB), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete_rounded, size: 20), color: const Color(0xFFEF4444), onPressed: onDelete),
          Switch(value: alarm.isEnabled, onChanged: (_) => onToggle(), activeThumbColor: const Color(0xFF2563EB)),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap; final bool isLoading;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap, this.isLoading = false});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.82), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 12))]),
      child: child,
    );
  }
}