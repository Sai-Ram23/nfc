import 'package:flutter/material.dart';
import 'dart:async';
import 'api_service.dart';

/// Attendees screen with search, filter chips, and individual/team view toggle.
class AttendeesScreen extends StatefulWidget {
  final ApiService api;

  const AttendeesScreen({super.key, required this.api});

  @override
  State<AttendeesScreen> createState() => _AttendeesScreenState();
}

class _AttendeesScreenState extends State<AttendeesScreen> {
  final _searchController = TextEditingController();
  String _view = 'individual'; // 'individual' or 'team'
  String _filter = ''; // '', 'collected_all', 'missing_items'
  Map<String, dynamic>? _data;
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchAttendees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchAttendees();
    });
  }

  Future<void> _fetchAttendees() async {
    setState(() => _loading = true);
    final result = await widget.api.getAttendees(
      search: _searchController.text.trim(),
      filter: _filter.isNotEmpty ? _filter : null,
      view: _view,
    );
    if (!mounted) return;
    setState(() {
      _data = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name, UID, or team...',
              hintStyle: const TextStyle(color: Color(0xFF666666)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFB0B0B0)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Color(0xFFB0B0B0), size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _fetchAttendees();
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
        ),

        const SizedBox(height: 10),

        // View toggle + Filter chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // View toggle
              _ViewToggle(
                value: _view,
                onChanged: (v) {
                  setState(() => _view = v);
                  _fetchAttendees();
                },
              ),
              const SizedBox(width: 10),
              // Filter chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filter.isEmpty,
                        onTap: () {
                          setState(() => _filter = '');
                          _fetchAttendees();
                        },
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Complete',
                        selected: _filter == 'collected_all',
                        onTap: () {
                          setState(() => _filter = 'collected_all');
                          _fetchAttendees();
                        },
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Missing',
                        selected: _filter == 'missing_items',
                        onTap: () {
                          setState(() => _filter = 'missing_items');
                          _fetchAttendees();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Results
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
              : _data == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 40, color: Color(0xFFB0B0B0)),
                          const SizedBox(height: 8),
                          const Text('Could not load attendees', style: TextStyle(color: Color(0xFFB0B0B0))),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _fetchAttendees, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF00E676),
                      backgroundColor: const Color(0xFF1C1C1C),
                      onRefresh: _fetchAttendees,
                      child: _view == 'individual'
                          ? _buildIndividualList()
                          : _buildTeamList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildIndividualList() {
    final attendees = (_data!['attendees'] as List?) ?? [];
    final total = _data!['total'] ?? attendees.length;

    if (attendees.isEmpty) {
      return _buildEmptyState('No attendees found');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$total attendee${total == 1 ? '' : 's'}',
                style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: attendees.length,
            itemBuilder: (_, index) {
              final a = attendees[index] as Map<String, dynamic>;
              return _AttendeeCard(data: a);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeamList() {
    final teams = (_data!['teams'] as List?) ?? [];
    final solo = (_data!['solo_participants'] as List?) ?? [];

    if (teams.isEmpty && solo.isEmpty) {
      return _buildEmptyState('No teams or solo attendees found');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (teams.isNotEmpty) ...[
          Text(
            '${teams.length} team${teams.length == 1 ? '' : 's'}',
            style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...teams.map((t) => _TeamGroupCard(data: t as Map<String, dynamic>)),
        ],
        if (solo.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${solo.length} solo attendee${solo.length == 1 ? '' : 's'}',
            style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...solo.map((s) => _AttendeeCard(data: s as Map<String, dynamic>)),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: Color(0xFF2E2E2E)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xFFB0B0B0))),
        ],
      ),
    );
  }
}

// --- Sub-widgets ---

class _ViewToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ViewToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggle('individual', Icons.person, 'List'),
          _toggle('team', Icons.group, 'Teams'),
        ],
      ),
    );
  }

  Widget _toggle(String val, IconData icon, String label) {
    final selected = value == val;
    return GestureDetector(
      onTap: () => onChanged(val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00E676).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? const Color(0xFF00E676) : const Color(0xFFB0B0B0)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? const Color(0xFF00E676) : const Color(0xFFB0B0B0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B5E20) : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF00E676) : const Color(0xFF2E2E2E),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? const Color(0xFF00E676) : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _AttendeeCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AttendeeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Unknown';
    final uid = data['uid'] ?? '';
    final teamName = data['team_name'] as String?;
    final teamColor = data['team_color'] as String?;

    // Count collected items
    int collected = 0;
    for (final key in [
      'registration_goodies',
      'breakfast',
      'lunch',
      'snacks',
      'dinner',
      'midnight_snacks'
    ]) {
      if (data[key] == true) collected++;
    }

    Color? dotColor;
    if (teamColor != null && teamColor.isNotEmpty) {
      final hex = teamColor.replaceFirst('#', '');
      dotColor = Color(int.parse('FF$hex', radix: 16));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: dotColor?.withValues(alpha: 0.15) ??
                const Color(0xFF00E676).withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: dotColor ?? const Color(0xFF00E676),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (teamName != null) ...[
                      if (dotColor != null)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor,
                          ),
                        ),
                      Text(
                        teamName,
                        style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      uid,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$collected/6',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: collected >= 6 ? const Color(0xFF00E676) : Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: collected / 6.0,
                    backgroundColor: const Color(0xFF2E2E2E),
                    color: collected >= 6
                        ? const Color(0xFF00E676)
                        : const Color(0xFF76FF03),
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamGroupCard extends StatefulWidget {
  final Map<String, dynamic> data;

  const _TeamGroupCard({required this.data});

  @override
  State<_TeamGroupCard> createState() => _TeamGroupCardState();
}

class _TeamGroupCardState extends State<_TeamGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final teamName = d['team_name'] ?? '';
    final colorHex = (d['team_color'] as String? ?? '#00E676').replaceFirst('#', '');
    final teamColor = Color(int.parse('FF$colorHex', radix: 16));
    final members = (d['members'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? teamColor.withValues(alpha: 0.4)
              : const Color(0xFF2E2E2E),
        ),
      ),
      child: Column(
        children: [
          // Team header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: teamColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      teamName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${members.length} members',
                    style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFFB0B0B0),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Expanded members
          if (_expanded && members.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(color: Color(0xFF2E2E2E), height: 1),
                  const SizedBox(height: 8),
                  ...members.map((m) {
                    final member = m as Map<String, dynamic>;
                    final mName = member['name'] ?? '';
                    int mCollected = 0;
                    for (final key in [
                      'registration_goodies',
                      'breakfast',
                      'lunch',
                      'snacks',
                      'dinner',
                      'midnight_snacks'
                    ]) {
                      if (member[key] == true) mCollected++;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: teamColor.withValues(alpha: 0.15),
                            child: Text(
                              mName.isNotEmpty ? mName[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: teamColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              mName,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          Text(
                            '$mCollected/6',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: mCollected >= 6 ? const Color(0xFF00E676) : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
