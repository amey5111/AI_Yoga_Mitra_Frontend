import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // static const String baseUrl = 'http://10.10.127.165:5000/api';
  // static const String rootUrl = 'http://10.10.127.165:5000';

  static const String baseUrl = 'https://yoga-mitra-backend.onrender.com/api';
  static const String rootUrl = 'https://yoga-mitra-backend.onrender.com/';

  // ── Deep convert any nested structure to plain Dart maps/lists ────────────
  static dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (e) => MapEntry(e.key.toString(), _deepConvert(e.value)),
        ),
      );
    } else if (value is List) {
      return value.map(_deepConvert).toList();
    }
    return value;
  }

  /* ---------------------------------------------------------
    Sign Up
  ---------------------------------------------------------- */
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String ageGroup,
    String gender,
  ) async {
    final resp = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "ageGroup": ageGroup,
        "gender": gender,
      }),
    );
    final data = jsonDecode(resp.body);
    if (resp.statusCode == 201) return data;
    throw Exception(data["message"]);
  }

  /* ---------------------------------------------------------
     Login
  ---------------------------------------------------------- */
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final resp = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    final data = jsonDecode(resp.body);
    if (resp.statusCode == 200) return data;
    throw Exception(data["message"]);
  }

  /* ---------------------------------------------------------
     IMAGE URL RESOLVER
  ---------------------------------------------------------- */
  static String resolveImageUrl(String? url) {
    if (url == null || url.isEmpty) return "";
    if (url.startsWith("http")) return url;
    return "$rootUrl$url";
  }

  /* ---------------------------------------------------------
     POSES
  ---------------------------------------------------------- */
  static Future<List<dynamic>> fetchAllPoses() async {
    final resp = await http.get(Uri.parse('$baseUrl/poses'));
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to fetch poses');
  }

  static Future<Map<String, dynamic>> fetchPoseById(int id) async {
    final resp = await http.get(Uri.parse('$baseUrl/poses/$id'));
    if (resp.statusCode == 200) {
      return _deepConvert(jsonDecode(resp.body)) as Map<String, dynamic>;
    }
    throw Exception('Pose not found');
  }

  /* ---------------------------------------------------------
     BREATHING
  ---------------------------------------------------------- */
  static Future<Map<String, dynamic>?> fetchBreathingById(int id) async {
    final resp = await http.get(Uri.parse('$baseUrl/breathing/$id'));
    if (resp.statusCode == 200) {
      return _deepConvert(jsonDecode(resp.body)) as Map<String, dynamic>;
    }
    return null;
  }

  /* ---------------------------------------------------------
     RECOMMENDATIONS
  ---------------------------------------------------------- */
  static Future<List<dynamic>> recommend(
    dynamic userProfile,
    dynamic healthInfo,
    dynamic goals,
    String userId,
  ) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/recommendations/recommend'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userProfile': userProfile ?? {},
        'healthInfo': healthInfo ?? {},
        'goals': goals ?? {},
        'userId': userId,
      }),
    );
    if (resp.statusCode == 200) {
      final parsed = jsonDecode(resp.body);
      if (parsed is Map && parsed['recommendations'] != null) {
        return parsed['recommendations'];
      }
      return [];
    }
    return [];
  }

  /* ---------------------------------------------------------
     ROUTINE GENERATOR
  ---------------------------------------------------------- */
  static Future<Map<String, dynamic>?> generateRoutine(
    List<int> poseIds,
    List<int> breathingIds,
    int duration,
    String userId,
  ) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/routine/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "poseIds": poseIds,
        "breathingIds": breathingIds,
        "duration": duration,
        "userId": userId,
      }),
    );
    if (resp.statusCode == 200) {
      return _deepConvert(jsonDecode(resp.body)) as Map<String, dynamic>;
    }
    return null;
  }

  /* ---------------------------------------------------------
     FETCH USER ROUTINE + SAVED RECOMMENDATIONS
  ---------------------------------------------------------- */
  static Future<Map<String, dynamic>?> fetchUserRoutine(String userId) async {
    final resp = await http.get(Uri.parse('$baseUrl/routine/user/$userId'));
    if (resp.statusCode == 200) {
      final raw = jsonDecode(resp.body);
      if (raw != null) {
        // Deep convert ensures all nested maps are Map<String, dynamic>
        return _deepConvert(raw) as Map<String, dynamic>;
      }
    }
    return null;
  }

  /* ---------------------------------------------------------
     UPDATE USER ROUTINE
  ---------------------------------------------------------- */
  static Future<Map<String, dynamic>?> updateUserRoutine(
    String userId,
    List<int> poseIds,
    List<int> breathingIds,
  ) async {
    final resp = await http.put(
      Uri.parse('$baseUrl/routine/user/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "userId": userId,
        "poseIds": poseIds,
        "breathingIds": breathingIds,
      }),
    );
    if (resp.statusCode == 200) {
      return _deepConvert(jsonDecode(resp.body)) as Map<String, dynamic>;
    }
    return null;
  }

  /* ---------------------------------------------------------
     SESSION MANAGEMENT
  ---------------------------------------------------------- */
  static Future<void> saveSession(
    String userId,
    String name,
    String email,
    String ageGroup,
    String gender,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("userId", userId);
    await prefs.setString("name", name);
    await prefs.setString("email", email);
    await prefs.setString("ageGroup", ageGroup);
    await prefs.setString("gender", gender);
  }

  static Future<Map<String, String>?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");
    if (userId == null) return null;
    return {
      "userId": userId,
      "name": prefs.getString("name") ?? "",
      "email": prefs.getString("email") ?? "",
      "ageGroup": prefs.getString("ageGroup") ?? "",
      "gender": prefs.getString("gender") ?? "",
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
