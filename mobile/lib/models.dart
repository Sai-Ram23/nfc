/// Data model for a participant from the backend.
class Participant {
  final String uid;
  final String name;
  final String college;
  
  // States
  final bool registrationGoodies;
  final bool breakfast;
  final bool lunch;
  final bool snacks;
  final bool dinner;
  final bool midnightSnacks;

  // Timestamps
  final DateTime? registrationTime;
  final DateTime? breakfastTime;
  final DateTime? lunchTime;
  final DateTime? snacksTime;
  final DateTime? dinnerTime;
  final DateTime? midnightSnacksTime;

  Participant({
    required this.uid,
    required this.name,
    required this.college,
    required this.registrationGoodies,
    required this.breakfast,
    required this.lunch,
    required this.snacks,
    required this.dinner,
    required this.midnightSnacks,
    this.registrationTime,
    this.breakfastTime,
    this.lunchTime,
    this.snacksTime,
    this.dinnerTime,
    this.midnightSnacksTime,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    DateTime? parseTime(String? dateStr) {
      if (dateStr == null) return null;
      return DateTime.tryParse(dateStr)?.toLocal();
    }

    return Participant(
      uid: json['uid'] ?? '',
      name: json['name'] ?? 'Unknown',
      college: json['college'] ?? 'Unknown',
      registrationGoodies: json['registration_goodies'] ?? false,
      breakfast: json['breakfast'] ?? false,
      lunch: json['lunch'] ?? false,
      snacks: json['snacks'] ?? false,
      dinner: json['dinner'] ?? false,
      midnightSnacks: json['midnight_snacks'] ?? false,
      registrationTime: parseTime(json['registration_time']),
      breakfastTime: parseTime(json['breakfast_time']),
      lunchTime: parseTime(json['lunch_time']),
      snacksTime: parseTime(json['snacks_time']),
      dinnerTime: parseTime(json['dinner_time']),
      midnightSnacksTime: parseTime(json['midnight_snacks_time']),
    );
  }
}

/// Response from a distribution action (give-breakfast, etc.)
class DistributionResponse {
  final String status; // 'success', 'already_collected', 'invalid'
  final String message;
  final String? name;
  final String? college;

  DistributionResponse({
    required this.status,
    required this.message,
    this.name,
    this.college,
  });

  factory DistributionResponse.fromJson(Map<String, dynamic> json) {
    return DistributionResponse(
      status: json['status'] ?? 'error',
      message: json['message'] ?? 'Unknown error',
      name: json['name'],
      college: json['college'],
    );
  }

  bool get isSuccess => status == 'success';
  bool get isAlreadyCollected => status == 'already_collected';
}
