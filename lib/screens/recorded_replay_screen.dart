import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Plays a finished class recording. Recordings live in external cloud
/// storage (never in the app); this screen only streams them for playback.
/// Supports a normal video URL (mp4/HLS) and, as a fallback, a YouTube link.
class RecordedReplayScreen extends StatefulWidget {
  final String title;
  final String url;
  const RecordedReplayScreen({super.key, required this.title, required this.url});

  @override
  State<RecordedReplayScreen> createState() => _RecordedReplayScreenState();
}

class _RecordedReplayScreenState extends State<RecordedReplayScreen> {
  VideoPlayerController? _video;
  YoutubePlayerController? _yt;
  bool _isYoutube = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ytId = YoutubePlayer.convertUrlToId(widget.url);
    _isYoutube = ytId != null;
    if (_isYoutube) {
      _yt = YoutubePlayerController(
        initialVideoId: ytId!,
        flags: const YoutubePlayerFlags(autoPlay: true),
      );
      _ready = true;
    } else {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _video = c;
      await c.initialize();
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not play this recording.');
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    _yt?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      ),
      body: Center(child: _body()),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.white70));
    }
    if (!_ready) return const CircularProgressIndicator(color: Colors.white);
    if (_isYoutube) {
      return YoutubePlayer(controller: _yt!, showVideoProgressIndicator: true);
    }
    final v = _video!;
    return AspectRatio(
      aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(v),
          VideoProgressIndicator(v, allowScrubbing: true),
          IconButton(
            iconSize: 56,
            color: Colors.white,
            icon: Icon(v.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
            onPressed: () => setState(
                () => v.value.isPlaying ? v.pause() : v.play()),
          ),
        ],
      ),
    );
  }
}
