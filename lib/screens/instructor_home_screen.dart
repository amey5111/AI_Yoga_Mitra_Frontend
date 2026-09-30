import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/live_api.dart';
import '../services/api_service.dart';
import 'create_live_class_screen.dart';
import 'instructor_profile_screen.dart';
import 'lesson_plan_screen.dart';
import 'live_broadcast_screen.dart';
import 'recorded_replay_screen.dart';
import 'schedule_calendar_screen.dart';
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
  Timer? _hb;

  @override
  void initState() {
    super.initState();
    _load();
    _startHeartbeat();
  }

  @override
  void dispose() {
    _hb?.cancel();
    super.dispose();
  }

  /// Ping presence now and every 90s so the admin console shows us online.
  Future<void> _startHeartbeat() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString('userId') ?? '';
    if (id.isEmpty) return;
    ApiService.heartbeat(id);
    _hb = Timer.periodic(
      const Duration(seconds: 90),
      (_) => ApiService.heartbeat(id),
    );
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

  Future<void> _openLessonPlan(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonPlanScreen(
          classId: c['_id']?.toString() ?? '',
          classTitle: c['title']?.toString() ?? '',
        ),
      ),
    );
    _load();
  }

  Future<void> _openSchedule() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ScheduleCalendarScreen(mode: ScheduleMode.instructor),
      ),
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
    } else {
      _showReport(c);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Code copied: $code')),
      );
    }
  }

  Future<void> _cancelClass(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel class?'),
        content: const Text('This removes the class permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (ok == true) {
      await LiveApi.cancelClass(id);
      _load();
    }
  }

  void _showReport(Map<String, dynamic> c) {
    final questions = (c['questions'] as List?)?.length ?? 0;
    final students = c['attendeesCount'] ?? 0;
    int mins = 0;
    final s = DateTime.tryParse(c['startedAt']?.toString() ?? '');
    final e = DateTime.tryParse(c['endedAt']?.toString() ?? '');
    if (s != null && e != null) mins = e.difference(s).inMinutes;
    final rec = (c['recordingUrl'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c['title'] ?? 'Class',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Class report',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            _reportRow(Icons.groups_2_outlined, 'Students reached', '$students'),
            _reportRow(Icons.forum_outlined, 'Questions asked', '$questions'),
            _reportRow(Icons.timer_outlined, 'Duration', '${mins}m'),
            _reportRow(Icons.videocam_outlined, 'Join code',
                (c['joinCode'] ?? '-').toString()),
            _reportRow(Icons.star_outline, 'Avg rating', _avgRating(c)),
            const SizedBox(height: 14),
            if (rec.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _green, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordedReplayScreen(
                            title: c['title'] ?? 'Recording', url: rec),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_circle),
                  label: const Text('Watch recording'),
                ),
              )
            else
              const Text('No recording for this class.',
                  style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  List<int> _weeklyBuckets() {
    final now = DateTime.now();
    final buckets = List<int>.filled(6, 0); // [0]=5 weeks ago ... [5]=this week
    for (final c in _classes) {
      final d =
          DateTime.tryParse((Map.from(c)['createdAt'] ?? '').toString());
      if (d == null) continue;
      final weeksAgo = now.difference(d).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < 6) buckets[5 - weeksAgo] += 1;
    }
    return buckets;
  }

  Widget _weeklyChart() {
    final b = _weeklyBuckets();
    final maxV = b.fold<int>(1, (m, v) => v > m ? v : m);
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          const Text('Activity (last 6 weeks)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                final h = 74.0 * b[i] / maxV;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${b[i]}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Container(
                      width: 26,
                      height: h < 4 ? 4 : h,
                      decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    const SizedBox(height: 4),
                    Text(i == 5 ? 'now' : '-${5 - i}w',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black45)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _avgRating(Map<String, dynamic> c) {
    final r = (c['ratings'] as List?) ?? [];
    if (r.isEmpty) return 'No ratings';
    final sum = r.fold<int>(
        0, (s, e) => s + ((Map.from(e)['stars'] ?? 0) as int));
    return '${(sum / r.length).toStringAsFixed(1)} ★ (${r.length})';
  }

  Widget _reportRow(IconData i, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(i, size: 20, color: _green),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

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
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'My schedule',
            onPressed: _openSchedule,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Edit profile',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const InstructorProfileScreen()),
              );
              _load();
            },
          ),
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
                  const SizedBox(height: 16),
                  _weeklyChart(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('My Classes',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: _openSchedule,
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: const Text('Calendar'),
                        style: TextButton.styleFrom(foregroundColor: _green),
                      ),
                    ],
                  ),
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
      _stat(
          'Students reached',
          '${_stats['uniqueStudents'] ?? _stats['totalStudents'] ?? 0}',
          Icons.groups_2_outlined,
          Colors.teal),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (live)
              _pill('LIVE', Colors.red)
            else if (status == 'scheduled')
              _pill('Go live', _green)
            else
              const Icon(Icons.chevron_right),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'copy') {
                  _copyCode(c['joinCode']?.toString() ?? '');
                } else if (v == 'plan') {
                  _openLessonPlan(c);
                } else if (v == 'cancel') {
                  _cancelClass(c['_id']?.toString() ?? '');
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'plan', child: Text('Lesson plan')),
                const PopupMenuItem(
                    value: 'copy', child: Text('Copy join code')),
                if (status != 'ended')
                  const PopupMenuItem(
                      value: 'cancel', child: Text('Cancel class')),
              ],
            ),
          ],
        ),
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
