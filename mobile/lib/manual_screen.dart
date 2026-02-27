import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'export_service.dart';
import 'models.dart';

/// Manual distribution screen — browse participants, search, filter, and
/// distribute items inline without NFC hardware.
class ManualScreen extends StatefulWidget {
  final ApiService api;

  const ManualScreen({super.key, required this.api});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  // Data
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _individuals = [];
  bool _loading = false;
  String? _error;

  // Filters
  int _filterIndex = 0; // 0=All, 1=Teams, 2=Solo
  static const _filters = ['all', 'team', 'solo'];
  static const _filterLabels = ['All', 'Teams', 'Solo'];

  // Expanded teams
  final Set<String> _expandedTeams = {};

  // Item loading state (key: "uid_item")
  final Set<String> _distributingItems = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final filter = _filters[_filterIndex];
    final search = _searchController.text.trim();

    // Fetch team-grouped view for Teams/All, individual for Solo
    final viewMode = _filterIndex == 2 ? 'individual' : 'team';

    final result = await widget.api.getAttendees(
      search: search.isNotEmpty ? search : null,
      filter: filter,
      view: viewMode,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _loading = false;
        _error = 'Failed to load data. Check server connection.';
      });
      return;
    }

    if (viewMode == 'team') {
      final teams = (result['teams'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _teams = teams;
        _individuals = [];
        _loading = false;
      });
    } else {
      final attendees =
          (result['attendees'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _individuals = attendees;
        _teams = [];
        _loading = false;
      });
    }
  }

  Future<void> _distributeItem(
      String uid, String itemKey, String label,
      Future<DistributionResponse> Function(String) action) async {
    final loadingKey = '${uid}_$itemKey';
    setState(() => _distributingItems.add(loadingKey));

    final response = await action(uid);

    if (!mounted) return;
    setState(() => _distributingItems.remove(loadingKey));

    if (response.isSuccess) {
      _showToast('✓ $label given');
      _fetchData(); // refresh
    } else {
      _showToast(response.message, isError: true);
    }
  }

  Future<void> _bulkDistribute(String teamId, String teamName) async {
    // Show item picker
    final items = [
      ('registration', 'Registration'),
      ('breakfast', 'Breakfast'),
      ('lunch', 'Lunch'),
      ('snacks', 'Snacks'),
      ('dinner', 'Dinner'),
      ('midnight_snacks', 'Midnight Snacks'),
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribute to $teamName',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text('Select an item to distribute:',
                style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13)),
            const SizedBox(height: 16),
            ...items.map((item) => ListTile(
                  leading: Text(_itemEmoji(item.$1), style: const TextStyle(fontSize: 22)),
                  title: Text(item.$2,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx, item.$1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                )),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() => _loading = true);
    final result = await widget.api.distributeToTeam(teamId, selected);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.status == 'success') {
      _showToast('✓ ${result.message}');
      _fetchData();
    } else {
      _showToast(result.message, isError: true);
    }
  }

  String _itemEmoji(String key) {
    switch (key) {
      case 'registration':
        return '🎁';
      case 'breakfast':
        return '☕';
      case 'lunch':
        return '🍱';
      case 'snacks':
        return '🍿';
      case 'dinner':
        return '🍽️';
      case 'midnight_snacks':
        return '🌙';
      default:
        return '📦';
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1C1C1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError ? const Color(0xFFFF5252) : const Color(0xFF00E676),
            width: 2,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fixed header: search + filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Manual Distribution',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share, color: Color(0xFF00E676)),
                    tooltip: 'Export Data',
                    onPressed: _showExportDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name, UID, or team...',
                  hintStyle: const TextStyle(color: Color(0xFF666666)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFB0B0B0)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFFB0B0B0), size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _fetchData();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1C1C1C),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00E676)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Filter chips
              Row(
                children: List.generate(3, (i) {
                  final active = _filterIndex == i;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : 4,
                        right: i == 2 ? 0 : 4,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          if (_filterIndex != i) {
                            setState(() => _filterIndex = i);
                            _fetchData();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFF00E676)
                                : const Color(0xFF1C1C1C),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFF2E2E2E),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _filterLabels[i],
                              style: TextStyle(
                                color: active ? Colors.black : const Color(0xFFB0B0B0),
                                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        // Results
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E676)))
              : _error != null
                  ? _buildError()
                  : RefreshIndicator(
                      color: const Color(0xFF00E676),
                      backgroundColor: const Color(0xFF1C1C1C),
                      onRefresh: _fetchData,
                      child: _buildResults(),
                    ),
        ),
      ],
    );
  }

  Future<void> _showExportDialog() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Export Data',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Color(0xFF00E676)),
              title: const Text('Excel (.xlsx)', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Multi-sheet formatted report', style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'xlsx'),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt, color: Color(0xFF00E676)),
              title: const Text('CSV (.csv)', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Raw data', style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
          ],
        ),
      ),
    );

    if (format == null || !mounted) return;

    setState(() => _loading = true);

    try {
      // Fetch ALL participants for export
      final result = await widget.api.getAttendees(view: 'individual');
      if (result == null || !mounted) throw Exception('Failed to fetch data');
      
      final attendees = (result['attendees'] as List).cast<Map<String, dynamic>>();
      
      if (format == 'xlsx') {
        await ExportService.exportToExcel(attendees);
      } else {
        await ExportService.exportToCsv(attendees);
      }
      if (mounted) _showToast('✓ Export generated successfully');
    } catch (e) {
      if (mounted) _showToast('Export failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFB0B0B0))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_filterIndex == 2) {
      // Solo — individual flat list
      return _buildIndividualList();
    } else {
      // All or Teams — team grouped view
      return _buildTeamList();
    }
  }

  // ─── Team Grouped View ───────────────────────────

  Widget _buildTeamList() {
    if (_teams.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _teams.length,
      itemBuilder: (context, i) => _buildTeamCard(_teams[i]),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team) {
    final teamId = team['team_id']?.toString();
    final name = team['team_name'] ?? 'Unknown';
    final color = _parseColor(team['team_color']);
    final members = (team['members'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final count = team['member_count'] ?? members.length;
    final isSoloGroup = teamId == null || teamId == 'null';
    final isExpanded = _expandedTeams.contains(teamId ?? 'solo');

    // Calculate progress
    int total = 0;
    int collected = 0;
    for (final m in members) {
      total += 6;
      collected += _countCollected(m);
    }
    final progress = total > 0 ? collected / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpanded
              ? color.withValues(alpha: 0.4)
              : const Color(0xFF2E2E2E),
        ),
      ),
      child: Column(
        children: [
          // Header (tappable)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() {
                final key = teamId ?? 'solo';
                if (isExpanded) {
                  _expandedTeams.remove(key);
                } else {
                  _expandedTeams.add(key);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Color dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        const SizedBox(height: 4),
                        // Progress bar
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: const Color(0xFF2E2E2E),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(color),
                                  minHeight: 5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$collected/$total items',
                              style: const TextStyle(
                                  color: Color(0xFFB0B0B0), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$count',
                      style:
                          const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12)),
                  const SizedBox(width: 2),
                  const Icon(Icons.person, color: Color(0xFFB0B0B0), size: 14),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFFB0B0B0),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded members
          if (isExpanded) ...[
            const Divider(color: Color(0xFF2E2E2E), height: 1),
            ...members.map((m) => _buildMemberRow(m)),
            // Bulk distribute for real teams
            if (!isSoloGroup)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _bulkDistribute(teamId, name),
                    icon: const Icon(Icons.group_add, size: 16),
                    label: const Text('Distribute to All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> member) {
    final name = member['name'] ?? '';
    final uid = member['uid'] ?? '';
    final collected = _countCollected(member);
    final items = _buildItemList(member);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + UID + progress
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    const Color(0xFF00E676).withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text(uid,
                        style: const TextStyle(
                            color: Color(0xFF666666),
                            fontFamily: 'monospace',
                            fontSize: 10)),
                  ],
                ),
              ),
              Text('$collected/6',
                  style: TextStyle(
                    color: collected >= 6
                        ? const Color(0xFF00E676)
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  )),
            ],
          ),
          const SizedBox(height: 6),

          // Item chips row
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items.map((item) {
              final isCollected = item['collected'] == true;
              final loadingKey = '${uid}_${item['key']}';
              final isDistributing = _distributingItems.contains(loadingKey);

              return GestureDetector(
                onTap: isCollected || isDistributing
                    ? null
                    : () => _distributeItem(
                        uid, item['key'], item['label'], item['action']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCollected
                        ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
                        : const Color(0xFF2E2E2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCollected
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF3E3E3E),
                    ),
                  ),
                  child: isDistributing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Color(0xFF00E676)),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item['emoji'],
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            if (isCollected)
                              const Icon(Icons.check,
                                  color: Color(0xFF00E676), size: 12)
                            else
                              const Text('GIVE',
                                  style: TextStyle(
                                    color: Color(0xFF00E676),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  )),
                          ],
                        ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Individual (Solo) View ──────────────────────

  Widget _buildIndividualList() {
    if (_individuals.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _individuals.length,
      itemBuilder: (context, i) => _buildIndividualCard(_individuals[i]),
    );
  }

  Widget _buildIndividualCard(Map<String, dynamic> p) {
    final name = p['name'] ?? '';
    final uid = p['uid'] ?? '';
    final college = p['college'] ?? '';
    final teamName = p['team_name'];
    final teamColor = _parseColor(p['team_color']);
    final collected = _countCollected(p);
    final items = _buildItemList(p);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    const Color(0xFF00E676).withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(college,
                        style: const TextStyle(
                            color: Color(0xFFB0B0B0), fontSize: 11)),
                    if (teamName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: teamColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(teamName,
                              style: TextStyle(
                                  color: teamColor, fontSize: 11)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Text('$collected/6',
                      style: TextStyle(
                        color: collected >= 6
                            ? const Color(0xFF00E676)
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      )),
                  const Text('items',
                      style:
                          TextStyle(color: Color(0xFFB0B0B0), fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // UID badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2E2E2E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              uid,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Color(0xFFB0B0B0)),
            ),
          ),
          const SizedBox(height: 10),
          // Item chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items.map((item) {
              final isCollected = item['collected'] == true;
              final loadingKey = '${uid}_${item['key']}';
              final isDistributing = _distributingItems.contains(loadingKey);

              return GestureDetector(
                onTap: isCollected || isDistributing
                    ? null
                    : () => _distributeItem(
                        uid, item['key'], item['label'], item['action']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCollected
                        ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
                        : const Color(0xFF2E2E2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCollected
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF3E3E3E),
                    ),
                  ),
                  child: isDistributing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Color(0xFF00E676)),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(item['emoji'],
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              item['label'],
                              style: TextStyle(
                                color: isCollected
                                    ? const Color(0xFF00E676)
                                    : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (isCollected)
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF00E676), size: 14)
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('GIVE',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    )),
                              ),
                          ],
                        ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(Icons.search_off,
                  size: 56,
                  color: const Color(0xFF00E676).withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                _searchController.text.isNotEmpty
                    ? 'No results for "${_searchController.text}"'
                    : 'No participants found',
                style:
                    const TextStyle(color: Color(0xFFB0B0B0), fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _countCollected(Map<String, dynamic> m) {
    int c = 0;
    if (m['registration_goodies'] == true) c++;
    if (m['breakfast'] == true) c++;
    if (m['lunch'] == true) c++;
    if (m['snacks'] == true) c++;
    if (m['dinner'] == true) c++;
    if (m['midnight_snacks'] == true) c++;
    return c;
  }

  List<Map<String, dynamic>> _buildItemList(Map<String, dynamic> m) {
    return [
      {
        'key': 'registration',
        'label': 'Reg',
        'emoji': '🎁',
        'collected': m['registration_goodies'] == true,
        'action': widget.api.giveRegistration,
      },
      {
        'key': 'breakfast',
        'label': 'Breakfast',
        'emoji': '☕',
        'collected': m['breakfast'] == true,
        'action': widget.api.giveBreakfast,
      },
      {
        'key': 'lunch',
        'label': 'Lunch',
        'emoji': '🍱',
        'collected': m['lunch'] == true,
        'action': widget.api.giveLunch,
      },
      {
        'key': 'snacks',
        'label': 'Snacks',
        'emoji': '🍿',
        'collected': m['snacks'] == true,
        'action': widget.api.giveSnacks,
      },
      {
        'key': 'dinner',
        'label': 'Dinner',
        'emoji': '🍽️',
        'collected': m['dinner'] == true,
        'action': widget.api.giveDinner,
      },
      {
        'key': 'midnight',
        'label': 'Midnight',
        'emoji': '🌙',
        'collected': m['midnight_snacks'] == true,
        'action': widget.api.giveMidnightSnacks,
      },
    ];
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFFB0B0B0);
    try {
      return Color(
          int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000);
    } catch (_) {
      return const Color(0xFFB0B0B0);
    }
  }
}
