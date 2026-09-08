import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

/// Plays a guided-audio track from a lesson plan.
///
/// video_player handles audio files as well as video, but rendering its
/// surface for an audio-only track would just be a black rectangle — so this
/// screen draws its own transport controls instead.
class AudioMaterialScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String url;

  const AudioMaterialScreen({
    super.key,
    required this.title,
    required this.url,
    this.subtitle = '',
  });

  @override
  State<AudioMaterialScreen> createState() => _AudioMaterialScreenState();
}

class _AudioMaterialScreenState extends State<AudioMaterialScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = c;
      // Repaint the scrubber as it plays.
      c.addListener(_onTick);
      await c.initialize();
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not play this audio.');
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  Future<void> _skip(int seconds) async {
    final c = _controller;
    if (c == null) return;
    final target = c.value.position + Duration(seconds: seconds);
    final max = c.value.duration;
    await c.seekTo(
      target < Duration.zero
          ? Duration.zero
          : (target > max ? max : target),
    );
  }

  String _clock(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: appBar(title: widget.title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _error != null
              ? Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                )
              : !_ready
                  ? const CircularProgressIndicator(color: AppColors.accent)
                  : _player(),
        ),
      ),
    );
  }

  Widget _player() {
    final c = _controller!;
    final position = c.value.position;
    final duration = c.value.duration;
    final maxMs = duration.inMilliseconds.toDouble();
    final valueMs = position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            gradient: AppGradients.cardGradient,
            shape: BoxShape.circle,
            boxShadow: AppShadows.card,
          ),
          child: const Icon(Icons.headphones_rounded,
              color: Colors.white, size: 56),
        ),
        const SizedBox(height: 26),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading2(),
        ),
        if (widget.subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 26),
        Slider(
          value: valueMs,
          max: maxMs <= 0 ? 1 : maxMs,
          activeColor: AppColors.accent,
          inactiveColor: AppColors.chipBg,
          onChanged: maxMs <= 0
              ? null
              : (v) => c.seekTo(Duration(milliseconds: v.round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_clock(position), style: AppTextStyles.caption()),
              Text(_clock(duration), style: AppTextStyles.caption()),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 34,
              color: AppColors.textSecondary,
              icon: const Icon(Icons.replay_10_rounded),
              onPressed: () => _skip(-10),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: AppGradients.cardGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.button,
                ),
                child: Icon(
                  c.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              iconSize: 34,
              color: AppColors.textSecondary,
              icon: const Icon(Icons.forward_10_rounded),
              onPressed: () => _skip(10),
            ),
          ],
        ),
      ],
    );
  }
}
