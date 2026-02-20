import 'package:flutter/material.dart';

enum ResultType { success, duplicate, invalid, error }

/// Full-screen overlay showing result status.
/// Green for success, red for duplicate, orange for invalid/error.
/// Auto-dismisses after 2 seconds (handled by caller).
class ResultOverlay extends StatelessWidget {
  final ResultType type;
  final String message;

  const ResultOverlay({
    super.key,
    required this.type,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: config.gradientColors,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: config.gradientColors.first.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: Icon(
                config.icon,
                size: 72,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              config.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Tap to dismiss hint
            Text(
              'Tap to dismiss',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _ResultConfig _getConfig() {
    switch (type) {
      case ResultType.success:
        return _ResultConfig(
          title: 'Allowed',
          icon: Icons.check_circle_outline,
          gradientColors: [
            const Color(0xFF059669),
            const Color(0xFF10B981),
          ],
        );
      case ResultType.duplicate:
        return _ResultConfig(
          title: 'Already Collected',
          icon: Icons.block_outlined,
          gradientColors: [
            const Color(0xFFDC2626),
            const Color(0xFFEF4444),
          ],
        );
      case ResultType.invalid:
        return _ResultConfig(
          title: 'Invalid Tag',
          icon: Icons.error_outline,
          gradientColors: [
            const Color(0xFFD97706),
            const Color(0xFFF59E0B),
          ],
        );
      case ResultType.error:
        return _ResultConfig(
          title: 'Error',
          icon: Icons.warning_amber_rounded,
          gradientColors: [
            const Color(0xFF7C3AED),
            const Color(0xFF8B5CF6),
          ],
        );
    }
  }
}

class _ResultConfig {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;

  _ResultConfig({
    required this.title,
    required this.icon,
    required this.gradientColors,
  });
}
