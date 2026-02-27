import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'models.dart';

/// Manual distribution screen — look up participants by UID and distribute
/// items without NFC hardware.
class ManualScreen extends StatefulWidget {
  final ApiService api;

  const ManualScreen({super.key, required this.api});

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final _uidController = TextEditingController();
  bool _loading = false;
  Participant? _participant;
  String? _error;

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final uid = _uidController.text.trim().toUpperCase();
    if (uid.isEmpty) {
      setState(() => _error = 'Please enter a UID');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await widget.api.scanUid(uid);

    if (!mounted) return;

    if (result['status'] == 'valid') {
      setState(() {
        _participant = Participant.fromJson(result);
        _loading = false;
      });
    } else {
      setState(() {
        _participant = null;
        _error = result['message'] ?? 'Participant not found';
        _loading = false;
      });
    }
  }

  Future<void> _distribute(String itemKey, String label,
      Future<DistributionResponse> Function(String) action) async {
    final uid = _uidController.text.trim().toUpperCase();
    if (uid.isEmpty) return;

    setState(() => _loading = true);
    final response = await action(uid);
    if (!mounted) return;
    setState(() => _loading = false);

    if (response.isSuccess) {
      _showToast('✓ $label distributed successfully');
      // Refresh participant
      await _lookup();
    } else {
      _showToast(response.message, isError: true);
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

  void _clear() {
    setState(() {
      _uidController.clear();
      _participant = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        const Text(
          'Manual Distribution',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        const Text(
          'Distribute items without NFC by entering a UID directly.',
          style: TextStyle(fontSize: 13, color: Color(0xFFB0B0B0)),
        ),
        const SizedBox(height: 20),

        // UID Input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _uidController,
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 16),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter NFC UID...',
                  hintStyle: const TextStyle(color: Color(0xFF666666)),
                  prefixIcon:
                      const Icon(Icons.badge_outlined, color: Color(0xFFB0B0B0)),
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
                ),
                onSubmitted: (_) => _lookup(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _lookup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.search, size: 24),
              ),
            ),
          ],
        ),

        // Error
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5252).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFFF5252), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFFF5252), fontSize: 13)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Participant result
        if (_participant != null) ...[
          _buildParticipantCard(),
          const SizedBox(height: 16),
          _buildDistributionGrid(),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.clear, size: 16, color: Color(0xFFB0B0B0)),
              label: const Text('Clear',
                  style: TextStyle(color: Color(0xFFB0B0B0))),
            ),
          ),
        ] else if (!_loading && _error == null) ...[
          // Empty state
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                Icon(Icons.keyboard_alt_outlined,
                    size: 64, color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                const Text(
                  'Enter a UID to get started',
                  style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Type the participant\'s NFC tag UID above',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 12),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildParticipantCard() {
    final p = _participant!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF00E676).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: p.isTeamMember
                ? p.teamColorValue.withValues(alpha: 0.15)
                : const Color(0xFF00E676).withValues(alpha: 0.1),
            child: Text(
              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: p.isTeamMember
                    ? p.teamColorValue
                    : const Color(0xFF00E676),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.college,
                  style:
                      const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
                ),
                if (p.isTeamMember) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.teamColorValue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        p.teamName,
                        style: TextStyle(
                            color: p.teamColorValue, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Collected count
          Column(
            children: [
              Text(
                '${p.itemsCollected}/6',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: p.itemsCollected >= 6
                      ? const Color(0xFF00E676)
                      : Colors.white,
                ),
              ),
              const Text('collected',
                  style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionGrid() {
    final p = _participant!;
    final timeFormat = DateFormat('h:mm a');

    final items = [
      _ItemData('🎁', 'Registration', p.registrationGoodies,
          p.registrationTime, widget.api.giveRegistration),
      _ItemData('☕', 'Breakfast', p.breakfast, p.breakfastTime,
          widget.api.giveBreakfast),
      _ItemData(
          '🍱', 'Lunch', p.lunch, p.lunchTime, widget.api.giveLunch),
      _ItemData('🍿', 'Snacks', p.snacks, p.snacksTime,
          widget.api.giveSnacks),
      _ItemData('🍽️', 'Dinner', p.dinner, p.dinnerTime,
          widget.api.giveDinner),
      _ItemData('🌙', 'Midnight', p.midnightSnacks,
          p.midnightSnacksTime, widget.api.giveMidnightSnacks),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribute Items',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: items.map((item) {
            return _ItemButton(
              icon: item.icon,
              label: item.label,
              collected: item.collected,
              collectedTime: item.collectedTime,
              timeFormat: timeFormat,
              loading: _loading,
              onTap: () =>
                  _distribute(item.label, item.label, item.action),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ItemData {
  final String icon;
  final String label;
  final bool collected;
  final DateTime? collectedTime;
  final Future<DistributionResponse> Function(String) action;

  _ItemData(this.icon, this.label, this.collected, this.collectedTime,
      this.action);
}

class _ItemButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool collected;
  final DateTime? collectedTime;
  final DateFormat timeFormat;
  final bool loading;
  final VoidCallback onTap;

  const _ItemButton({
    required this.icon,
    required this.label,
    required this.collected,
    required this.collectedTime,
    required this.timeFormat,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: collected || loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: collected
              ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
              : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: collected
                ? const Color(0xFF1B5E20)
                : const Color(0xFF2E2E2E),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: TextStyle(fontSize: 22,
                    color: collected ? null : null)),
                if (collected)
                  const Icon(Icons.check_circle,
                      color: Color(0xFF00E676), size: 20)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'GIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: collected ? const Color(0xFF00E676) : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (collected && collectedTime != null)
                  Text(
                    '✓ ${timeFormat.format(collectedTime!)}',
                    style: const TextStyle(
                        color: Color(0xFFB0B0B0), fontSize: 10),
                  )
                else if (!collected)
                  const Text(
                    'Tap to distribute',
                    style:
                        TextStyle(color: Color(0xFF666666), fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
