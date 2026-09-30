import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// REST client for the admin / recruiter console (/api/admin).
/// Every call carries the admin's own userId; the server enforces isAdmin.
class AdminApi {
  static String get _base => ApiService.baseUrl;

  static Future<String> _adminId() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('userId') ?? '';
  }

  /// Counters for the top of the console.
  static Future<Map<String, dynamic>> overview() async {
    final adminId = await _adminId();
    final resp = await http.get(
      Uri.parse('$_base/admin/overview').replace(
        queryParameters: {'adminId': adminId},
      ),
    );
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(resp.body));
    }
    return {};
  }

  /// All instructors with live/online status. [q] searches name/email/specialty.
  static Future<List<Map<String, dynamic>>> instructors({String q = ''}) async {
    final adminId = await _adminId();
    final params = {'adminId': adminId};
    if (q.trim().isNotEmpty) params['q'] = q.trim();
    final resp = await http.get(
      Uri.parse('$_base/admin/instructors').replace(queryParameters: params),
    );
    if (resp.statusCode == 200) {
      final list = (jsonDecode(resp.body)['instructors'] as List? ?? const []);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception(_msg(resp.body, 'Could not load instructors'));
  }

  /// Every class from every instructor. [q] searches title/instructor/code.
  static Future<List<Map<String, dynamic>>> classes({
    String q = '',
    String status = '',
  }) async {
    final adminId = await _adminId();
    final params = {'adminId': adminId};
    if (q.trim().isNotEmpty) params['q'] = q.trim();
    if (status.trim().isNotEmpty) params['status'] = status.trim();
    final resp = await http.get(
      Uri.parse('$_base/admin/classes').replace(queryParameters: params),
    );
    if (resp.statusCode == 200) {
      final list = (jsonDecode(resp.body)['classes'] as List? ?? const []);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    throw Exception(_msg(resp.body, 'Could not load classes'));
  }

  static String _msg(String body, String or) {
    try {
      final d = jsonDecode(body);
      if (d is Map && d['message'] != null) return '${d['message']}';
    } catch (_) {}
    return or;
  }
}
