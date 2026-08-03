import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// REST client for the in-app Live Training feature (Agora based).
/// Mirrors the /api/live endpoints on the Yoga Mitra backend.
class LiveApi {
  static String get _base => ApiService.baseUrl;

  static Future<Map<String, String>> currentUser() async {
    final p = await SharedPreferences.getInstance();
    return {
      'userId': p.getString('userId') ?? '',
      'userName': p.getString('name') ?? 'Guest',
    };
  }

  static Future<int> myUid() async {
    // A stable numeric Agora uid derived from the stored userId.
    final p = await SharedPreferences.getInstance();
    final id = p.getString('userId') ?? '';
    if (id.isEmpty) return DateTime.now().millisecondsSinceEpoch % 100000 + 1;
    int h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (h % 900000) + 1000; // 1000..900999
  }

  // ---- classes ----
  static Future<Map<String, dynamic>> createClass({
    required String title,
    String description = '',
    DateTime? scheduledAt,
    bool goLiveNow = false,
  }) async {
    final u = await currentUser();
    final resp = await http.post(
      Uri.parse('$_base/live'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'instructorId': u['userId'],
        'instructorName': u['userName'],
        'scheduledAt': scheduledAt?.toIso8601String(),
        'goLiveNow': goLiveNow,
      }),
    );
    final data = jsonDecode(resp.body);
    if (resp.statusCode == 201) {
      return Map<String, dynamic>.from(data['liveClass']);
    }
    throw Exception(data['message'] ?? 'Could not create class');
  }

  static Future<Map<String, dynamic>> feed() async {
    final resp = await http.get(Uri.parse('$_base/live/feed'));
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body));
    }
    throw Exception('Could not load classes');
  }

  static Future<Map<String, dynamic>> getState(String id) async {
    final resp = await http.get(Uri.parse('$_base/live/$id/state'));
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body));
    }
    throw Exception('Could not load state');
  }

  static Future<Map<String, dynamic>> getToken(
    String id, {
    required int uid,
    required String role, // host | audience
  }) async {
    final resp = await http.get(
      Uri.parse('$_base/live/$id/token?uid=$uid&role=$role'),
    );
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body));
    }
    throw Exception('Could not get token');
  }

  static Future<void> goLive(String id) async {
    await http.post(Uri.parse('$_base/live/$id/go-live'));
  }

  static Future<Map<String, dynamic>> endClass(String id) async {
    final resp = await http.post(Uri.parse('$_base/live/$id/end'));
    final data = jsonDecode(resp.body);
    return Map<String, dynamic>.from(data['liveClass'] ?? {});
  }

  static Future<void> join(String id) async {
    final u = await currentUser();
    await http.post(
      Uri.parse('$_base/live/$id/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': u['userId'], 'userName': u['userName']}),
    );
  }

  static Future<void> leave(String id) async {
    final u = await currentUser();
    await http.post(
      Uri.parse('$_base/live/$id/leave'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': u['userId']}),
    );
  }

  static Future<void> postAttendance(String id, int minutes) async {
    final u = await currentUser();
    await http.post(
      Uri.parse('$_base/live/$id/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': u['userId'], 'minutes': minutes}),
    );
  }

  static Future<Map<String, dynamic>> userHistory(String userId) async {
    final resp = await http.get(Uri.parse('$_base/live/user/$userId/history'));
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body));
    }
    return {'items': [], 'totalSessions': 0, 'totalMinutes': 0};
  }

  // ---- Q&A ----
  static Future<void> postQuestion(String id, String text) async {
    final u = await currentUser();
    await http.post(
      Uri.parse('$_base/live/$id/questions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': u['userId'],
        'userName': u['userName'],
        'text': text,
      }),
    );
  }

  static Future<void> answerQuestion(String id, String qid) async {
    await http.post(Uri.parse('$_base/live/$id/questions/$qid/answer'));
  }

  // ---- raise hand / roles ----
  static Future<void> raiseHand(String id) async {
    final u = await currentUser();
    await http.post(
      Uri.parse('$_base/live/$id/raise-hand'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': u['userId'], 'userName': u['userName']}),
    );
  }

  static Future<void> approveHand(String id, String userId) async {
    await http.post(
      Uri.parse('$_base/live/$id/approve-hand'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }

  static Future<void> lowerHand(String id, String userId) async {
    await http.post(
      Uri.parse('$_base/live/$id/lower-hand'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
  }

  // ---- recording ----
  static Future<Map<String, dynamic>> startRecording(String id) async {
    final resp = await http.post(Uri.parse('$_base/live/$id/recording/start'));
    return Map<String, dynamic>.from(jsonDecode(resp.body));
  }

  static Future<Map<String, dynamic>> stopRecording(String id) async {
    final resp = await http.post(Uri.parse('$_base/live/$id/recording/stop'));
    return Map<String, dynamic>.from(jsonDecode(resp.body));
  }

  // ---- instructor dashboard ----
  static Future<Map<String, dynamic>> instructorStats(
      String instructorId) async {
    final resp = await http
        .get(Uri.parse('$_base/live/instructor/$instructorId/stats'));
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body));
    }
    return {};
  }

  static Future<List> myClasses(String instructorId) async {
    final resp =
        await http.get(Uri.parse('$_base/live?instructorId=$instructorId'));
    if (resp.statusCode == 200) {
      return (jsonDecode(resp.body)['classes'] ?? []) as List;
    }
    return [];
  }
}
