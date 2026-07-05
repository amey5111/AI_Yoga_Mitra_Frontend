import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';

/// Audio-guided breathing counter with synchronized voice guidance
/// for inhale / hold / exhale phases.
class BreathingGuideScreen extends StatefulWidget {
  final String techniqueName;
  final int inhaleSeconds;
  final int holdSeconds;
  final int exhaleSeconds;

  const BreathingGuideScreen({
    super.key,
    required this.techniqueName,
    this.inhaleSeconds = 4,
    this.holdSeconds = 4,
    this.exhaleSeconds = 6,
  });

  @override
  State<BreathingGuideScreen> createState() => _BreathingGuideScreenState();
}

enum _Phase { inhale, hold, exhale }

class _BreathingGuideScreenState extends State<BreathingGuideScreen> {
  final FlutterTts _tts = FlutterTts();

  late int inhale;
  late int hold;
  late int exhale;
  int cycles = 5;

  bool running = false;
  bool finished = false;
  _Phase phase = _Phase.inhale;
  int secondsLeft = 0;
  int currentCycle = 0;
  Timer? _timer;
  bool _voiceOn = true;

  String t(String en, String mr, String hn) => LanguageHelper.t(en, mr, hn);

  @override
  void initState() {
    super.initState();
    inhale = widget.inhaleSeconds.clamp(2, 20);
    hold = widget.holdSeconds.clamp(0, 20);
    exhale = widget.exhaleSeconds.clamp(2, 20);
    _initTts();
  }

  Future<void> _initTts() async {
    // Pick a voice language matching the app language, with fallbacks
    final wanted = switch (LanguageHelper.currentLanguage) {
      "मराठी" => ["mr-IN", "hi-IN", "en-IN", "en-US"],
      "हिंदी" => ["hi-IN", "en-IN", "en-US"],
      _ => ["en-IN", "en-US"],
    };

    for (final lang in wanted) {
      try {
        final available = await _tts.isLanguageAvailable(lang);
        if (available == true) {
          await _tts.setLanguage(lang);
          break;
        }
      } catch (_) {}
    }

    try {
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    if (!_voiceOn) return;
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  String _phaseWord(_Phase p) {
    switch (p) {
      case _Phase.inhale:
        return t("Inhale", "श्वास घ्या", "सांस लें");
      case _Phase.hold:
        return t("Hold", "रोखून धरा", "रोकें");
      case _Phase.exhale:
        return t("Exhale", "श्वास सोडा", "सांस छोड़ें");
    }
  }

  int _phaseLength(_Phase p) {
    switch (p) {
      case _Phase.inhale:
        return inhale;
      case _Phase.hold:
        return hold;
      case _Phase.exhale:
        return exhale;
    }
  }

  void _start() {
    setState(() {
      running = true;
      finished = false;
      currentCycle = 1;
      phase = _Phase.inhale;
      secondsLeft = inhale;
    });
    _speak(_phaseWord(_Phase.inhale));
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stop({bool completed = false}) {
    _timer?.cancel();
    _timer = null;
    _tts.stop();
    setState(() {
      running = false;
      finished = completed;
    });
    if (completed) {
      _speak(
        t(
          "Session complete. Well done!",
          "सत्र पूर्ण झाले. छान केले!",
          "सत्र पूरा हुआ. बहुत बढ़िया!",
        ),
      );
    }
  }

  void _tick() {
    if (!mounted) return;

    // count down within the phase; speak the remaining count
    if (secondsLeft > 1) {
      setState(() => secondsLeft--);
      final spoken = _phaseLength(phase) - secondsLeft;
      _speak("$spoken");
      return;
    }

    // phase finished → next phase (skip hold if 0)
    _Phase? next;
    switch (phase) {
      case _Phase.inhale:
        next = hold > 0 ? _Phase.hold : _Phase.exhale;
        break;
      case _Phase.hold:
        next = _Phase.exhale;
        break;
      case _Phase.exhale:
        next = null; // cycle done
        break;
    }

    if (next != null) {
      setState(() {
        phase = next!;
        secondsLeft = _phaseLength(next);
      });
      _speak(_phaseWord(next));
      return;
    }

    // cycle complete
    if (currentCycle >= cycles) {
      _stop(completed: true);
      return;
    }

    setState(() {
      currentCycle++;
      phase = _Phase.inhale;
      secondsLeft = inhale;
    });
    _speak(_phaseWord(_Phase.inhale));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Color _phaseColor() {
    switch (phase) {
      case _Phase.inhale:
        return const Color(0xFF4CAF50);
      case _Phase.hold:
        return const Color(0xFFFF9800);
      case _Phase.exhale:
        return AppColors.accent;
    }
  }

  double _circleScale() {
    if (!running) return 0.75;
    final total = _phaseLength(phase);
    if (total <= 0) return 0.75;
    final progress = (total - secondsLeft) / total;
    switch (phase) {
      case _Phase.inhale:
        return 0.6 + 0.4 * progress; // grow
      case _Phase.hold:
        return 1.0; // stay full
      case _Phase.exhale:
        return 1.0 - 0.4 * progress; // shrink
    }
  }

  Widget _stepper({
    required String label,
    required int value,
    required void Function(int) onChanged,
    int min = 0,
    int max = 20,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption(),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: running
                  ? null
                  : () {
                      if (value > min) onChanged(value - 1);
                    },
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.remove_rounded,
                  size: 15,
                  color: AppColors.accent,
                ),
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: running
                  ? null
                  : () {
                      if (value < max) onChanged(value + 1);
                    },
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  size: 15,
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final phaseColor = _phaseColor();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.softBg),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: const BoxDecoration(
                  gradient: AppGradients.welcomeBg,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _stop();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t(
                              "Guided Breathing",
                              "मार्गदर्शित श्वसन",
                              "निर्देशित श्वास",
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.techniqueName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // voice toggle
                    GestureDetector(
                      onTap: () => setState(() => _voiceOn = !_voiceOn),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _voiceOn
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Breathing circle ─────────────────────────────────────
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (running) ...[
                        Text(
                          "${t("Cycle", "आवर्तन", "चक्र")} $currentCycle / $cycles",
                          style: AppTextStyles.heading3(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      AnimatedScale(
                        scale: _circleScale(),
                        duration: const Duration(milliseconds: 950),
                        curve: Curves.easeInOut,
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                phaseColor.withOpacity(0.75),
                                phaseColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: phaseColor.withOpacity(0.35),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (finished) ...[
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.white,
                                    size: 52,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t("Complete!", "पूर्ण!", "पूर्ण!"),
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ] else if (running) ...[
                                  Text(
                                    _phaseWord(phase),
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$secondsLeft',
                                    style: GoogleFonts.poppins(
                                      fontSize: 56,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(
                                    Icons.air_rounded,
                                    color: Colors.white,
                                    size: 44,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t("Ready?", "तयार?", "तैयार?"),
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Settings + controls ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    AppCard(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _stepper(
                              label: t("Inhale", "श्वास", "सांस"),
                              value: inhale,
                              min: 2,
                              onChanged: (v) => setState(() => inhale = v),
                            ),
                          ),
                          Expanded(
                            child: _stepper(
                              label: t("Hold", "धरा", "रोकें"),
                              value: hold,
                              onChanged: (v) => setState(() => hold = v),
                            ),
                          ),
                          Expanded(
                            child: _stepper(
                              label: t("Exhale", "सोडा", "छोड़ें"),
                              value: exhale,
                              min: 2,
                              onChanged: (v) => setState(() => exhale = v),
                            ),
                          ),
                          Expanded(
                            child: _stepper(
                              label: t("Cycles", "आवर्तने", "चक्र"),
                              value: cycles,
                              min: 1,
                              max: 30,
                              onChanged: (v) => setState(() => cycles = v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppPrimaryButton(
                      label: running
                          ? t("Stop", "थांबवा", "रोकें")
                          : t("Start Session", "सत्र सुरू करा", "सत्र शुरू करें"),
                      icon: running
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      onPressed: running ? () => _stop() : _start,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
