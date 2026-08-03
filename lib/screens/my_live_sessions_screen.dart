import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/live_api.dart';

/// Normal-user history: the live classes they joined and how long they spent.
class MyLiveSessionsScreen extends StatefulWidget {
  const MyLiveSessionsScreen({super.key});

  @override
  State<MyLiveSessionsScreen> createState() => _MyLiveSessionsScreenState();
}

class _MyLiveSessionsScreenState extends State<MyLiveSessionsScreen> {
  static const _accent = Color(0xFF6C63FF);
  bool _loading = true;
  int _totalSessions = 0;
  int _totalMinutes = 0;
  List _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await SharedPreferences.getInstance();
    final uid = p.getString('userId') ?? '';
    try {
      final data = await LiveApi.userHistory(uid);
      _items = data['items'] ?? [];
      _totalSessions = (data['totalSessions'] ?? 0) as int;
      _totalMinutes = (data['totalMinutes'] ?? 0) as int;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _fmtTime(int m) => m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';

  String _fmtDate(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '');
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.day}/${l.month}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        title: const Text('My Live Sessions'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7B73E8), Color(0xFF5348C7)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _headStat('$_totalSessions', 'Sessions joined'),
                        Container(width: 1, height: 40, color: Colors.white24),
                        _headStat(_fmtTime(_totalMinutes), 'Total time'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('History',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text('You have not joined any live class yet.'),
                      ),
                    ),
                  ..._items.map((it) {
                    final m = Map<String, dynamic>.from(it);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEDE9FF),
                          child: Icon(Icons.videocam, color: _accent),
                        ),
                        title: Text(m['title'] ?? 'Live class',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          [
                            'with ${m['instructorName'] ?? 'Instructor'}',
                            _fmtDate(m['createdAt']),
                          ].where((e) => e.toString().isNotEmpty).join('  •  '),
                        ),
                        trailing: Text(
                          _fmtTime((m['minutes'] ?? 0) as int),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: _accent),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _headStat(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      );
}
