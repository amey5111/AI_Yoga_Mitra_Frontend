import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/live_api.dart';
import '../services/live_engine.dart';

/// Audience side: watch the live class, ask questions in the Q&A, and raise a
/// hand to come on camera/mic once the instructor approves.
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
  bool _isSpeaker = false;
  bool _handRaised = false;
  List _questions = [];
  List _participants = [];
  DateTime? _joinedAt;
  Timer? _poll;

  static const _green = Color(0xFF6C63FF); // app accent (purple)

  @override
  void initState() {
    super.initState();
    _id = widget.liveClass['_id']?.toString() ?? '';
    _start();
  }

  Future<void> _start() async {
    try {
      final u = await LiveApi.currentUser();
      _myId = u['userId'] ?? '';
      await LiveApi.join(_id);
      _uid = await LiveApi.myUid();
      final tok = await LiveApi.getToken(_id, uid: _uid, role: 'audience');
      _appId = (tok['appId'] ?? '').toString();
      if (_appId.isEmpty) {
        setState(() {
          _error = 'Agora App ID is not set on the server yet.';
          _starting = false;
        });
        return;
      }
      await _eng.init(_appId);
      _eng.onChanged = () {
        if (mounted) setState(() {});
      };
      await _eng.join(
        token: (tok['token'] ?? '').toString(),
        channel: (tok['channelName'] ?? '').toString(),
        uid: _uid,
        asHost: false,
      );
      _joinedAt = DateTime.now();
      setState(() => _starting = false);
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    } catch (e) {
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

      if (amSpeaker && !_isSpeaker) {
        await _promote();
      } else if (!amSpeaker && _isSpeaker) {
        await _demote();
      }

      setState(() {
        _questions = s['questions'] ?? [];
        _participants = s['participants'] ?? [];
        _status = (s['status'] ?? 'live').toString();
      });

      if (_status == 'ended') {
        _poll?.cancel();
        _showEnded();
      }
    } catch (_) {}
  }

  Future<void> _promote() async {
    try {
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

  void _showEnded() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Class ended'),
        content: const Text('The instructor has ended this class.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
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
                        label: Text('On stage',
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
    final hostUid = _eng.remoteUids.isNotEmpty ? _eng.remoteUids.first : null;
    return Stack(
      children: [
        // Instructor video (first remote publisher) fills the screen.
        Positioned.fill(
          child: (hostUid == null || _eng.engine == null)
              ? const Center(
                  child: Text('Waiting for the host to start video...',
                      style: TextStyle(color: Colors.white70)),
                )
              : AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _eng.engine!,
                    canvas: VideoCanvas(uid: hostUid),
                    connection: RtcConnection(channelId: _eng.channel),
                  ),
                ),
        ),
        // My own preview when I am on stage.
        if (_isSpeaker && _eng.engine != null)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 90,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white24),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _eng.engine!,
                  canvas: const VideoCanvas(uid: 0),
                ),
              ),
            ),
          ),
        // Header.
        Positioned(
          top: 8,
          left: 12,
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('LIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                child: Text(widget.liveClass['title'] ?? 'Live class',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        // Bottom bar: ask a question + raise hand / leave stage.
        Positioned(
          left: 10,
          right: 10,
          bottom: 12,
          child: Row(
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
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: _green),
                        onPressed: _sendQuestion,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  IconButton(
                    style:
                        IconButton.styleFrom(backgroundColor: Colors.white24),
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
              const SizedBox(width: 8),
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
          ),
        ),
      ],
    );
  }
}
