import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

class ThemeToggleWidget extends StatelessWidget {
  const ThemeToggleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final isDark = state.isDarkMode;

    return GestureDetector(
      onTap: () => state.toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        width: 56,
        height: 30,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isDark ? const Color(0xFF111827) : const Color(0xFFEFF6FF),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFD0E2FF),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.28) : const Color(0xFF2563EB).withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF7C3AED) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDark ? Icons.nightlight_round : Icons.wb_sunny,
                  size: 14,
                  color: isDark ? Colors.white : const Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
