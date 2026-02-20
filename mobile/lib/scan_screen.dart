import 'package:flutter/material.dart';
import 'dart:async';
import 'package:nfc_manager/nfc_manager.dart';
import 'api_service.dart';
import 'models.dart';
import 'result_screen.dart';
import 'login_screen.dart';

class ScanScreen extends StatefulWidget {
  final ApiService api;

  const ScanScreen({super.key, required this.api});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  bool _nfcAvailable = false;
  bool _loading = false;
  String _statusMessage = 'Ready to Scan';
  Participant? _participant;
  String? _lastScannedUid;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

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
    _checkNfc();
  }

  @override
  void dispose() {
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
        // Extract hardware UID from the tag
        final nfca = tag.data['nfca'];
        final nfcb = tag.data['nfcb'];
        final nfcf = tag.data['nfcf'];
        final nfcv = tag.data['nfcv'];
        final isodep = tag.data['isodep'];
        final mifare = tag.data['mifareultralight'] ?? tag.data['mifareclassic'];

        List<int>? identifier;

        // Try to get UID from various tag types
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
          setState(() {
            _statusMessage = 'Could not read tag UID';
          });
          return;
        }

        // Convert to uppercase hex string without colons
        final uid = identifier
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase();

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
      _statusMessage = 'Looking up participant...';
    });

    final result = await widget.api.scanUid(uid);

    if (!mounted) return;

    if (result['status'] == 'valid') {
      setState(() {
        _participant = Participant(
          uid: uid,
          name: result['name'] ?? 'Unknown',
          college: result['college'] ?? 'Unknown',
          breakfast: result['breakfast'] ?? false,
          lunch: result['lunch'] ?? false,
          dinner: result['dinner'] ?? false,
          goodieCollected: result['goodie_collected'] ?? false,
        );
        _statusMessage = 'Participant Found';
        _loading = false;
      });
    } else if (result['status'] == 'invalid') {
      setState(() {
        _participant = null;
        _statusMessage = 'Invalid NFC Tag';
        _loading = false;
      });
      _showResult(ResultType.invalid, 'No participant linked to this tag');
    } else {
      setState(() {
        _participant = null;
        _statusMessage = result['message'] ?? 'Error';
        _loading = false;
      });
      _showResult(ResultType.error, result['message'] ?? 'Unknown error');
    }
  }

  Future<void> _giveItem(String label, Future<DistributionResponse> Function(String) action) async {
    if (_lastScannedUid == null) return;

    setState(() => _loading = true);

    final response = await action(_lastScannedUid!);

    if (!mounted) return;

    setState(() => _loading = false);

    if (response.isSuccess) {
      _showResult(ResultType.success, response.message);
      // Refresh participant data
      await _scanUid(_lastScannedUid!);
    } else if (response.isAlreadyCollected) {
      _showResult(ResultType.duplicate, response.message);
    } else {
      _showResult(ResultType.error, response.message);
    }
  }

  void _showResult(ResultType type, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ResultOverlay(type: type, message: message),
    );

    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Event Manager'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_participant != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetScan,
              tooltip: 'New Scan',
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
            ? _buildParticipantView()
            : _buildScanView(),
      ),
    );
  }

  Widget _buildScanView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated NFC icon
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
                        const Color(0xFF6C63FF).withValues(alpha: 0.3),
                        const Color(0xFF6C63FF).withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _nfcAvailable ? Icons.nfc_rounded : Icons.nfc_outlined,
                    size: 80,
                    color: _nfcAvailable
                        ? const Color(0xFF6C63FF)
                        : Colors.grey,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Status text
          if (_loading)
            const CircularProgressIndicator()
          else
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _nfcAvailable ? Colors.white : Colors.grey,
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

          // Manual UID entry for testing
          const SizedBox(height: 48),
          TextButton.icon(
            onPressed: () => _showManualEntry(),
            icon: const Icon(Icons.keyboard, size: 18),
            label: const Text('Enter UID manually'),
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
        backgroundColor: const Color(0xFF1A1A3E),
        title: const Text('Enter NFC UID'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'e.g. 04A23B1C5D6E80',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
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

  Widget _buildParticipantView() {
    final p = _participant!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Participant Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFF6C63FF),
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    p.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 4),

                  // College
                  Text(
                    p.college,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white60,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // UID Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'UID: ${p.uid}',
                      style: const TextStyle(
                        color: Color(0xFF9D97FF),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Distribution Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distribution Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _statusRow('Breakfast', p.breakfast, Icons.free_breakfast),
                  _statusRow('Lunch', p.lunch, Icons.lunch_dining),
                  _statusRow('Dinner', p.dinner, Icons.dinner_dining),
                  _statusRow('Goodie', p.goodieCollected, Icons.card_giftcard),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildActionButton(
              'Give Breakfast',
              Icons.free_breakfast,
              p.breakfast,
              const Color(0xFFF59E0B),
              () => _giveItem('Breakfast', widget.api.giveBreakfast),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Give Lunch',
              Icons.lunch_dining,
              p.lunch,
              const Color(0xFF10B981),
              () => _giveItem('Lunch', widget.api.giveLunch),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Give Dinner',
              Icons.dinner_dining,
              p.dinner,
              const Color(0xFF3B82F6),
              () => _giveItem('Dinner', widget.api.giveDinner),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              'Give Goodie',
              Icons.card_giftcard,
              p.goodieCollected,
              const Color(0xFFEC4899),
              () => _giveItem('Goodie', widget.api.giveGoodie),
            ),
          ],

          const SizedBox(height: 24),

          // Scan another button
          OutlinedButton.icon(
            onPressed: _resetScan,
            icon: const Icon(Icons.nfc),
            label: const Text('Scan Another Tag'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, bool collected, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: collected
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  collected ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: collected ? Colors.greenAccent : Colors.white30,
                ),
                const SizedBox(width: 6),
                Text(
                  collected ? 'Collected' : 'Pending',
                  style: TextStyle(
                    color: collected ? Colors.greenAccent : Colors.white30,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    bool alreadyCollected,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: alreadyCollected ? null : onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          alreadyCollected ? '$label ✓ Collected' : label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: alreadyCollected
              ? Colors.grey.shade800
              : color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade800,
          disabledForegroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: alreadyCollected ? 0 : 4,
        ),
      ),
    );
  }
}
