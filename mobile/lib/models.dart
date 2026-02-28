import 'dart:ui';

/// Data model for a team.
class Team {
  final String teamId;
  final String teamName;
  final String teamColor;
  final int teamSize;

  Team({
    required this.teamId,
    required this.teamName,
    required this.teamColor,
    required this.teamSize,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      teamId: json['team_id'] ?? '',
      teamName: json['team_name'] ?? 'Individual',
      teamColor: json['team_color'] ?? '#00E676',
      teamSize: json['team_size'] ?? json['member_count'] ?? 1,
    );
  }

  /// Parse hex color string to Color object.
  Color get color {
    final hex = teamColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  bool get isIndividual => teamId.isEmpty;
}

/// Data model for a participant from the backend.
class Participant {
  final String uid;
  final String name;
  final String college;

  // Team info
  final String teamId;
  final String teamName;
  final String teamColor;
  final int teamSize;

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
    this.teamId = '',
    this.teamName = 'Individual',
    this.teamColor = '#00E676',
    this.teamSize = 1,
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
      teamId: json['team_id'] ?? '',
      teamName: json['team_name'] ?? 'Individual',
      teamColor: json['team_color'] ?? '#00E676',
      teamSize: json['team_size'] ?? 1,
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

  /// Whether this participant belongs to a team.
  bool get isTeamMember => teamId.isNotEmpty;

  /// Parse hex team color to Color object.
  Color get teamColorValue {
    final hex = teamColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  /// Count of collected items.
  int get itemsCollected {
    int count = 0;
    if (registrationGoodies) count++;
    if (breakfast) count++;
    if (lunch) count++;
    if (snacks) count++;
    if (dinner) count++;
    if (midnightSnacks) count++;
    return count;
  }
}

/// Compact member info used in team detail views.
class TeamMember {
  final String uid;
  final String name;
  final String college;
  final bool registrationGoodies;
  final bool breakfast;
  final bool lunch;
  final bool snacks;
  final bool dinner;
  final bool midnightSnacks;
  final int itemsCollected;
  final DateTime? lastScan;

  TeamMember({
    required this.uid,
    required this.name,
    required this.college,
    required this.registrationGoodies,
    required this.breakfast,
    required this.lunch,
    required this.snacks,
    required this.dinner,
    required this.midnightSnacks,
    required this.itemsCollected,
    this.lastScan,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      uid: json['uid'] ?? '',
      name: json['name'] ?? 'Unknown',
      college: json['college'] ?? '',
      registrationGoodies: json['registration_goodies'] ?? false,
      breakfast: json['breakfast'] ?? false,
      lunch: json['lunch'] ?? false,
      snacks: json['snacks'] ?? false,
      dinner: json['dinner'] ?? false,
      midnightSnacks: json['midnight_snacks'] ?? false,
      itemsCollected: json['items_collected'] ?? 0,
      lastScan: json['last_scan'] != null
          ? DateTime.tryParse(json['last_scan'])?.toLocal()
          : null,
    );
  }

  /// List of missing item names.
  List<String> get missingItems {
    final missing = <String>[];
    if (!registrationGoodies) missing.add('Registration & Goodies');
    if (!breakfast) missing.add('Breakfast');
    if (!lunch) missing.add('Lunch');
    if (!snacks) missing.add('Snacks');
    if (!dinner) missing.add('Dinner');
    if (!midnightSnacks) missing.add('Midnight Snacks');
    return missing;
  }
}

/// Full team details including members and progress.
class TeamDetails {
  final String teamId;
  final String teamName;
  final String teamColor;
  final int memberCount;
  final List<TeamMember> members;
  final Map<String, String> teamProgress; // e.g. {"lunch": "2/4"}

  TeamDetails({
    required this.teamId,
    required this.teamName,
    required this.teamColor,
    required this.memberCount,
    required this.members,
    required this.teamProgress,
  });

  factory TeamDetails.fromJson(Map<String, dynamic> json) {
    return TeamDetails(
      teamId: json['team_id'] ?? '',
      teamName: json['team_name'] ?? '',
      teamColor: json['team_color'] ?? '#00E676',
      memberCount: json['member_count'] ?? 0,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((m) => TeamMember.fromJson(m as Map<String, dynamic>))
          .toList(),
      teamProgress: (json['team_progress'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// Parse hex team color to Color object.
  Color get color {
    final hex = teamColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
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

/// Response from a team bulk distribution action.
class TeamDistributionResponse {
  final String status;
  final String message;
  final List<String> distributed;
  final List<String> alreadyCollected;

  TeamDistributionResponse({
    required this.status,
    required this.message,
    required this.distributed,
    required this.alreadyCollected,
  });

  factory TeamDistributionResponse.fromJson(Map<String, dynamic> json) {
    return TeamDistributionResponse(
      status: json['status'] ?? 'error',
      message: json['message'] ?? 'Unknown error',
      distributed: List<String>.from(json['distributed'] ?? []),
      alreadyCollected: List<String>.from(json['already_collected'] ?? []),
    );
  }

  bool get isSuccess => status == 'success';
}

/// Dashboard statistics from /api/stats/.
class DashboardStats {
  final int totalParticipants;
  final int totalTeams;
  final int soloParticipants;
  final double averageTeamSize;
  final int registrationGiven;
  final int breakfastGiven;
  final int lunchGiven;
  final int snacksGiven;
  final int dinnerGiven;
  final int midnightSnacksGiven;

  DashboardStats({
    required this.totalParticipants,
    required this.totalTeams,
    required this.soloParticipants,
    required this.averageTeamSize,
    required this.registrationGiven,
    required this.breakfastGiven,
    required this.lunchGiven,
    required this.snacksGiven,
    required this.dinnerGiven,
    required this.midnightSnacksGiven,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalParticipants: json['total_participants'] ?? 0,
      totalTeams: json['total_teams'] ?? 0,
      soloParticipants: json['solo_participants'] ?? 0,
      averageTeamSize: (json['average_team_size'] ?? 0).toDouble(),
      registrationGiven: json['registration_given'] ?? 0,
      breakfastGiven: json['breakfast_given'] ?? 0,
      lunchGiven: json['lunch_given'] ?? 0,
      snacksGiven: json['snacks_given'] ?? 0,
      dinnerGiven: json['dinner_given'] ?? 0,
      midnightSnacksGiven: json['midnight_snacks_given'] ?? 0,
    );
  }

  /// Pending counts (based on total participants).
  int get registrationPending => totalParticipants - registrationGiven;
  int get breakfastPending => totalParticipants - breakfastGiven;
  int get lunchPending => totalParticipants - lunchGiven;
  int get snacksPending => totalParticipants - snacksGiven;
  int get dinnerPending => totalParticipants - dinnerGiven;
  int get midnightSnacksPending => totalParticipants - midnightSnacksGiven;
}

/// A single pre-registered member slot (name + college, no NFC UID yet).
class PreregMember {
  final int id;
  final String name;
  final String college;

  PreregMember({
    required this.id,
    required this.name,
    required this.college,
  });

  factory PreregMember.fromJson(Map<String, dynamic> json) {
    return PreregMember(
      id: json['id'] as int,
      name: json['name'] ?? '',
      college: json['college'] ?? '',
    );
  }
}

/// A team with its list of unregistered (unlinked) member slots.
class PreregTeam {
  final String teamId;
  final String teamName;
  final String teamColor;
  final List<PreregMember> unregisteredMembers;

  PreregTeam({
    required this.teamId,
    required this.teamName,
    required this.teamColor,
    required this.unregisteredMembers,
  });

  factory PreregTeam.fromJson(Map<String, dynamic> json) {
    return PreregTeam(
      teamId: json['team_id'] ?? '',
      teamName: json['team_name'] ?? '',
      teamColor: json['team_color'] ?? '#00E676',
      unregisteredMembers: (json['unregistered_members'] as List<dynamic>? ?? [])
          .map((m) => PreregMember.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasUnregisteredSlots => unregisteredMembers.isNotEmpty;
}

