import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alarm_model.dart';
import '../models/user_profile_model.dart';
import '../providers/app_state_provider.dart';
import '../main.dart';
import '../widgets/theme_toggle_widget.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String userType = 'Student';
  TransportMode transportMode = TransportMode.car;

  final sourceCtrl = TextEditingController();
  final destinationCtrl = TextEditingController();
  final routineCtrl = TextEditingController();

  TimeOfDay wakeTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay arrivalTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    sourceCtrl.dispose();
    destinationCtrl.dispose();
    routineCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (sourceCtrl.text.trim().isEmpty ||
        destinationCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both source and destination.'),
        ),
      );
      return;
    }

    final profile = UserProfileModel(
      userType: userType,
      sourceAddress: sourceCtrl.text.trim(),
      destinationAddress: destinationCtrl.text.trim(),
      transportMode: transportMode,
      wakeTime: wakeTime,
      arrivalTime: arrivalTime,
      dailyRoutine: routineCtrl.text.trim(),
    );

    await context.read<AppStateProvider>().saveUserProfile(profile);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const MainNavigationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: const [ThemeToggleWidget()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              const Text(
                'Setup TimePilot AI',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Tell us your daily routine once. TimePilot will remember it and use it for smart alarms and traffic checks.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 28),

              _SectionCard(
                title: 'I am a',
                child: Row(
                  children: [
                    Expanded(
                      child: _ChoiceChipBox(
                        title: 'Student',
                        icon: Icons.school_rounded,
                        selected: userType == 'Student',
                        onTap: () => setState(() => userType = 'Student'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ChoiceChipBox(
                        title: 'Employee',
                        icon: Icons.work_rounded,
                        selected: userType == 'Employee',
                        onTap: () => setState(() => userType = 'Employee'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _SectionCard(
                title: 'Daily travel route',
                child: Column(
                  children: [
                    _InputField(
                      controller: sourceCtrl,
                      label: 'Source address',
                      hint: 'e.g. Hostel, Whitefield, Bengaluru',
                      icon: Icons.my_location_rounded,
                    ),
                    const SizedBox(height: 14),
                    _InputField(
                      controller: destinationCtrl,
                      label: userType == 'Student'
                          ? 'College address'
                          : 'Office address',
                      hint: userType == 'Student'
                          ? 'e.g. College, MG Road, Bengaluru'
                          : 'e.g. Office, Indiranagar, Bengaluru',
                      icon: Icons.location_on_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _SectionCard(
                title: 'Transport mode',
                child: Row(
                  children: TransportMode.values.map((mode) {
                    final selected = transportMode == mode;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => transportMode = mode),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFF4F7FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF2563EB)
                                  : Colors.black12,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                mode.icon,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mode.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: selected
                                      ? Colors.white
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 18),

              _SectionCard(
                title: 'Daily timing',
                child: Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        label: 'Wake-up',
                        time: wakeTime,
                        onTap: () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: wakeTime,
                          );
                          if (selected != null) {
                            setState(() => wakeTime = selected);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeTile(
                        label: 'Arrival',
                        time: arrivalTime,
                        onTap: () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: arrivalTime,
                          );
                          if (selected != null) {
                            setState(() => arrivalTime = selected);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              _SectionCard(
                title: 'Daily routine',
                child: _InputField(
                  controller: routineCtrl,
                  label: 'Routine notes',
                  hint: userType == 'Student'
                      ? 'e.g. College 9-4, gym 6 PM, study DBMS at 9 PM'
                      : 'e.g. Office 9-6, meeting at 10 AM, focus block 8 PM',
                  icon: Icons.event_note_rounded,
                  maxLines: 3,
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text(
                    'Save & Start TimePilot',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ChoiceChipBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChipBox({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFF4F7FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : Colors.black12,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF2563EB),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF4F7FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.access_time_rounded,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}