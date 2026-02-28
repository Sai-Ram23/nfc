import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'models.dart';

class TeamsScreen extends StatefulWidget {
  final ApiService api;

  const TeamsScreen({super.key, required this.api});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<PreregTeam> _teams = [];
  bool _loading = true;
  final Set<String> _expandedTeams = {};

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _loading = true;
    });
    final teams = await widget.api.getPreregTeams();
    if (mounted) {
      setState(() {
        _teams = teams;
        _loading = false;
      });
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style:
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // ── Create New Team ──────────────────────────────────────────────────────

  static const List<Color> _teamColors = [
    Color(0xFF00E676), // green
    Color(0xFFFF6B6B), // red
    Color(0xFF448AFF), // blue
    Color(0xFFFFD740), // yellow
    Color(0xFFFF80AB), // pink
    Color(0xFF69F0AE), // mint
  ];

  Future<void> _showCreateTeamSheet() async {
    final nameController = TextEditingController();
    Color selectedColor = _teamColors[0];
    bool creating = false;
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Create New Team',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Team name field
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Team Name',
                      labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                      filled: true,
                      fillColor: const Color(0xFF2E2E2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFF00E676), width: 2),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() => errorMessage = null),
                  ),
                  const SizedBox(height: 16),
                  // Color picker
                  const Text('Team Color',
                      style: TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: _teamColors.map((color) {
                      final isSelected = color == selectedColor;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: isSelected ? 40 : 34,
                          height: isSelected ? 40 : 34,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFFFF5252).withValues(alpha: 0.4)),
                      ),
                      child: Text(errorMessage!,
                          style: const TextStyle(
                              color: Color(0xFFFF5252), fontSize: 13)),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: creating
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                setSheetState(() =>
                                    errorMessage = 'Team name cannot be empty.');
                                return;
                              }
                              setSheetState(() => creating = true);
                              // team_id = snake_case of name
                              final teamId = name
                                  .toLowerCase()
                                  .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                                  .replaceAll(RegExp(r'^_|_$'), '');
                              final colorHex =
                                  '#${selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                              final result =
                                  await widget.api.createPreregTeam(
                                teamId: teamId,
                                teamName: name,
                                teamColor: colorHex,
                              );
                              if (!ctx.mounted) return;
                              if (result['status'] == 'created') {
                                Navigator.pop(ctx);
                                HapticFeedback.mediumImpact();
                                _showToast('Team "$name" created!');
                                _loadTeams();
                              } else {
                                setSheetState(() {
                                  creating = false;
                                  errorMessage = result['message'] ??
                                      'Failed to create team.';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: creating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ))
                          : const Text('Create Team',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Add Member ───────────────────────────────────────────────────────────

  Future<void> _showAddMemberSheet(PreregTeam team) async {
    final nameController = TextEditingController();
    final collegeController = TextEditingController();
    bool adding = false;
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Add Member to ${team.teamName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                      filled: true,
                      fillColor: const Color(0xFF2E2E2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFF00E676), width: 2),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() => errorMessage = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: collegeController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'College',
                      labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                      filled: true,
                      fillColor: const Color(0xFF2E2E2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFF00E676), width: 2),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() => errorMessage = null),
                  ),
                  const SizedBox(height: 20),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                const Color(0xFFFF5252).withValues(alpha: 0.4)),
                      ),
                      child: Text(errorMessage!,
                          style: const TextStyle(
                              color: Color(0xFFFF5252), fontSize: 13)),
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: adding
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              final college = collegeController.text.trim();
                              if (name.isEmpty || college.isEmpty) {
                                setSheetState(() =>
                                    errorMessage = 'Name and College are required.');
                                return;
                              }
                              setSheetState(() => adding = true);
                              final result = await widget.api.addPreregMember(
                                teamId: team.teamId,
                                name: name,
                                college: college,
                              );
                              if (!ctx.mounted) return;
                              if (result['status'] == 'created') {
                                Navigator.pop(ctx);
                                HapticFeedback.mediumImpact();
                                _showToast('$name added to ${team.teamName}!');
                                _loadTeams();
                              } else {
                                setSheetState(() {
                                  adding = false;
                                  errorMessage = result['message'] ??
                                      'Failed to add member.';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: adding
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ))
                          : const Text('Add Member',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Teams',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      // Refresh
                      IconButton(
                        onPressed: _loadTeams,
                        icon: const Icon(Icons.refresh,
                            color: Color(0xFF00E676), size: 22),
                        tooltip: 'Refresh',
                      ),
                      // Add Team
                      GestureDetector(
                        onTap: _showCreateTeamSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, color: Colors.black, size: 18),
                              SizedBox(width: 4),
                              Text('New Team',
                                  style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Text(
                    '${_teams.length} teams · '
                    '${_teams.fold(0, (s, t) => s + t.unregisteredMembers.length)} unlinked slots',
                    style: const TextStyle(
                        color: Color(0xFFB0B0B0), fontSize: 13),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00E676)))
                  : _teams.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: const Color(0xFF00E676),
                          backgroundColor: const Color(0xFF1C1C1C),
                          onRefresh: _loadTeams,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: _teams.length,
                            itemBuilder: (context, index) =>
                                _buildTeamCard(_teams[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_off_outlined,
              color: Color(0xFF3E3E3E), size: 64),
          const SizedBox(height: 16),
          const Text('No teams yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tap "New Team" to create one,\nor import via CSV.',
              style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreateTeamSheet,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create First Team'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(PreregTeam team) {
    final isExpanded = _expandedTeams.contains(team.teamId);
    final teamColor =
        Color(int.parse('FF${team.teamColor.replaceFirst('#', '')}', radix: 16));
    final unlinkedCount = team.unregisteredMembers.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? teamColor.withValues(alpha: 0.5)
              : const Color(0xFF2E2E2E),
        ),
      ),
      child: Column(
        children: [
          // Team header row
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedTeams.remove(team.teamId);
                } else {
                  _expandedTeams.add(team.teamId);
                }
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Color dot
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: teamColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.teamName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          unlinkedCount == 0
                              ? 'All members registered ✓'
                              : '$unlinkedCount unregistered slot${unlinkedCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: unlinkedCount == 0
                                ? const Color(0xFF00E676)
                                : const Color(0xFFB0B0B0),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add member button
                  GestureDetector(
                    onTap: () => _showAddMemberSheet(team),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: teamColor.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_add_alt_1,
                              color: teamColor, size: 14),
                          const SizedBox(width: 4),
                          Text('Add',
                              style: TextStyle(
                                  color: teamColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white54, size: 22),
                  ),
                ],
              ),
            ),
          ),
          // Expanded member list
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFF2E2E2E)),
            if (team.unregisteredMembers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No unregistered member slots in this team.',
                  style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13),
                ),
              )
            else
              ...team.unregisteredMembers.map((member) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            teamColor.withValues(alpha: 0.15),
                        child: Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: teamColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text(member.college,
                                style: const TextStyle(
                                    color: Color(0xFFB0B0B0), fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E2E2E),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Unlinked',
                            style: TextStyle(
                                color: Color(0xFFB0B0B0), fontSize: 10)),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }
}
