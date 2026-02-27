import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:nfc_manager/nfc_manager.dart';

import 'api_service.dart';
import 'models.dart';
import 'login_screen.dart';
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
  
  // Timers and Animation controllers
  Timer? _minuteTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  
  // Store the exact time we fetched the participant to show "Last scanned"
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    // Start pulse animation for Available items / NFC logo
    _pulseController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Refresh time-based logic every minute
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

        // Haptic feedback
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
      setState(() {
        _participant = Participant.fromJson(result);
        _lastFetchTime = DateTime.now();
        _statusMessage = 'Participant Found';
        _loading = false;
      });
      HapticFeedback.mediumImpact();
    } else {
      setState(() {
        _participant = null;
        _statusMessage = result['status'] == 'invalid' 
            ? 'Invalid NFC Tag' 
            : (result['message'] ?? 'Error');
        _loading = false;
      });
      _showToast(result['message'] ?? 'No participant linked to this tag', isError: true);
      HapticFeedback.heavyImpact();
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
      HapticFeedback.heavyImpact(); // Confirms success
      await _scanUid(_lastScannedUid!);
    } else if (response.isAlreadyCollected) {
      _showToast(response.message, isError: true);
      HapticFeedback.vibrate();
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

  Future<void> _logout() async {
    await widget.api.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(api: widget.api),
      ),
    );
  }

  void _resetScan() {
    setState(() {
      _participant = null;
      _lastScannedUid = null;
      _statusMessage = 'Hold NFC tag near the device...';
    });
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NFC Event Manager',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Export feature coming soon")),
              );
            },
          ),
          if (_participant != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _scanUid(_lastScannedUid!),
              tooltip: 'Refresh Status',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
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
      ),
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
        'startTime': timeManager.getSlotStartTime(slot) // secondary sort
      });
    }

    // Sort slots logically
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
        // 1. User Profile Card
        Container(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.1),
                    child: Text(
                      p.name == 'Unknown' ? '?' : p.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E676),
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
                        Text(
                          p.college,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFB0B0B0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.w600),
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
        ),

        const SizedBox(height: 20),

        // 2. Progress Indicator
        Column(
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
        ),

        const SizedBox(height: 24),
        
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

        // 3. Items List
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
                  const SizedBox(height: 48), // Padding before end of scroll
                ],
              ),
            ),
          )
        else
          ...slotData.map((data) => _buildSlotCard(data)),
      ],
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> data) {
    final slot = data['slot'] as DistributionSlot;
    final state = data['state'] as SlotState;
    final pData = data['pData'] as Map<String, dynamic>;
    final collectedTime = pData['time'] as DateTime?;
    
    // Default styling (Locked/Missed)
    Color bgColor = const Color(0xFF000000);
    Color borderColor = const Color(0xFF2E2E2E);
    double opacity = 0.5;
    
    Color badgeColor = const Color(0xFF2E2E2E);
    Color badgeTextColor = Colors.white;
    String badgeText = "LOCKED";
    bool glowingBorder = false;

    String timeStr = slot.timeDisplay;
    Color timeColor = const Color(0xFFB0B0B0);

    // Apply State Transitions
    switch (state) {
      case SlotState.available:
        bgColor = const Color(0xFF0B1F11); // Very dark green background
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
              // Badge
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
