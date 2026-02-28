import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// HTTP client for the BREACH GATE backend API.
class ApiService {
  // Change this to your server IP/domain
  static String baseUrl = 'http://10.0.2.2:8000/api';

  String? _authToken;

  /// Load saved auth token from SharedPreferences.
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
  }

  /// Save auth token to SharedPreferences.
  Future<void> _saveToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// Clear saved auth token.
  Future<void> clearToken() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  bool get isLoggedIn => _authToken != null && _authToken!.isNotEmpty;

  /// Build headers with auth token.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null) 'Authorization': 'Token $_authToken',
      };

  // ──────────────────────────────────────────────
  //  AUTH
  // ──────────────────────────────────────────────

  /// POST /api/login/ — Authenticate and get token.
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['status'] == 'success') {
        await _saveToken(data['token']);
        return data;
      }

      return {
        'status': 'error',
        'message': data['message'] ?? 'Login failed',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: Could not connect to server.\n$e',
      };
    }
  }

  // ──────────────────────────────────────────────
  //  SCAN
  // ──────────────────────────────────────────────

  /// POST /api/scan/ — Lookup participant by NFC UID.
  Future<Map<String, dynamic>> scanUid(String uid) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/scan/'),
        headers: _headers,
        body: jsonEncode({'uid': uid}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: Could not connect to server.\n$e',
      };
    }
  }

  // ──────────────────────────────────────────────
  //  INDIVIDUAL DISTRIBUTION
  // ──────────────────────────────────────────────

  /// Generic distribution request.
  Future<DistributionResponse> _distribute(String endpoint, String uid) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint/'),
        headers: _headers,
        body: jsonEncode({'uid': uid}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return DistributionResponse.fromJson(data);
    } catch (e) {
      return DistributionResponse(
        status: 'error',
        message: 'Network error: Could not connect to server.',
      );
    }
  }

  Future<DistributionResponse> giveRegistration(String uid) =>
      _distribute('give-registration', uid);

  Future<DistributionResponse> giveBreakfast(String uid) =>
      _distribute('give-breakfast', uid);

  Future<DistributionResponse> giveLunch(String uid) =>
      _distribute('give-lunch', uid);

  Future<DistributionResponse> giveSnacks(String uid) =>
      _distribute('give-snacks', uid);

  Future<DistributionResponse> giveDinner(String uid) =>
      _distribute('give-dinner', uid);

  Future<DistributionResponse> giveMidnightSnacks(String uid) =>
      _distribute('give-midnight-snacks', uid);

  // ──────────────────────────────────────────────
  //  TEAM ENDPOINTS
  // ──────────────────────────────────────────────

  /// GET /api/team/<teamId>/ — Get full team details with members and progress.
  Future<TeamDetails?> getTeamDetails(String teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/team/$teamId/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return TeamDetails.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// POST /api/distribute-team/ — Bulk distribute an item to all team members.
  Future<TeamDistributionResponse> distributeToTeam(
      String teamId, String item) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/distribute-team/'),
        headers: _headers,
        body: jsonEncode({'team_id': teamId, 'item': item}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TeamDistributionResponse.fromJson(data);
    } catch (e) {
      return TeamDistributionResponse(
        status: 'error',
        message: 'Network error: Could not connect to server.',
        distributed: [],
        alreadyCollected: [],
      );
    }
  }

  // ──────────────────────────────────────────────
  //  DASHBOARD & STATS
  // ──────────────────────────────────────────────

  /// GET /api/stats/ — Get dashboard statistics.
  Future<DashboardStats?> getDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return DashboardStats.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/teams/stats/ — Get team-level statistics and leaderboard.
  Future<Map<String, dynamic>?> getTeamsStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teams/stats/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ──────────────────────────────────────────────
  //  ATTENDEES
  // ──────────────────────────────────────────────

  /// GET /api/attendees/ — Get attendee list with optional search/filter/view.
  Future<Map<String, dynamic>?> getAttendees({
    String? search,
    String? filter,
    String view = 'individual',
  }) async {
    try {
      final queryParams = <String, String>{
        'view': view,
        if (search != null && search.isNotEmpty) 'search': search,
        if (filter != null && filter.isNotEmpty) 'filter': filter,
      };

      final uri = Uri.parse('$baseUrl/attendees/')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ──────────────────────────────────────────────
  //  CONFIG
  // ──────────────────────────────────────────────

  /// Update base URL (for settings screen).
  static void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  // ──────────────────────────────────────────────
  //  PRE-REGISTRATION
  // ──────────────────────────────────────────────

  /// GET /api/prereg/teams/ — Fetch all teams with unlinked member slots.
  Future<List<PreregTeam>> getPreregTeams() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/prereg/teams/'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((t) => PreregTeam.fromJson(t as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// POST /api/prereg/register/ — Link NFC UID to a pre-registered member slot.
  /// Returns the created Participant data map on success or an error map.
  Future<Map<String, dynamic>> registerNfcTag(
      String uid, int preregMemberId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/prereg/register/'),
        headers: _headers,
        body: jsonEncode({'uid': uid, 'prereg_member_id': preregMemberId}),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: Could not connect to server.\n$e',
      };
    }
  }

  /// POST /api/prereg/teams/create/ — Create a new team from the app.
  Future<Map<String, dynamic>> createPreregTeam({
    required String teamId,
    required String teamName,
    required String teamColor,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/prereg/teams/create/'),
        headers: _headers,
        body: jsonEncode({
          'team_id': teamId,
          'team_name': teamName,
          'team_color': teamColor,
        }),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: Could not connect to server.\n$e',
      };
    }
  }

  /// POST /api/prereg/teams/<teamId>/add-member/ — Add a member slot to a team.
  Future<Map<String, dynamic>> addPreregMember({
    required String teamId,
    required String name,
    required String college,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/prereg/teams/$teamId/add-member/'),
        headers: _headers,
        body: jsonEncode({'name': name, 'college': college}),
      );
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Network error: Could not connect to server.\n$e',
      };
    }
  }
}

