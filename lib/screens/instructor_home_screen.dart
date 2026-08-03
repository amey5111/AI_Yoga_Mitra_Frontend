import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/live_api.dart';
import '../services/api_service.dart';
import 'create_live_class_screen.dart';
import 'live_broadcast_screen.dart';
import 'recorded_replay_screen.dart';
import 'welcome_screen.dart';

/// The instructor experience. Completely separate from the normal user app:
/// a stats dashboard plus the instructor's own classes and a Go Live action.
class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({super.key});

  @override
  State<InstructorHomeScreen> createState() => _InstructorHomeScreenState();
}

class _InstructorHomeScreenState extends State<InstructorHomeScreen> {
  static const _green = Color(0xFF6C63FF); // app accent (purple)
  bool _loading = true;
  String _name = 'Instructor';
  String _id = '';
  Map<String, dynamic> _stats = {};
  List _classes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final p = await SharedPreferences.getInstance();
    _id = p.getString('userId') ?? '';
    _name = p.getString('name') ?? 'Instructor';
    try {
      final results = await Future.wait([
        LiveApi.instructorStats(_id),
        LiveApi.myClasses(_id),
      ]);
      _stats = results[0] as Map<String, dynamic>;
      _classes = results[1] as List;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateLiveClassScreen()),
    );
    _load();
  }

  Future<void> _logout() async {
    await ApiService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => WelcomeScreen()),
      (route) => false,
    );
  }

  void _openClass(Map<String, dynamic> c) {
    final status = c['status'];
    if (status == 'live' || status == 'scheduled') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveBroadcastScreen(
              liveClass: c, autoGoLive: status == 'scheduled'),
        ),
      ).then((_) => _load());
    } else if (status == 'ended' && (c['recordingUrl'] ?? '') != '') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordedReplayScreen(
            title: c['title'] ?? 'Recording',
            url: c['recordingUrl'] ?? '',
          ),
        ),
      );
    }
  }

  String _fmtTime(dynamic minutes) {
    final m = (minutes is num) ? minutes.round() : 0;
    if (m >= 60) return '${m ~/ 60}h ${m % 60}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Instructor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: Colors.red,
        icon: const Icon(Icons.sensors),
        label: const Text('Go Live / New class'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7B73E8), Color(0xFF5348C7)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.self_improvement,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Namaste, $_name',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                  const Text('Instructor',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Here is how your teaching is going.',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _statsGrid(),
                  const SizedBox(height: 22),
                  const Text('My Classes',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (_classes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                            'No classes yet. Tap Go Live to start your first.'),
                      ),
                    ),
                  ..._classes
                      .map((c) => _classCard(Map<String, dynamic>.from(c))),
                ],
              ),
            ),
    );
  }

  Widget _statsGrid() {
    final tiles = [
      _stat('Sessions taken', '${_stats['sessionsTaken'] ?? 0}',
          Icons.event_available, _green),
      _stat('Teaching time', _fmtTime(_stats['totalMinutes']),
          Icons.timer_outlined, Colors.indigo),
      _stat('Students reached', '${_stats['totalStudents'] ?? 0}',
          Icons.groups_2_outlined, Colors.teal),
      _stat('Recordings', '${_stats['recordings'] ?? 0}',
          Icons.video_library_outlined, Colors.deepOrange),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: tiles,
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 26),
          Text(value,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _classCard(Map<String, dynamic> c) {
    final status = c['status'] ?? 'scheduled';
    final live = status == 'live';
    final recorded = status == 'ended';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: live
              ? Colors.red.shade50
              : recorded
                  ? Colors.grey.shade200
                  : const Color(0xFFEDE9FF),
          child: Icon(
            live
                ? Icons.sensors
                : recorded
                    ? Icons.play_circle_fill
                    : Icons.schedule,
            color: live ? Colors.red : _green,
          ),
        ),
        title: Text(c['title'] ?? 'Class',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            status.toString().toUpperCase(),
            if ((c['attendeesCount'] ?? 0) != 0)
              '${c['attendeesCount']} students',
          ].join('  •  '),
        ),
        trailing: live
            ? _pill('LIVE', Colors.red)
            : (status == 'scheduled'
                ? _pill('Go live', _green)
                : const Icon(Icons.chevron_right)),
        onTap: () => _openClass(c),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
}
