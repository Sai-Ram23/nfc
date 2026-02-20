/// Data model for a participant from the backend.
class Participant {
  final String uid;
  final String name;
  final String college;
  final bool breakfast;
  final bool lunch;
  final bool dinner;
  final bool goodieCollected;

  Participant({
    required this.uid,
    required this.name,
    required this.college,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.goodieCollected,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      uid: json['uid'] ?? '',
      name: json['name'] ?? 'Unknown',
      college: json['college'] ?? 'Unknown',
      breakfast: json['breakfast'] ?? false,
      lunch: json['lunch'] ?? false,
      dinner: json['dinner'] ?? false,
      goodieCollected: json['goodie_collected'] ?? false,
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
