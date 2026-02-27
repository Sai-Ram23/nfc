import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:nfc_manager/nfc_manager.dart';

import 'api_service.dart';
import 'models.dart';

import 'utils/time_manager.dart';

class ScanScreen extends StatefulWidget {
  final ApiService api;

  const ScanScreen({super.key, required this.api});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with TickerProviderStateMixin {
  bool _nfcAvailable = false;
  bool _loading = false;
  String _statusMessage = 'Ready to Scan';
  Participant? _participant;
  String? _lastScannedUid;
  TeamDetails? _teamDetails;

  // Timers and Animation controllers
  Timer? _minuteTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Store the exact time we fetched the participant to show "Last scanned"
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });

    _checkNfc();
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _pulseController.dispose();
    NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> _checkNfc() async {
    bool available = await NfcManager.instance.isAvailable();
    setState(() {
      _nfcAvailable = available;
      if (available) {
        _startNfcSession();
      } else {
        _statusMessage = 'NFC not available on this device';
      }
    });
  }

  void _startNfcSession() {
    setState(() {
      _statusMessage = 'Hold NFC tag near the device...';
    });

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        final nfca = tag.data['nfca'];
        final nfcb = tag.data['nfcb'];
        final nfcf = tag.data['nfcf'];
        final nfcv = tag.data['nfcv'];
        final isodep = tag.data['isodep'];
        final mifare = tag.data['mifareultralight'] ?? tag.data['mifareclassic'];

        List<int>? identifier;

        if (nfca != null && nfca['identifier'] != null) {
          identifier = List<int>.from(nfca['identifier']);
        } else if (mifare != null && mifare['identifier'] != null) {
          identifier = List<int>.from(mifare['identifier']);
        } else if (nfcb != null && nfcb['identifier'] != null) {
          identifier = List<int>.from(nfcb['identifier']);
        } else if (nfcf != null && nfcf['identifier'] != null) {
          identifier = List<int>.from(nfcf['identifier']);
        } else if (nfcv != null && nfcv['identifier'] != null) {
          identifier = List<int>.from(nfcv['identifier']);
        } else if (isodep != null && isodep['identifier'] != null) {
          identifier = List<int>.from(isodep['identifier']);
        }

        if (identifier == null || identifier.isEmpty) {
          _showToast('Could not read tag UID', isError: true);
          return;
        }

        final uid = identifier
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase();

        HapticFeedback.lightImpact();

        _lastScannedUid = uid;
        await _scanUid(uid);
      },
      onError: (error) async {
        setState(() {
          _statusMessage = 'NFC Error: $error';
        });
      },
    );
  }

  Future<void> _scanUid(String uid) async {
    setState(() {
      _loading = true;
      _statusMessage = 'Syncing status...';
    });

    final result = await widget.api.scanUid(uid);

    if (!mounted) return;

    if (result['status'] == 'valid') {
      final participant = Participant.fromJson(result);
      setState(() {
        _participant = participant;
        _lastFetchTime = DateTime.now();
        _statusMessage = 'Participant Found';
        _loading = false;
      });
      HapticFeedback.mediumImpact();

      // Fetch team details if participant has a team
      if (participant.isTeamMember) {
        _fetchTeamDetails(participant.teamId);
      } else {
        setState(() => _teamDetails = null);
      }
    } else {
      setState(() {
        _participant = null;
        _teamDetails = null;
        _statusMessage = result['status'] == 'invalid'
            ? 'Invalid NFC Tag'
            : (result['message'] ?? 'Error');
        _loading = false;
      });
      _showToast(result['message'] ?? 'No participant linked to this tag', isError: true);
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _fetchTeamDetails(String teamId) async {
    final details = await widget.api.getTeamDetails(teamId);
    if (mounted) {
      setState(() => _teamDetails = details);
    }
  }

  Future<void> _giveItem(DistributionSlot slot, Future<DistributionResponse> Function(String) action) async {
    if (_lastScannedUid == null) return;
    HapticFeedback.selectionClick();

    setState(() => _loading = true);
    final response = await action(_lastScannedUid!);
    if (!mounted) return;
    setState(() => _loading = false);

    if (response.isSuccess) {
      _showToast('✓ ${slot.title} collected successfully');
      HapticFeedback.heavyImpact();
      await _scanUid(_lastScannedUid!);
    } else if (response.isAlreadyCollected) {
      _showToast(response.message, isError: true);
      HapticFeedback.vibrate();
    } else {
      _showToast(response.message, isError: true);
    }
  }

  Future<void> _distributeToTeam(String itemKey, String itemLabel) async {
    if (_participant == null || !_participant!.isTeamMember) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2E2E2E)),
        ),
        title: const Text('Distribute to Team', style: TextStyle(color: Colors.white)),
        content: Text(
          'Give "$itemLabel" to all members of ${_participant!.teamName}?',
          style: const TextStyle(color: Color(0xFFB0B0B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            child: const Text('Distribute'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    final response = await widget.api.distributeToTeam(
      _participant!.teamId,
      itemKey,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (response.isSuccess) {
      _showToast('✓ ${response.message}');
      HapticFeedback.heavyImpact();
      // Refresh scan + team details
      await _scanUid(_lastScannedUid!);
    } else {
      _showToast(response.message, isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1C1C1C),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError ? const Color(0xFFFF5252) : const Color(0xFF00E676),
            width: 2,
          ),
        ),
        dismissDirection: DismissDirection.up,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resetScan() {
    setState(() {
      _participant = null;
      _teamDetails = null;
      _lastScannedUid = null;
      _statusMessage = 'Hold NFC tag near the device...';
    });
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _participant != null
          ? RefreshIndicator(
              color: const Color(0xFF00E676),
              backgroundColor: const Color(0xFF1C1C1C),
              onRefresh: () async {
                if (_lastScannedUid != null) {
                  await _scanUid(_lastScannedUid!);
                }
              },
              child: _buildParticipantView(),
            )
          : _buildScanView(),
    );
  }

  Widget _buildScanView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnim.value,
                child: Container(
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00E676).withValues(alpha: 0.3),
                        const Color(0xFF00E676).withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF00E676).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _nfcAvailable ? Icons.nfc_rounded : Icons.nfc_outlined,
                    size: 80,
                    color: _nfcAvailable
                        ? const Color(0xFF00E676)
                        : Colors.grey,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          if (_loading)
            const CircularProgressIndicator(color: Color(0xFF00E676))
          else
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _nfcAvailable ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          if (!_nfcAvailable) ...[
            const SizedBox(height: 16),
            const Text(
              'Enable NFC in your device settings',
              style: TextStyle(color: Colors.white38),
            ),
          ],
          const SizedBox(height: 48),
          TextButton.icon(
            onPressed: _showManualEntry,
            icon: const Icon(Icons.keyboard, size: 18, color: Color(0xFF00E676)),
            label: const Text('Enter UID manually', style: TextStyle(color: Color(0xFF00E676))),
          ),
        ],
      ),
    );
  }

  void _showManualEntry() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2E2E2E))),
        title: const Text('Enter NFC UID', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. 04A23B1C5D6E80',
            hintStyle: const TextStyle(color: Colors.white30),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E2E2E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00E676)),
            ),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final uid = controller.text.trim().toUpperCase();
              if (uid.isNotEmpty) {
                Navigator.pop(ctx);
                _lastScannedUid = uid;
                _scanUid(uid);
              }
            },
            child: const Text('Scan'),
          ),
        ],
      ),
    );
  }

  // Helper to map a Slot to the Participant's boolean status and timestamp
  Map<String, dynamic> _getParticipantDataForSlot(DistributionSlot slot) {
    final p = _participant!;
    switch (slot.id) {
      case 'registration_goodies':
        return {'collected': p.registrationGoodies, 'time': p.registrationTime, 'action': widget.api.giveRegistration};
      case 'breakfast':
        return {'collected': p.breakfast, 'time': p.breakfastTime, 'action': widget.api.giveBreakfast};
      case 'lunch':
        return {'collected': p.lunch, 'time': p.lunchTime, 'action': widget.api.giveLunch};
      case 'snacks':
        return {'collected': p.snacks, 'time': p.snacksTime, 'action': widget.api.giveSnacks};
      case 'dinner':
        return {'collected': p.dinner, 'time': p.dinnerTime, 'action': widget.api.giveDinner};
      case 'midnight_snacks':
        return {'collected': p.midnightSnacks, 'time': p.midnightSnacksTime, 'action': widget.api.giveMidnightSnacks};
      default:
        return {'collected': false, 'time': null, 'action': (_) async => DistributionResponse(status: 'error', message: 'Unknown')};
    }
  }

  Widget _buildParticipantView() {
    final p = _participant!;
    final timeFormat = DateFormat('h:mm a');

    // Build list of slots with their states for sorting and progress bar
    int collectedCount = 0;
    List<Map<String, dynamic>> slotData = [];

    for (var slot in TimeManager.slots) {
      final pData = _getParticipantDataForSlot(slot);
      final isCollected = pData['collected'] as bool;
      if (isCollected) collectedCount++;

      final state = timeManager.getSlotState(slot, isCollected);
      int sortWeight;
      switch (state) {
        case SlotState.available: sortWeight = 0; break;
        case SlotState.locked: sortWeight = 1; break;
        case SlotState.collected: sortWeight = 2; break;
        case SlotState.expired: sortWeight = 3; break;
      }

      slotData.add({
        'slot': slot,
        'state': state,
        'pData': pData,
        'sortWeight': sortWeight,
        'startTime': timeManager.getSlotStartTime(slot)
      });
    }

    slotData.sort((a, b) {
      if (a['sortWeight'] != b['sortWeight']) {
        return a['sortWeight'].compareTo(b['sortWeight']);
      }
      return (a['startTime'] as DateTime).compareTo(b['startTime'] as DateTime);
    });

    final bool allExpiredOrCollected = slotData.every((s) => s['state'] == SlotState.expired || s['state'] == SlotState.collected);

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // 1. User Profile Card with Team Info
        _buildProfileCard(p, timeFormat, collectedCount),

        const SizedBox(height: 16),

        // 2. Team Context Section (if team member)
        if (p.isTeamMember) ...[
          _buildTeamContextSection(p),
          const SizedBox(height: 16),
        ],

        // 3. Progress Indicator
        _buildProgressBar(collectedCount),

        const SizedBox(height: 16),

        // Scan another button
        OutlinedButton.icon(
          onPressed: _resetScan,
          icon: const Icon(Icons.nfc, color: Colors.white),
          label: const Text('Scan Another Tag', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF2E2E2E)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        const SizedBox(height: 24),

        // 4. Items List
        if (allExpiredOrCollected)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  const Icon(Icons.event_available, color: Color(0xFF00E676), size: 48),
                  const SizedBox(height: 12),
                  const Text('Event Completed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('You collected $collectedCount of 6 items', style: const TextStyle(color: Color(0xFFB0B0B0))),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          )
        else
          ...slotData.map((data) => _buildSlotCard(data)),
      ],
    );
  }

  Widget _buildProfileCard(Participant p, DateFormat timeFormat, int collectedCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.05),
            blurRadius: 20,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team badge (if team member)
          if (p.isTeamMember) ...[
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.teamColorValue,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  p.teamName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.teamColorValue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: p.isTeamMember
                    ? p.teamColorValue.withValues(alpha: 0.15)
                    : const Color(0xFF00E676).withValues(alpha: 0.1),
                child: Text(
                  p.name == 'Unknown' ? '?' : p.name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: p.isTeamMember ? p.teamColorValue : const Color(0xFF00E676),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name == 'Unknown' ? 'Guest Attendee' : p.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.school_outlined, size: 14, color: Color(0xFFB0B0B0)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            p.college,
                            style: const TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (p.isTeamMember) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.group_outlined, size: 14, color: Color(0xFFB0B0B0)),
                          const SizedBox(width: 4),
                          Text(
                            'Team Size: ${p.teamSize} members',
                            style: const TextStyle(fontSize: 13, color: Color(0xFFB0B0B0)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.uid,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                ),
              ),
              if (_lastFetchTime != null)
                Text(
                  'Last scanned: ${timeFormat.format(_lastFetchTime!)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFFB0B0B0)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamContextSection(Participant p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.group, size: 18, color: p.teamColorValue),
                  const SizedBox(width: 8),
                  Text(
                    'Team: ${p.teamName}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showTeamMembersModal(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'View Members',
                    style: TextStyle(fontSize: 11, color: Color(0xFF00E676), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          if (_teamDetails != null) ...[
            const SizedBox(height: 14),
            // Team progress bars for each item
            ..._teamDetails!.teamProgress.entries.map((entry) {
              final parts = entry.value.split('/');
              final collected = int.tryParse(parts[0]) ?? 0;
              final total = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
              final progress = total > 0 ? collected / total : 0.0;
              final label = _itemLabel(entry.key);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: const Color(0xFF2E2E2E),
                          color: progress >= 1.0
                              ? const Color(0xFF00E676)
                              : const Color(0xFF76FF03),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: progress >= 1.0 ? const Color(0xFF00E676) : Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            // Distribute to team button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDistributeTeamPicker(),
                icon: Icon(Icons.group_add, size: 18, color: p.teamColorValue),
                label: const Text(
                  'Distribute to Entire Team',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: p.teamColorValue.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E676),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _itemLabel(String key) {
    const labels = {
      'registration_goodies': 'Registration',
      'breakfast': 'Breakfast',
      'lunch': 'Lunch',
      'snacks': 'Snacks',
      'dinner': 'Dinner',
      'midnight_snacks': 'Midnight',
    };
    return labels[key] ?? key;
  }

  void _showDistributeTeamPicker() {
    final items = [
      ('registration_goodies', 'Registration & Goodies', '🎁'),
      ('breakfast', 'Breakfast', '☕'),
      ('lunch', 'Lunch', '🍱'),
      ('snacks', 'Snacks', '🍿'),
      ('dinner', 'Dinner', '🍽️'),
      ('midnight_snacks', 'Midnight Snacks', '🌙'),
    ];

    showModalBottomSheet(
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Distribute to Entire Team',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Select an item to give to all members of ${_participant!.teamName}',
              style: const TextStyle(fontSize: 13, color: Color(0xFFB0B0B0)),
            ),
            const SizedBox(height: 16),
            ...items.map((item) {
              final progress = _teamDetails?.teamProgress[item.$1] ?? '?/?';
              return ListTile(
                leading: Text(item.$3, style: const TextStyle(fontSize: 24)),
                title: Text(item.$2, style: const TextStyle(color: Colors.white)),
                trailing: Text(progress, style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () {
                  Navigator.pop(ctx);
                  _distributeToTeam(item.$1, item.$2);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showTeamMembersModal() {
    if (_teamDetails == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          final td = _teamDetails!;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2E2E),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: td.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      td.teamName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      '${td.memberCount} members',
                      style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: td.members.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF2E2E2E), height: 1),
                    itemBuilder: (_, index) {
                      final m = td.members[index];
                      final isCurrentUser = m.uid == _participant!.uid;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: isCurrentUser
                              ? td.color.withValues(alpha: 0.2)
                              : const Color(0xFF2E2E2E),
                          child: Text(
                            m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCurrentUser ? td.color : Colors.white70,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                m.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isCurrentUser)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: td.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'YOU',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: td.color),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${m.itemsCollected}/6 collected',
                          style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
                        ),
                        trailing: SizedBox(
                          width: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: m.itemsCollected / 6.0,
                              backgroundColor: const Color(0xFF2E2E2E),
                              color: m.itemsCollected >= 6
                                  ? const Color(0xFF00E676)
                                  : td.color,
                              minHeight: 5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(int collectedCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$collectedCount of 6 items collected',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(6, (index) {
            final isFilled = index < collectedCount;
            return Expanded(
              child: Container(
                height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: isFilled ? const Color(0xFF00E676) : const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: isFilled
                      ? [const BoxShadow(color: Color(0xFF00E676), blurRadius: 4)]
                      : null,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> data) {
    final slot = data['slot'] as DistributionSlot;
    final state = data['state'] as SlotState;
    final pData = data['pData'] as Map<String, dynamic>;
    final collectedTime = pData['time'] as DateTime?;

    Color bgColor = const Color(0xFF000000);
    Color borderColor = const Color(0xFF2E2E2E);
    double opacity = 0.5;

    Color badgeColor = const Color(0xFF2E2E2E);
    Color badgeTextColor = Colors.white;
    String badgeText = "LOCKED";
    bool glowingBorder = false;

    String timeStr = slot.timeDisplay;
    Color timeColor = const Color(0xFFB0B0B0);

    switch (state) {
      case SlotState.available:
        bgColor = const Color(0xFF0B1F11);
        borderColor = const Color(0xFF00E676);
        opacity = 1.0;
        badgeColor = const Color(0xFF00E676);
        badgeTextColor = Colors.black;
        badgeText = "AVAILABLE NOW";
        glowingBorder = true;
        timeColor = const Color(0xFF76FF03);
        break;
      case SlotState.collected:
        borderColor = const Color(0xFF1B5E20);
        opacity = 0.7;
        badgeColor = const Color(0xFF1B5E20);
        if (collectedTime != null) {
          badgeText = "✓ COLLECTED ${DateFormat('h:mm a').format(collectedTime)}";
        } else {
          badgeText = "✓ COLLECTED";
        }
        break;
      case SlotState.locked:
        final countdown = timeManager.getCountdownText(slot);
        if (countdown.isNotEmpty) {
          badgeText = countdown.toUpperCase();
        }
        break;
      case SlotState.expired:
        badgeText = "EXPIRED";
        opacity = 0.4;
        break;
    }

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: glowingBorder ? 2 : 1),
        boxShadow: glowingBorder ? [
          BoxShadow(
            color: const Color(0xFF00E676).withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: opacity,
                child: Text(slot.icon, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: opacity),
                        decoration: state == SlotState.expired ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Time: $timeStr',
                      style: TextStyle(
                        fontSize: 14,
                        color: timeColor.withValues(alpha: opacity),
                        decoration: state == SlotState.expired ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),

          if (state == SlotState.available) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : () => _giveItem(slot, pData['action']),
                child: _loading
                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                   : Text('Collect ${slot.title}', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ]
        ],
      ),
    );

    if (glowingBorder) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Opacity(
            opacity: _pulseAnim.value,
            child: child,
          );
        },
        child: cardContent,
      );
    }

    return cardContent;
  }
}
