import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// HTTP client for the NFC event backend API.
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

  /// Update base URL (for settings screen).
  static void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
