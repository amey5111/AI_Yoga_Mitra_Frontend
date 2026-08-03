import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/live_api.dart';
import 'live_broadcast_screen.dart';
import 'live_watch_screen.dart';
import 'recorded_replay_screen.dart';

/// The Live Training hub: Live now, Upcoming and Recorded classes.
class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key});

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> {
  bool _loading = true;
  String? _error;
  String _myId = '';
  List _live = [];
  List _upcoming = [];
  List _recorded = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await SharedPreferences.getInstance();
      _myId = p.getString('userId') ?? '';
      final feed = await LiveApi.feed();
      setState(() {
        _live = feed['live'] ?? [];
        _upcoming = feed['upcoming'] ?? [];
        _recorded = feed['recorded'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load classes.';
        _loading = false;
      });
    }
  }

  bool _isMine(Map c) => (c['instructorId'] ?? '') == _myId;

  void _open(Map c) {
    final status = c['status'];
    if (status == 'live') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _isMine(c)
              ? LiveBroadcastScreen(liveClass: Map<String, dynamic>.from(c))
              : LiveWatchScreen(liveClass: Map<String, dynamic>.from(c)),
        ),
      ).then((_) => _load());
    } else if (status == 'ended') {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Training'),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                    children: [
                      _section('Live now', _live, live: true),
                      _section('Upcoming', _upcoming),
                      _section('Recorded', _recorded, recorded: true),
                      if (_live.isEmpty &&
                          _upcoming.isEmpty &&
                          _recorded.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text('No classes yet. Tap New class.'),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _section(String title, List items,
      {bool live = false, bool recorded = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(
            children: [
              if (live)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.circle, color: Colors.red, size: 10),
                ),
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        ...items.map((c) => _card(Map<String, dynamic>.from(c),
            live: live, recorded: recorded)),
      ],
    );
  }

  Widget _card(Map<String, dynamic> c,
      {bool live = false, bool recorded = false}) {
    final mine = _isMine(c);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
            color: live ? Colors.red : const Color(0xFF6C63FF),
          ),
        ),
        title: Text(c['title'] ?? 'Class',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            c['instructorName'] ?? 'Instructor',
            if (live) '${c['attendeesCount'] ?? 0} watching',
            if (!live && !recorded) _fmt(c['scheduledAt']),
          ].where((e) => e.toString().isNotEmpty).join('  •  '),
        ),
        trailing: live
            ? _pill('LIVE', Colors.red)
            : recorded
                ? const Icon(Icons.chevron_right)
                : (mine
                    ? _pill('Go live', const Color(0xFF6C63FF))
                    : const Icon(Icons.chevron_right)),
        onTap: () {
          if (!live && !recorded && mine) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    LiveBroadcastScreen(liveClass: c, autoGoLive: true),
              ),
            ).then((_) => _load());
          } else {
            _open(c);
          }
        },
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );

  String _fmt(dynamic iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso.toString());
    if (d == null) return '';
    final local = d.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ap = local.hour < 12 ? 'AM' : 'PM';
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}  $h:$m $ap';
  }
}
