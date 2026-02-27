import 'package:flutter/material.dart';
import 'api_service.dart';
import 'scan_screen.dart';
import 'dashboard_screen.dart';
import 'attendees_screen.dart';
import 'manual_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';


/// Main app shell with 5-tab bottom navigation bar.
class HomeShell extends StatefulWidget {
  final ApiService api;

  const HomeShell({super.key, required this.api});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      // Tab 0: Scan (existing screen)
      ScanScreen(api: widget.api),
      // Tab 1: Dashboard
      DashboardScreen(api: widget.api),
      // Tab 2: Attendees
      AttendeesScreen(api: widget.api),
      // Tab 3: Manual
      ManualScreen(api: widget.api),
      // Tab 4: Settings
      SettingsScreen(api: widget.api),
    ];
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _logout() async {
    await widget.api.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(api: widget.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/Trojan_Horse.png',
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 10),
            const Text(
              'BREACH GATE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          if (_currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Export feature coming soon")),
                );
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF2E2E2E), width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabTapped,
          backgroundColor: const Color(0xFF000000),
          indicatorColor: const Color(0xFF1B5E20).withValues(alpha: 0.5),
          surfaceTintColor: Colors.transparent,
          height: 70,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.nfc_outlined, color: Color(0xFFB0B0B0)),
              selectedIcon: Icon(Icons.nfc_rounded, color: Color(0xFF00E676)),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: Color(0xFFB0B0B0)),
              selectedIcon: Icon(Icons.dashboard, color: Color(0xFF00E676)),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline, color: Color(0xFFB0B0B0)),
              selectedIcon: Icon(Icons.people, color: Color(0xFF00E676)),
              label: 'Attendees',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_note_outlined, color: Color(0xFFB0B0B0)),
              selectedIcon: Icon(Icons.edit_note, color: Color(0xFF00E676)),
              label: 'Manual',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: Color(0xFFB0B0B0)),
              selectedIcon: Icon(Icons.settings, color: Color(0xFF00E676)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
