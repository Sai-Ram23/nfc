import 'package:flutter/material.dart';
import 'api_service.dart';
import 'models.dart';

/// Dashboard screen showing real-time event statistics and team leaderboard.
class DashboardScreen extends StatefulWidget {
  final ApiService api;

  const DashboardScreen({super.key, required this.api});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  Map<String, dynamic>? _teamStats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      widget.api.getDashboardStats(),
      widget.api.getTeamsStats(),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = results[0] as DashboardStats?;
      _teamStats = results[1] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }

    if (_stats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Color(0xFFB0B0B0)),
            const SizedBox(height: 12),
            const Text('Could not load stats', style: TextStyle(color: Color(0xFFB0B0B0))),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _fetchData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final s = _stats!;

    return RefreshIndicator(
      color: const Color(0xFF00E676),
      backgroundColor: const Color(0xFF1C1C1C),
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // Header
          const Text(
            'Event Overview',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),

          // Quick stats row
          Row(
            children: [
              _StatCard(
                icon: Icons.people,
                label: 'Participants',
                value: '${s.totalParticipants}',
                color: const Color(0xFF00E676),
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.group_work,
                label: 'Teams',
                value: '${s.totalTeams}',
                color: const Color(0xFF76FF03),
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.person,
                label: 'Solo',
                value: '${s.soloParticipants}',
                color: const Color(0xFFB0B0B0),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Distribution Progress
          const Text(
            'Distribution Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),

          _DistributionRow(
            icon: '🎁',
            label: 'Registration',
            given: s.registrationGiven,
            total: s.totalParticipants,
          ),
          _DistributionRow(
            icon: '☕',
            label: 'Breakfast',
            given: s.breakfastGiven,
            total: s.totalParticipants,
          ),
          _DistributionRow(
            icon: '🍱',
            label: 'Lunch',
            given: s.lunchGiven,
            total: s.totalParticipants,
          ),
          _DistributionRow(
            icon: '🍿',
            label: 'Snacks',
            given: s.snacksGiven,
            total: s.totalParticipants,
          ),
          _DistributionRow(
            icon: '🍽️',
            label: 'Dinner',
            given: s.dinnerGiven,
            total: s.totalParticipants,
          ),
          _DistributionRow(
            icon: '🌙',
            label: 'Midnight Snacks',
            given: s.midnightSnacksGiven,
            total: s.totalParticipants,
          ),

          const SizedBox(height: 24),

          // Team Leaderboard
          if (_teamStats != null && (_teamStats!['top_teams'] as List).isNotEmpty) ...[
            const Text(
              'Team Leaderboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ..._buildLeaderboard(),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _buildLeaderboard() {
    final topTeams = (_teamStats!['top_teams'] as List)
        .map((t) => t as Map<String, dynamic>)
        .toList();

    return List.generate(topTeams.length, (index) {
      final team = topTeams[index];
      final rate = (team['completion_rate'] as num).toDouble();
      final colorHex = (team['team_color'] as String? ?? '#00E676').replaceFirst('#', '');
      final teamColor = Color(int.parse('FF$colorHex', radix: 16));

      String medal = '';
      if (index == 0) medal = '🥇';
      if (index == 1) medal = '🥈';
      if (index == 2) medal = '🥉';

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: index == 0
                ? teamColor.withValues(alpha: 0.5)
                : const Color(0xFF2E2E2E),
          ),
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 32,
              child: Text(
                medal.isNotEmpty ? medal : '#${index + 1}',
                style: TextStyle(
                  fontSize: medal.isNotEmpty ? 20 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Team color dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: teamColor,
              ),
            ),
            const SizedBox(width: 10),
            // Team name + members
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team['team_name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${team['members']} members',
                    style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 11),
                  ),
                ],
              ),
            ),
            // Completion rate
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: rate >= 80
                        ? const Color(0xFF00E676)
                        : rate >= 50
                            ? const Color(0xFF76FF03)
                            : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: rate / 100,
                      backgroundColor: const Color(0xFF2E2E2E),
                      color: teamColor,
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Small stat card widget for the top row.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2E2E2E)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Distribution progress row with icon, label, fraction, and progress bar.
class _DistributionRow extends StatelessWidget {
  final String icon;
  final String label;
  final int given;
  final int total;

  const _DistributionRow({
    required this.icon,
    required this.label,
    required this.given,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? given / total : 0.0;
    final percent = (progress * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF2E2E2E),
                color: progress >= 1.0
                    ? const Color(0xFF00E676)
                    : const Color(0xFF76FF03),
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              '$given/$total ($percent%)',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: progress >= 1.0 ? const Color(0xFF00E676) : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
