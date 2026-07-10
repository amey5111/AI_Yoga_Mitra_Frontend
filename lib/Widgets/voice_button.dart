import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import '../utils/language_helper.dart';

/// Passive, NON-interactive voice status indicator. The assistant listens and
/// speaks fully automatically — this just shows what it's doing (listening /
/// speaking / last heard) so sighted users have visual feedback. There is no
/// button to tap; blind users never need to find or touch anything.
class VoiceStatusIndicator extends StatelessWidget {
  const VoiceStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final voice = VoiceService.instance;
    return AnimatedBuilder(
      animation: voice,
      builder: (context, _) {
        // Hidden entirely when the assistant is off
        if (!voice.accessibilityMode) return const SizedBox.shrink();

        final isSpeaking = voice.speaking;
        final isListening = voice.listening;

        final color = isSpeaking
            ? AppColors.accent
            : isListening
                ? const Color(0xFFE53935)
                : AppColors.textSecondary;
        final label = isSpeaking
            ? LanguageHelper.t("Speaking", "बोलत आहे", "बोल रहा हूँ")
            : isListening
                ? LanguageHelper.t("Listening", "ऐकत आहे", "सुन रहा हूँ")
                : (voice.lastHeard.isNotEmpty
                    ? voice.lastHeard
                    : LanguageHelper.t("Voice on", "व्हॉईस चालू", "वॉइस चालू"));
        final icon = isSpeaking
            ? Icons.volume_up_rounded
            : isListening
                ? Icons.mic_rounded
                : Icons.hearing_rounded;

        return IgnorePointer(
          // Never intercepts touches — purely informational
          child: Container(
            constraints: const BoxConstraints(maxWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(99),
              boxShadow: AppShadows.soft,
              border: Border.all(color: color.withOpacity(0.35), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(active: isListening || isSpeaking, color: color),
                const SizedBox(width: 8),
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PulseDot extends StatefulWidget {
  final bool active;
  final Color color;
  const _PulseDot({required this.active, required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final scale = widget.active ? (0.7 + 0.3 * _c.value) : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
