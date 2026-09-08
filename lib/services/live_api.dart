import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/class_event.dart';
import '../models/lesson_material.dart';
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
    int durationMinutes = 60,
    bool goLiveNow = false,
    String visibility = 'public',
    String stageMode = 'webinar', // webinar | group
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
        // The server stores instants in UTC.
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
        'durationMinutes': durationMinutes,
        'goLiveNow': goLiveNow,
        'visibility': visibility,
        'stageMode': stageMode,
      }),
    );
    final data = jsonDecode(resp.body);
    if (resp.statusCode == 201) {
      return Map<String, dynamic>.from(data['liveClass']);
    }
    throw Exception(data['message'] ?? 'Could not create class');
  }

  /// Look up a class by its join code (for private classes).
  static Future<Map<String, dynamic>?> getByCode(String code) async {
    final resp = await http.get(
      Uri.parse('$_base/live/by-code/${code.trim().toUpperCase()}'),
    );
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body)['liveClass']);
    }
    return null;
  }

  static Future<Map<String, dynamic>> feed() async {
    final resp = await http.get(Uri.parse('$_base/live/feed'));
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body));
    }
    throw Exception('Could not load classes');
  }

  // ---- schedule calendar ----

  /// Classes inside one month, already bucketed into local days by the server.
  ///
  /// Pass [instructorId] for an instructor's own schedule (their private
  /// classes are included); leave it null to browse the public schedule.
  static Future<CalendarWindow> calendarMonth(
    DateTime month, {
    String? instructorId,
    String? viewerId,
    List<String> statuses = const [],
  }) async {
    final params = <String, String>{
      'month': monthKeyOf(month),
      // Day boundaries are drawn in the viewer's timezone, not UTC.
      'tzOffset': '${DateTime.now().timeZoneOffset.inMinutes}',
    };
    if (instructorId != null && instructorId.isNotEmpty) {
      params['instructorId'] = instructorId;
    }
    if (viewerId != null && viewerId.isNotEmpty) {
      params['viewerId'] = viewerId;
    }
    if (statuses.isNotEmpty) params['status'] = statuses.join(',');

    final resp = await http.get(
      Uri.parse('$_base/live/calendar').replace(queryParameters: params),
    );
    if (resp.statusCode == 200) {
      return CalendarWindow.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)),
      );
    }
    throw Exception(_messageOf(resp.body, 'Could not load the schedule'));
  }

  /// Move a scheduled class to a new slot, change its length, or both.
  static Future<void> reschedule(
    String id, {
    DateTime? scheduledAt,
    int? durationMinutes,
  }) async {
    final u = await currentUser();
    final body = <String, dynamic>{'instructorId': u['userId']};
    if (scheduledAt != null) {
      body['scheduledAt'] = scheduledAt.toUtc().toIso8601String();
    }
    if (durationMinutes != null) body['durationMinutes'] = durationMinutes;

    final resp = await http.patch(
      Uri.parse('$_base/live/$id/schedule'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      throw Exception(_messageOf(resp.body, 'Could not reschedule the class'));
    }
  }

  // ---- lesson plan ----

  /// The plan for a class. Passing the owner's id returns drafts too and sets
  /// [LessonPlan.isOwner], which is what unlocks editing in the UI.
  static Future<LessonPlan> lessonPlan(
    String classId, {
    String? instructorId,
  }) async {
    final params = <String, String>{};
    if (instructorId != null && instructorId.isNotEmpty) {
      params['instructorId'] = instructorId;
    }
    final resp = await http.get(
      Uri.parse('$_base/live/$classId/materials')
          .replace(queryParameters: params.isEmpty ? null : params),
    );
    if (resp.statusCode == 200) {
      return LessonPlan.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)),
      );
    }
    throw Exception(_messageOf(resp.body, 'Could not load the lesson plan'));
  }

  static Future<LessonMaterial> addMaterial(
    String classId, {
    required String kind,
    String title = '',
    String body = '',
    String url = '',
    int durationSeconds = 0,
    bool publishedToStudents = true,
  }) async {
    final u = await currentUser();
    final resp = await http.post(
      Uri.parse('$_base/live/$classId/materials'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'instructorId': u['userId'],
        'kind': kind,
        'title': title,
        'body': body,
        'url': url,
        'durationSeconds': durationSeconds,
        'publishedToStudents': publishedToStudents,
      }),
    );
    if (resp.statusCode == 201) {
      return LessonMaterial.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)['material']),
      );
    }
    throw Exception(_messageOf(resp.body, 'Could not add that'));
  }

  /// Send only what changed — anything omitted keeps its current value.
  static Future<LessonMaterial> updateMaterial(
    String classId,
    String materialId, {
    String? title,
    String? body,
    String? url,
    int? durationSeconds,
    bool? publishedToStudents,
  }) async {
    final u = await currentUser();
    final payload = <String, dynamic>{'instructorId': u['userId']};
    if (title != null) payload['title'] = title;
    if (body != null) payload['body'] = body;
    if (url != null) payload['url'] = url;
    if (durationSeconds != null) payload['durationSeconds'] = durationSeconds;
    if (publishedToStudents != null) {
      payload['publishedToStudents'] = publishedToStudents;
    }

    final resp = await http.patch(
      Uri.parse('$_base/live/$classId/materials/$materialId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (resp.statusCode == 200) {
      return LessonMaterial.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)['material']),
      );
    }
    throw Exception(_messageOf(resp.body, 'Could not save that change'));
  }

  static Future<void> deleteMaterial(String classId, String materialId) async {
    final u = await currentUser();
    final resp = await http.delete(
      Uri.parse('$_base/live/$classId/materials/$materialId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'instructorId': u['userId']}),
    );
    if (resp.statusCode != 200) {
      throw Exception(_messageOf(resp.body, 'Could not remove that'));
    }
  }

  static Future<List<LessonMaterial>> reorderMaterials(
    String classId,
    List<String> orderedIds,
  ) async {
    final u = await currentUser();
    final resp = await http.post(
      Uri.parse('$_base/live/$classId/materials/reorder'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'instructorId': u['userId'],
        'orderedIds': orderedIds,
      }),
    );
    if (resp.statusCode == 200) {
      return (jsonDecode(resp.body)['materials'] as List? ?? const [])
          .map((e) => LessonMaterial.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception(_messageOf(resp.body, 'Could not reorder the plan'));
  }

  /// Upload one audio/video/image/PDF straight into the plan.
  static Future<LessonMaterial> uploadMaterial(
    String classId, {
    required String filePath,
    String title = '',
  }) async {
    final u = await currentUser();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/live/$classId/materials/upload'),
    );
    request.fields['instructorId'] = u['userId'] ?? '';
    if (title.isNotEmpty) request.fields['title'] = title;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 201) {
      return LessonMaterial.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)['material']),
      );
    }
    throw Exception(_messageOf(resp.body, 'Could not upload that file'));
  }

  /// Pull the server's error message out of a response, falling back to [or].
  static String _messageOf(String body, String or) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return '${decoded['message']}';
      }
    } catch (_) {}
    return or;
  }

  static Future<Map<String, dynamic>> getState(String id) async {
    final resp = await http.get(Uri.parse('$_base/live/$id/state'));
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body));
    }
    throw Exception('Could not load state');
  }

  /// Ask for a channel token.
  ///
  /// [role] is a request, not a decision: the server grants a publishing role
  /// only to the instructor, to students it has put on stage, and to everyone
  /// in a group class. The `role` it returns is the one actually granted.
  static Future<Map<String, dynamic>> getToken(
    String id, {
    required int uid,
    required String role, // host | audience
  }) async {
    final u = await currentUser();
    final resp = await http.get(
      Uri.parse('$_base/live/$id/token').replace(queryParameters: {
        'uid': '$uid',
        'role': role,
        'viewerId': u['userId'] ?? '',
      }),
    );
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body));
    }
    throw Exception('Could not get token');
  }

  /// Start the class. [agoraUid] is published so viewers can tell the
  /// instructor's video stream apart from a student who is on camera.
  static Future<void> goLive(String id, {int? agoraUid}) async {
    await http.post(
      Uri.parse('$_base/live/$id/go-live'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'agoraUid': ?agoraUid}),
    );
  }

  static Future<Map<String, dynamic>> endClass(String id) async {
    final resp = await http.post(Uri.parse('$_base/live/$id/end'));
    final data = jsonDecode(resp.body);
    return Map<String, dynamic>.from(data['liveClass'] ?? {});
  }

  /// Enter the room. [agoraUid] maps this person to their video tile, so the
  /// grid can label it with a name instead of a number.
  static Future<void> join(String id, {int? agoraUid}) async {
    final u = await currentUser();
    await http.post(
      Uri.parse('$_base/live/$id/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': u['userId'],
        'userName': u['userName'],
        'agoraUid': ?agoraUid,
      }),
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

  static Future<void> cancelClass(String id) async {
    await http.delete(Uri.parse('$_base/live/$id'));
  }

  static Future<void> rateClass(String id, int stars) async {
    final u = await currentUser();
    await http.post(
      Uri.parse('$_base/live/$id/rate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': u['userId'], 'stars': stars}),
    );
  }

  // ---- instructor profile ----
  static Future<Map<String, dynamic>> getProfile(String userId) async {
    final resp = await http.get(Uri.parse('$_base/profile/$userId'));
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body));
    }
    return {};
  }

  static Future<void> saveProfile({
    String? bio,
    String? specialty,
    String? photo,
  }) async {
    final u = await currentUser();
    final body = <String, dynamic>{};
    if (bio != null) body['bio'] = bio;
    if (specialty != null) body['specialty'] = specialty;
    if (photo != null) body['photo'] = photo;
    await http.post(
      Uri.parse('$_base/profile/${u['userId']}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }
}
