import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/live_api.dart';
import '../services/live_engine.dart';

/// Instructor side: broadcast video, manage Q&A, approve raised hands,
/// start/stop cloud recording and end the class.
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
  bool _starting = true;
  String? _error;
  bool _recording = false;
  List _questions = [];
  List _hands = [];
  List _participants = [];
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
      await _eng.ensurePermissions();
      if (widget.autoGoLive || widget.liveClass['status'] == 'scheduled') {
        await LiveApi.goLive(_id);
      }
      final uid = await LiveApi.myUid();
      final tok = await LiveApi.getToken(_id, uid: uid, role: 'host');
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
        uid: uid,
        asHost: true,
      );
      setState(() => _starting = false);
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    } catch (e) {
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
      setState(() {
        _questions = s['questions'] ?? [];
        _hands = s['raisedHands'] ?? [];
        _participants = s['participants'] ?? [];
        _recording = s['isRecording'] == true;
      });
    } catch (_) {}
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
                trailing: TextButton(
                  onPressed: () async {
                    await LiveApi.approveHand(_id, m['userId'].toString());
                    await _refresh();
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('On stage'),
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
        // The instructor camera fills the screen (or a "camera off" tile).
        Positioned.fill(
          child: (_eng.engine == null || !_eng.camOn)
              ? Container(
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_off,
                            color: Colors.white38, size: 48),
                        SizedBox(height: 8),
                        Text('Camera off',
                            style: TextStyle(color: Colors.white38)),
                      ],
                    ),
                  ),
                )
              : AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _eng.engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
        ),
        // Approved speakers who came on video.
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: _eng.remoteUids
                .take(3)
                .map((u) => Container(
                      width: 90,
                      height: 120,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _eng.engine!,
                          canvas: VideoCanvas(uid: u),
                          connection: RtcConnection(channelId: _eng.channel),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        // Header.
        Positioned(
          top: 8,
          left: 12,
          child: Row(
            children: [
              _tag('LIVE', Colors.red),
              if (_recording) ...[
                const SizedBox(width: 6),
                _tag('REC', Colors.black87),
              ],
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: Text(
                  widget.liveClass['title'] ?? 'Live class',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              if ((widget.liveClass['joinCode'] ?? '')
                  .toString()
                  .isNotEmpty) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(
                        text: widget.liveClass['joinCode'].toString()));
                    _snack('Join code copied');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.liveClass['joinCode'].toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy,
                            color: Colors.white, size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Controls.
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ctrl(_eng.micOn ? Icons.mic : Icons.mic_off, 'Mic',
                  _eng.toggleMic),
              _ctrl(_eng.camOn ? Icons.videocam : Icons.videocam_off, 'Cam',
                  _eng.toggleCam),
              _ctrl(Icons.cameraswitch, 'Flip', _eng.switchCamera),
              _ctrl(
                _recording ? Icons.stop_circle : Icons.fiber_manual_record,
                _recording ? 'Stop' : 'Record',
                _toggleRecord,
                color: Colors.red,
              ),
              Stack(
                children: [
                  _ctrl(Icons.forum, 'Q and A', _openPanel),
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
          ),
        ),
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
            radius: 24,
            backgroundColor: Colors.white12,
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
