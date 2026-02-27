import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'login_screen.dart';
import 'utils/time_manager.dart';

/// Settings screen with server config, event timing, app info, and logout.
class SettingsScreen extends StatefulWidget {
  final ApiService api;

  const SettingsScreen({super.key, required this.api});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverUrlController = TextEditingController();
  bool _urlSaved = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController.text = ApiService.baseUrl;
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  void _saveUrl() {
    final url = _serverUrlController.text.trim();
    if (url.isNotEmpty) {
      ApiService.setBaseUrl(url);
      setState(() => _urlSaved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _urlSaved = false);
      });
    }
  }

  Future<void> _changeEventDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: timeManager.eventStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E676),
              onPrimary: Colors.black,
              surface: Color(0xFF1C1C1C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      await timeManager.setEventStartDate(date);
      setState(() {});
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2E2E2E)),
        ),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Color(0xFFB0B0B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await widget.api.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Settings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 20),

        // Server Configuration
        const _SectionHeader(icon: Icons.dns_outlined, title: 'Server Configuration'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2E2E2E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _serverUrlController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Backend URL',
                  labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                  hintText: 'http://10.248.56.164:8000/api',
                  hintStyle: const TextStyle(color: Color(0xFF666666)),
                  prefixIcon: const Icon(Icons.link, color: Color(0xFFB0B0B0), size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF00E676)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveUrl,
                  icon: Icon(
                    _urlSaved ? Icons.check : Icons.save_outlined,
                    size: 18,
                  ),
                  label: Text(_urlSaved ? 'Saved!' : 'Save URL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _urlSaved
                        ? const Color(0xFF1B5E20)
                        : const Color(0xFF00E676),
                    foregroundColor: _urlSaved ? const Color(0xFF00E676) : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Event Timing
        const _SectionHeader(icon: Icons.schedule_outlined, title: 'Event Timing'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2E2E2E)),
          ),
          child: Column(
            children: [
              _SettingsRow(
                icon: Icons.calendar_today_outlined,
                title: 'Event Start Date',
                subtitle: DateFormat('EEEE, MMM dd, yyyy').format(timeManager.eventStartDate),
                trailing: TextButton(
                  onPressed: _changeEventDate,
                  child: const Text('Change', style: TextStyle(color: Color(0xFF00E676))),
                ),
              ),
              const Divider(color: Color(0xFF2E2E2E), height: 24),
              const _SettingsRow(
                icon: Icons.event_note_outlined,
                title: 'Day 1 Slots',
                subtitle: 'Registration, Breakfast, Lunch, Snacks',
                trailing: null,
              ),
              const Divider(color: Color(0xFF2E2E2E), height: 24),
              const _SettingsRow(
                icon: Icons.nightlight_outlined,
                title: 'Day 2 Slots',
                subtitle: 'Dinner, Midnight Snacks',
                trailing: null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // App Info
        const _SectionHeader(icon: Icons.info_outline, title: 'About'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2E2E2E)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/images/Trojan_Horse.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BREACH GATE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'NFC Distribution System',
                          style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'v1.0.0',
                    style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF2E2E2E), height: 24),
              const Row(
                children: [
                  Icon(Icons.security, size: 16, color: Color(0xFFB0B0B0)),
                  SizedBox(width: 8),
                  Text(
                    'Siege of Troy — Breach Point',
                    style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.school_outlined, size: 16, color: Color(0xFFB0B0B0)),
                  SizedBox(width: 8),
                  Text(
                    'Malla Reddy University',
                    style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Logout
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Color(0xFFFF5252), size: 20),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                color: Color(0xFFFF5252),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00E676)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF00E676),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFB0B0B0)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12)),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
