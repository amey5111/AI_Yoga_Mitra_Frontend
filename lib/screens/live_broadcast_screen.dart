import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/live_api.dart';
import '../services/live_engine.dart';
import '../Widgets/video_grid.dart';
import 'lesson_plan_screen.dart';

/// Instructor side: broadcast video, watch the class practise, manage Q&A,
/// approve raised hands, start/stop cloud recording and end the class.
///
/// The stage shows every participant who is publishing video. In a group class
/// that is everybody from the moment they join; in a webinar it is the
/// instructor plus whoever they have brought on camera.
class LiveBroadcastScreen extends StatefulWidget {
  final Map<String, dynamic> liveClass;
  final bool autoGoLive;
  const LiveBroadcastScreen({
    super.key,
    required this.liveClass,
    this.autoGoLive = false,
  });

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  final LiveEngine _eng = LiveEngine();
  String _id = '';
  String _appId = '';
  int _myUid = 0;
  bool _starting = true;
  String? _error;
  bool _recording = false;
  bool _gridView = true;

  /// Whoever the instructor has tapped to enlarge. 0 means "no one pinned".
  int _spotlightUid = 0;

  String _stageMode = 'webinar';
  List _questions = [];
  List _hands = [];
  List _participants = [];

  /// Agora uid -> the person's name, so tiles are labelled properly.
  Map<int, String> _namesByUid = {};

  Timer? _poll;

  static const _green = Color(0xFF6C63FF); // app accent (purple)

  @override
  void initState() {
    super.initState();
    _id = widget.liveClass['_id']?.toString() ?? '';
    _stageMode = (widget.liveClass['stageMode'] ?? 'webinar').toString();
    _start();
  }

  Future<void> _start() async {
    try {
      await _eng.ensurePermissions();
      // The uid has to be known before going live: it is published with
      // go-live so viewers can tell which stream is the instructor's.
      final uid = await LiveApi.myUid();
      _myUid = uid;

      if (widget.autoGoLive || widget.liveClass['status'] == 'scheduled') {
        await LiveApi.goLive(_id, agoraUid: uid);
      }

      final tok = await LiveApi.getToken(_id, uid: uid, role: 'host');
      _appId = (tok['appId'] ?? '').toString();
      if (_appId.isEmpty) {
        setState(() {
          _error = 'Agora App ID is not set on the server yet.';
          _starting = false;
        });
        return;
      }
      _stageMode = (tok['stageMode'] ?? _stageMode).toString();

      await _eng.init(_appId);
      _eng.onChanged = () {
        if (mounted) setState(() {});
      };
      _eng.onFatal = (reason) {
        if (mounted) setState(() => _error = reason);
      };
      await _eng.join(
        token: (tok['token'] ?? '').toString(),
        channel: (tok['channelName'] ?? '').toString(),
        uid: uid,
        asHost: true,
      );
      if (!mounted) return;
      setState(() => _starting = false);
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
      _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not start the broadcast.';
        _starting = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final s = await LiveApi.getState(_id);
      if (!mounted) return;
      final people = (s['participants'] as List?) ?? [];
      setState(() {
        _questions = s['questions'] ?? [];
        _hands = s['raisedHands'] ?? [];
        _participants = people;
        _recording = s['isRecording'] == true;
        _stageMode = (s['stageMode'] ?? _stageMode).toString();
        _namesByUid = _buildNameMap(people);
      });
    } catch (_) {}
  }

  Map<int, String> _buildNameMap(List people) {
    final map = <int, String>{};
    for (final p in people) {
      final m = Map<String, dynamic>.from(p as Map);
      final uid = (m['agoraUid'] as num?)?.toInt() ?? 0;
      if (uid > 0) map[uid] = (m['userName'] ?? 'Guest').toString();
    }
    return map;
  }

  String _nameFor(int uid) => _namesByUid[uid] ?? 'Guest';

  /// Everyone currently on camera: the instructor first, then the room.
  List<VideoTileData> get _tiles {
    final tiles = <VideoTileData>[
      VideoTileData(
        uid: _myUid,
        name: 'You',
        isLocal: true,
        isInstructor: true,
        cameraOff: !_eng.camOn,
        muted: !_eng.micOn,
        speaking: _eng.localIsSpeaking,
      ),
      ..._eng.remoteUids.map(
        (uid) => VideoTileData(
          uid: uid,
          name: _nameFor(uid),
          cameraOff: _eng.isVideoOff(uid),
          muted: _eng.isMuted(uid),
          speaking: _eng.activeSpeakerUid == uid,
        ),
      ),
    ];
    return tiles;
  }

  Future<void> _toggleRecord() async {
    try {
      if (_recording) {
        await LiveApi.stopRecording(_id);
      } else {
        final r = await LiveApi.startRecording(_id);
        if (r['message'] != null && r['recording'] == null) {
          _snack(r['message'].toString());
        }
      }
      await _refresh();
    } catch (_) {
      _snack('Recording action failed.');
    }
  }

  Future<void> _end() async {
    try {
      await LiveApi.endClass(_id);
    } catch (_) {}
    await _eng.leave();
    if (mounted) Navigator.pop(context);
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  void _openLessonPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonPlanScreen(
          classId: _id,
          classTitle: (widget.liveClass['title'] ?? '').toString(),
        ),
      ),
    );
  }

  void _openPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text('People (${_participants.length})',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (_participants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No one has joined yet.'),
              ),
            ..._participants.map((p) {
              final m = Map<String, dynamic>.from(p);
              final onStage = m['onStage'] == true;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEDE9FF),
                  child: Text(
                    (m['userName'] ?? 'G')
                        .toString()
                        .characters
                        .first
                        .toUpperCase(),
                    style: const TextStyle(color: _green),
                  ),
                ),
                title: Text(m['userName'] ?? 'Guest'),
                subtitle: onStage ? const Text('On camera') : null,
                trailing: _stageMode == 'group'
                    ? null
                    : TextButton(
                        onPressed: () async {
                          if (onStage) {
                            await LiveApi.lowerHand(
                                _id, m['userId'].toString());
                          } else {
                            await LiveApi.approveHand(
                                _id, m['userId'].toString());
                          }
                          await _refresh();
                          if (mounted) Navigator.pop(context);
                        },
                        child: Text(onStage ? 'Take off' : 'On stage'),
                      ),
              );
            }),
            const Divider(height: 24),
            const Text('Raised hands',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (_hands.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No raised hands.'),
              ),
            ..._hands.map((h) {
              final m = Map<String, dynamic>.from(h);
              final approved = m['approved'] == true;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.pan_tool_alt, color: _green),
                title: Text(m['userName'] ?? 'Guest'),
                trailing: approved
                    ? TextButton(
                        onPressed: () async {
                          await LiveApi.lowerHand(_id, m['userId'].toString());
                          await _refresh();
                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text('Remove'),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white),
                        onPressed: () async {
                          await LiveApi.approveHand(
                              _id, m['userId'].toString());
                          await _refresh();
                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text('Allow'),
                      ),
              );
            }),
            const Divider(height: 24),
            const Text('Questions',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (_questions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No questions yet.'),
              ),
            ..._questions.map((q) {
              final m = Map<String, dynamic>.from(q);
              final answered = m['answered'] == true;
              return ListTile(
                dense: true,
                leading: Icon(
                  answered ? Icons.check_circle : Icons.help_outline,
                  color: answered ? Colors.green : Colors.orange,
                ),
                title: Text(m['text'] ?? ''),
                subtitle: Text(m['userName'] ?? 'Guest'),
                trailing: answered
                    ? null
                    : TextButton(
                        onPressed: () async {
                          await LiveApi.answerQuestion(
                              _id, m['_id'].toString());
                          await _refresh();
                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text('Mark done'),
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _eng.leave();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _starting
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  )
                : _live(),
      ),
    );
  }

  Widget _live() {
    return Stack(
      children: [
        Positioned.fill(child: _stage()),
        Positioned(top: 8, left: 12, right: 12, child: _header()),
        Positioned(left: 0, right: 0, bottom: 12, child: _controls()),
      ],
    );
  }

  /* ── stage ──────────────────────────────────────────────────────────────── */

  Widget _stage() {
    final engine = _eng.engine;
    if (engine == null) return const SizedBox.shrink();

    final tiles = _tiles;

    // In a webinar with nobody brought up yet, the instructor's own camera
    // fills the screen — a one-tile grid would just be the same view with a
    // border around it.
    final soloWebinar = _eng.remoteUids.isEmpty;
    if (soloWebinar) {
      return Stack(
        children: [
          Positioned.fill(
            child: VideoTile(
              engine: engine,
              channelId: _eng.channel,
              tile: tiles.first,
              large: true,
            ),
          ),
          if (_stageMode != 'group')
            Positioned(
              left: 16,
              right: 16,
              bottom: 112,
              child: _hint(
                'Students are watching. Bring someone on camera from the '
                'People panel to see them here.',
              ),
            ),
        ],
      );
    }

    if (_gridView && _spotlightUid == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 52, bottom: 96),
        child: VideoGrid(
          engine: engine,
          channelId: _eng.channel,
          tiles: tiles,
          onTapTile: (t) => setState(() => _spotlightUid = t.uid),
        ),
      );
    }

    // Spotlight: one large tile with the rest along the bottom.
    final spotlight = tiles.firstWhere(
      (t) => t.uid == _spotlightUid,
      orElse: () => tiles.first,
    );
    final others = tiles.where((t) => t.uid != spotlight.uid).toList();

    return Column(
      children: [
        Expanded(
          child: VideoTile(
            engine: engine,
            channelId: _eng.channel,
            tile: spotlight,
            large: true,
            onTap: () => setState(() {
              _spotlightUid = 0;
              _gridView = true;
            }),
          ),
        ),
        if (others.isNotEmpty)
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              itemCount: others.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) => SizedBox(
                width: 78,
                child: VideoTile(
                  engine: engine,
                  channelId: _eng.channel,
                  tile: others[i],
                  onTap: () => setState(() => _spotlightUid = others[i].uid),
                ),
              ),
            ),
          ),
        const SizedBox(height: 88),
      ],
    );
  }

  Widget _hint(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /* ── chrome ─────────────────────────────────────────────────────────────── */

  Widget _header() {
    final joinCode = (widget.liveClass['joinCode'] ?? '').toString();
    return Row(
      children: [
        _tag('LIVE', Colors.red),
        if (_recording) ...[
          const SizedBox(width: 6),
          _tag('REC', Colors.black87),
        ],
        if (_stageMode == 'group') ...[
          const SizedBox(width: 6),
          _tag('GROUP', _green),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.liveClass['title'] ?? 'Live class',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        if (joinCode.isNotEmpty)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: joinCode));
              _snack('Join code copied');
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: _green, borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(joinCode,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy, color: Colors.white, size: 12),
                ],
              ),
            ),
          ),
        if (_eng.remoteUids.isNotEmpty)
          IconButton(
            tooltip: _gridView ? 'Spotlight view' : 'Grid view',
            icon: Icon(
              _gridView ? Icons.person_rounded : Icons.grid_view_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => setState(() {
              _gridView = !_gridView;
              _spotlightUid = 0;
            }),
          ),
      ],
    );
  }

  Widget _controls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ctrl(_eng.micOn ? Icons.mic : Icons.mic_off, 'Mic', _eng.toggleMic),
        _ctrl(_eng.camOn ? Icons.videocam : Icons.videocam_off, 'Cam',
            _eng.toggleCam),
        _ctrl(Icons.cameraswitch, 'Flip', _eng.switchCamera),
        _ctrl(Icons.menu_book_rounded, 'Plan', _openLessonPlan),
        _ctrl(
          _recording ? Icons.stop_circle : Icons.fiber_manual_record,
          _recording ? 'Stop' : 'Record',
          _toggleRecord,
          color: Colors.red,
        ),
        Stack(
          children: [
            _ctrl(Icons.forum, 'People', _openPanel),
            if (_hands.isNotEmpty)
              Positioned(
                right: 6,
                top: 0,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: Colors.red,
                  child: Text('${_hands.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10)),
                ),
              ),
          ],
        ),
        _ctrl(Icons.call_end, 'End', _end, color: Colors.red),
      ],
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
        child: Text(t,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );

  Widget _ctrl(IconData icon, String label, VoidCallback onTap,
      {Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white12,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}
