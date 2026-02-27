import 'package:shared_preferences/shared_preferences.dart';

enum SlotState { locked, available, collected, expired }

class DistributionSlot {
  final String id;
  final String title;
  final String icon;
  final int startDayOffset; // 0 for Day 1, 1 for Day 2
  final int startHour;
  final int startMinute;
  final int endDayOffset;
  final int endHour;
  final int endMinute;

  const DistributionSlot({
    required this.id,
    required this.title,
    required this.icon,
    required this.startDayOffset,
    required this.startHour,
    required this.startMinute,
    required this.endDayOffset,
    required this.endHour,
    required this.endMinute,
  });

  String get timeDisplay {
    String formatTime(int h, int m) {
      final period = h >= 12 ? 'PM' : 'AM';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      final minStr = m.toString().padLeft(2, '0');
      return '$hour12:$minStr $period';
    }
    return '${formatTime(startHour, startMinute)} - ${formatTime(endHour, endMinute)}';
  }
}

class TimeManager {
  static const List<DistributionSlot> slots = [
    DistributionSlot(
      id: 'registration_goodies',
      title: 'Registration & Goodies',
      icon: '🎁',
      startDayOffset: 0,
      startHour: 8,
      startMinute: 0,
      endDayOffset: 0,
      endHour: 12,
      endMinute: 0,
    ),
    DistributionSlot(
      id: 'lunch',
      title: 'Lunch',
      icon: '🍔',
      startDayOffset: 0,
      startHour: 12,
      startMinute: 30,
      endDayOffset: 0,
      endHour: 16,
      endMinute: 0,
    ),
    DistributionSlot(
      id: 'snacks',
      title: 'Evening Snacks',
      icon: '☕',
      startDayOffset: 0,
      startHour: 16,
      startMinute: 30,
      endDayOffset: 0,
      endHour: 19,
      endMinute: 0,
    ),
    DistributionSlot(
      id: 'dinner',
      title: 'Dinner',
      icon: '🍽️',
      startDayOffset: 0,
      startHour: 20,
      startMinute: 0,
      endDayOffset: 0,
      endHour: 23,
      endMinute: 0,
    ),
    DistributionSlot(
      id: 'midnight_snacks',
      title: 'Midnight Snacks',
      icon: '🌙',
      startDayOffset: 1, // Day 2
      startHour: 0,
      startMinute: 0,
      endDayOffset: 1,
      endHour: 2,
      endMinute: 0,
    ),
    DistributionSlot(
      id: 'breakfast',
      title: 'Breakfast',
      icon: '☕',
      startDayOffset: 1, // Day 2
      startHour: 7,
      startMinute: 30,
      endDayOffset: 1,
      endHour: 10,
      endMinute: 30,
    ),
  ];

  DateTime? _eventStartDate;

  // If testing, we can override the current time here
  DateTime get now => DateTime.now();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('eventStartDate');
    if (millis != null) {
      _eventStartDate = DateTime.fromMillisecondsSinceEpoch(millis);
    } else {
      // Default to today for immediate testing
      final today = DateTime.now();
      _eventStartDate = DateTime(today.year, today.month, today.day);
      await prefs.setInt('eventStartDate', _eventStartDate!.millisecondsSinceEpoch);
    }
  }

  Future<void> setEventStartDate(DateTime date) async {
    final cleanDate = DateTime(date.year, date.month, date.day);
    _eventStartDate = cleanDate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('eventStartDate', cleanDate.millisecondsSinceEpoch);
  }

  DateTime get eventStartDate => _eventStartDate ?? DateTime.now();

  DateTime getSlotStartTime(DistributionSlot slot) {
    return _eventStartDate!.add(
      Duration(
        days: slot.startDayOffset,
        hours: slot.startHour,
        minutes: slot.startMinute,
      ),
    );
  }

  DateTime getSlotEndTimeWithGrace(DistributionSlot slot) {
    return _eventStartDate!.add(
      Duration(
        days: slot.endDayOffset,
        hours: slot.endHour,
        minutes: slot.endMinute + 5, // 5 min grace period
      ),
    );
  }

  SlotState getSlotState(DistributionSlot slot, bool isCollected) {
    if (isCollected) {
      return SlotState.collected;
    }

    if (_eventStartDate == null) return SlotState.locked;

    final current = now;
    final start = getSlotStartTime(slot);
    final end = getSlotEndTimeWithGrace(slot);

    if (current.isBefore(start)) {
      return SlotState.locked;
    } else if (current.isAfter(end)) {
      return SlotState.expired;
    } else {
      return SlotState.available;
    }
  }

  String getCountdownText(DistributionSlot slot) {
    if (_eventStartDate == null) return '';
    
    final current = now;
    final start = getSlotStartTime(slot);
    
    if (current.isAfter(start)) return '';

    final diff = start.difference(current);
    if (diff.inDays > 0) {
      return 'Opens in ${diff.inDays}d ${diff.inHours % 24}h';
    } else if (diff.inHours > 0) {
      return 'Opens in ${diff.inHours}h ${diff.inMinutes % 60}m';
    } else {
      return 'Opens in ${diff.inMinutes} mins';
    }
  }
}

// Global Singleton Instance
final timeManager = TimeManager();
