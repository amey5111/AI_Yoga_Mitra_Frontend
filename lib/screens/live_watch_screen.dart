import 'dart:async';
import 'package:flutter/material.dart';
import '../services/live_api.dart';
import '../services/live_engine.dart';
import '../Widgets/video_grid.dart';
import 'lesson_plan_screen.dart';

/// Student side: watch the class, ask questions, and — in a group class, or
/// once the instructor approves a raised hand — be on camera too.
///
/// The instructor is identified by the hostUid the class publishes when it
/// goes live, not by whichever stream happens to arrive first, so the big tile
/// is always the teacher even when other students are on camera.
class LiveWatchScreen extends StatefulWidget {
  final Map<String, dynamic> liveClass;
  const LiveWatchScreen({super.key, required this.liveClass});

  @override
  State<LiveWatchScreen> createState() => _LiveWatchScreenState();
}

class _LiveWatchScreenState extends State<LiveWatchScreen> {
  final LiveEngine _eng = LiveEngine();
  final TextEditingController _qCtrl = TextEditingController();
  String _id = '';
  String _myId = '';
  int _uid = 0;
  String _appId = '';
  bool _starting = true;
  String? _error;
  String _status = 'live';
  String _stageMode = 'webinar';
  bool _isSpeaker = false;
  bool _handRaised = false;
  bool _gridView = false;

  int _hostUid = 0;
  String _instructorName = 'Instructor';
  Map<int, String> _namesByUid = {};

  List _questions = [];
  List _participants = [];
  DateTime? _joinedAt;
  Timer? _poll;

  static const _green = Color(0xFF6C63FF); // app accent (purple)

  /// True when this device is publishing video — either a group class, or the
  /// instructor brought us on stage.
  bool get _onCamera => _isSpeaker || _stageMode == 'group';

  @override
  void initState() {
    super.initState();
    _id = widget.liveClass['_id']?.toString() ?? '';
    _stageMode = (widget.liveClass['stageMode'] ?? 'webinar').toString();
    _start();
  }

  Future<void> _start() async {
    try {
      final u = await LiveApi.currentUser();
      _myId = u['userId'] ?? '';
      _uid = await LiveApi.myUid();

      // Tell the room who this uid belongs to, so our tile carries a name.
      await LiveApi.join(_id, agoraUid: _uid);

      // The server decides the role. Ask for host: in a group class it grants
      // it, in a webinar it hands back audience.
      final tok = await LiveApi.getToken(_id, uid: _uid, role: 'host');
      _appId = (tok['appId'] ?? '').toString();
      if (_appId.isEmpty) {
        setState(() {
          _error = 'Agora App ID is not set on the server yet.';
          _starting = false;
        });
        return;
      }

      _stageMode = (tok['stageMode'] ?? _stageMode).toString();
      _hostUid = (tok['hostUid'] as num?)?.toInt() ?? 0;
      final grantedHost = (tok['role'] ?? 'audience').toString() == 'host';

      if (grantedHost) await _eng.ensurePermissions();

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
        uid: _uid,
        asHost: grantedHost,
      );

      _isSpeaker = grantedHost && _stageMode != 'group';
      _joinedAt = DateTime.now();
      if (!mounted) return;
      setState(() {
        _starting = false;
        // Everyone on camera together is best seen as a grid.
        _gridView = _stageMode == 'group';
      });
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
      _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not join the class.';
        _starting = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final s = await LiveApi.getState(_id);
      if (!mounted) return;
      final speakers = (s['speakers'] ?? []).map((e) => e.toString()).toList();
      final amSpeaker = _myId.isNotEmpty && speakers.contains(_myId);
      final mode = (s['stageMode'] ?? _stageMode).toString();

      // Role changes only apply in a webinar; in a group class everyone is
      // already publishing.
      if (mode != 'group') {
        if (amSpeaker && !_isSpeaker) {
          await _promote();
        } else if (!amSpeaker && _isSpeaker) {
          await _demote();
        }
      }

      final people = (s['participants'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _questions = s['questions'] ?? [];
        _participants = people;
        _status = (s['status'] ?? 'live').toString();
        _stageMode = mode;
        _hostUid = (s['hostUid'] as num?)?.toInt() ?? _hostUid;
        _instructorName = (s['instructorName'] ?? _instructorName).toString();
        _namesByUid = _buildNameMap(people);
      });

      if (_status == 'ended') {
        _poll?.cancel();
        _showEnded();
      }
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

  String _nameFor(int uid) {
    if (uid == _hostUid && _hostUid != 0) return _instructorName;
    return _namesByUid[uid] ?? 'Guest';
  }

  /// The instructor's stream, when it has arrived.
  ///
  /// Falls back to the first remote publisher only for classes that went live
  /// before hostUid existed — otherwise the teacher is matched by uid.
  int? get _instructorUid {
    if (_hostUid != 0 && _eng.remoteUids.contains(_hostUid)) return _hostUid;
    if (_hostUid != 0) return null; // known host, not publishing yet
    return _eng.remoteUids.isNotEmpty ? _eng.remoteUids.first : null;
  }

  VideoTileData _tileFor(int uid) => VideoTileData(
        uid: uid,
        name: _nameFor(uid),
        isInstructor: uid == _hostUid && _hostUid != 0,
        cameraOff: _eng.isVideoOff(uid),
        muted: _eng.isMuted(uid),
        speaking: _eng.activeSpeakerUid == uid,
      );

  VideoTileData get _myTile => VideoTileData(
        uid: _uid,
        name: 'You',
        isLocal: true,
        cameraOff: !_eng.camOn,
        muted: !_eng.micOn,
        speaking: _eng.localIsSpeaking,
      );

  /// Everyone on camera, instructor first, with our own tile in place if we
  /// are publishing.
  List<VideoTileData> get _tiles {
    final host = _instructorUid;
    final tiles = <VideoTileData>[
      if (host != null) _tileFor(host),
      if (_onCamera) _myTile,
      ..._eng.remoteUids.where((u) => u != host).map(_tileFor),
    ];
    return tiles;
  }

  Future<void> _promote() async {
    try {
      await _eng.ensurePermissions();
      final tok = await LiveApi.getToken(_id, uid: _uid, role: 'host');
      await _eng.engine?.renewToken((tok['token'] ?? '').toString());
    } catch (_) {}
    await _eng.setHost(true);
    _isSpeaker = true;
  }

  Future<void> _demote() async {
    await _eng.setHost(false);
    _isSpeaker = false;
    _handRaised = false;
  }

  Future<void> _raiseHand() async {
    await LiveApi.raiseHand(_id);
    setState(() => _handRaised = true);
    _snack('Hand raised. Waiting for the instructor.');
  }

  Future<void> _leaveStage() async {
    await LiveApi.lowerHand(_id, _myId);
    await _demote();
    if (mounted) setState(() {});
  }

  Future<void> _sendQuestion() async {
    final text = _qCtrl.text.trim();
    if (text.isEmpty) return;
    _qCtrl.clear();
    await LiveApi.postQuestion(_id, text);
    await _refresh();
    _snack('Question sent.');
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

  void _showEnded() {
    if (!mounted) return;
    int stars = 0;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Class ended'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How was the class? Rate it:'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(i < stars ? Icons.star : Icons.star_border,
                        color: Colors.amber, size: 30),
                    onPressed: () => setLocal(() => stars = i + 1),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Grab the navigator before awaiting: the dialog's context is
                // not safe to use once the rating call has finished.
                final navigator = Navigator.of(context);
                if (stars > 0) await LiveApi.rateClass(_id, stars);
                if (!mounted) return;
                navigator.pop(); // the rating dialog
                navigator.pop(); // back out of the class
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _openQuestions() {
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
            const Text('Questions',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (_questions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No questions yet. Be the first to ask.'),
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
    _qCtrl.dispose();
    // Record how long I attended, then leave the room.
    final mins =
        _joinedAt == null ? 0 : DateTime.now().difference(_joinedAt!).inMinutes;
    LiveApi.postAttendance(_id, mins);
    LiveApi.leave(_id);
    _eng.leave();
    super.dispose();
  }

  void _openPeople() {
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
            Text('In this class (${_participants.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            if (_participants.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Just you for now.'),
              ),
            ..._participants.map((p) {
              final m = Map<String, dynamic>.from(p);
              final onStage = m['onStage'] == true;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEDE9FF),
                  child: Text(
                    (m['userName'] ?? 'G').toString().characters.first
                        .toUpperCase(),
                    style: const TextStyle(color: _green),
                  ),
                ),
                title: Text(m['userName'] ?? 'Guest'),
                trailing: onStage
                    ? const Chip(
                        label: Text('On camera',
                            style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      )
                    : null,
              );
            }),
          ],
        ),
      ),
    );
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
                : _watch(),
      ),
    );
  }

  Widget _watch() {
    return Stack(
      children: [
        Positioned.fill(child: _stage()),
        Positioned(top: 8, left: 12, right: 12, child: _header()),
        Positioned(left: 10, right: 10, bottom: 12, child: _bottomBar()),
      ],
    );
  }

  Widget _stage() {
    final engine = _eng.engine;
    if (engine == null) return const SizedBox.shrink();

    final tiles = _tiles;
    if (tiles.isEmpty) {
      return const Center(
        child: Text('Waiting for the instructor to start video...',
            style: TextStyle(color: Colors.white70)),
      );
    }

    if (_gridView) {
      return Padding(
        padding: const EdgeInsets.only(top: 50, bottom: 84),
        child: VideoGrid(
          engine: engine,
          channelId: _eng.channel,
          tiles: tiles,
          onTapTile: (_) => setState(() => _gridView = false),
        ),
      );
    }

    // Spotlight the instructor, with everyone else along the top.
    final main = tiles.first;
    final others = tiles.skip(1).toList();
    return Stack(
      children: [
        Positioned.fill(
          child: VideoTile(
            engine: engine,
            channelId: _eng.channel,
            tile: main,
            large: true,
            onTap: others.isEmpty
                ? null
                : () => setState(() => _gridView = true),
          ),
        ),
        if (others.isNotEmpty)
          Positioned(
            top: 46,
            right: 10,
            child: SizedBox(
              width: 92,
              height: 340,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: others.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, i) => SizedBox(
                  height: 118,
                  child: VideoTile(
                    engine: engine,
                    channelId: _eng.channel,
                    tile: others[i],
                    onTap: () => setState(() => _gridView = true),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: Colors.red, borderRadius: BorderRadius.circular(6)),
          child: const Text('LIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
        if (_stageMode == 'group') ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: _green, borderRadius: BorderRadius.circular(6)),
            child: const Text('GROUP',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: Text(widget.liveClass['title'] ?? 'Live class',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ),
        if (_tiles.length > 1)
          IconButton(
            tooltip: _gridView ? 'Spotlight view' : 'Grid view',
            icon: Icon(
              _gridView ? Icons.person_rounded : Icons.grid_view_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
      ],
    );
  }

  Widget _bottomBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _qCtrl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendQuestion(),
              decoration: InputDecoration(
                hintText: 'Ask a question',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: _green),
                  onPressed: _sendQuestion,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          style: IconButton.styleFrom(backgroundColor: Colors.white24),
          tooltip: 'Lesson plan',
          icon: const Icon(Icons.menu_book_rounded, color: Colors.white),
          onPressed: _openLessonPlan,
        ),
        Stack(
          children: [
            IconButton(
              style: IconButton.styleFrom(backgroundColor: Colors.white24),
              icon: const Icon(Icons.people, color: Colors.white),
              onPressed: _openPeople,
            ),
            if (_participants.isNotEmpty)
              Positioned(
                right: 4,
                top: 2,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: _green,
                  child: Text('${_participants.length}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10)),
                ),
              ),
          ],
        ),
        IconButton(
          style: IconButton.styleFrom(backgroundColor: Colors.white24),
          icon: const Icon(Icons.forum, color: Colors.white),
          onPressed: _openQuestions,
        ),
        const SizedBox(width: 4),
        // Whenever we are publishing, our own mic and camera are ours to
        // control — in a group class that is from the moment we joined.
        if (_onCamera) ...[
          IconButton(
            style: IconButton.styleFrom(backgroundColor: Colors.white24),
            icon: Icon(_eng.micOn ? Icons.mic : Icons.mic_off,
                color: _eng.micOn ? Colors.white : Colors.red),
            onPressed: () => _eng.toggleMic(),
          ),
          IconButton(
            style: IconButton.styleFrom(backgroundColor: Colors.white24),
            icon: Icon(_eng.camOn ? Icons.videocam : Icons.videocam_off,
                color: _eng.camOn ? Colors.white : Colors.red),
            onPressed: () => _eng.toggleCam(),
          ),
          const SizedBox(width: 4),
        ],
        // Raising a hand only means something in a webinar.
        if (_stageMode != 'group')
          if (_isSpeaker)
            FloatingActionButton.small(
              heroTag: 'stage',
              backgroundColor: Colors.red,
              onPressed: _leaveStage,
              child: const Icon(Icons.pan_tool, color: Colors.white),
            )
          else
            FloatingActionButton.small(
              heroTag: 'raise',
              backgroundColor: _handRaised ? Colors.orange : _green,
              onPressed: _handRaised ? null : _raiseHand,
              child: const Icon(Icons.pan_tool_alt, color: Colors.white),
            ),
      ],
    );
  }
}
