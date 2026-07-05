import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';

class YogaGptScreen extends StatefulWidget {
  const YogaGptScreen({super.key});

  @override
  State<YogaGptScreen> createState() => _YogaGptScreenState();
}

class _ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  _ChatMessage(this.role, this.content);
}

class _YogaGptScreenState extends State<YogaGptScreen>
    with SingleTickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _sending = false;
  bool _hasText = false;

  String t(String en, String mr, String hn) => LanguageHelper.t(en, mr, hn);

  String get langCode {
    switch (LanguageHelper.currentLanguage) {
      case "मराठी":
        return "mr";
      case "हिंदी":
        return "hn";
      default:
        return "en";
    }
  }

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() {
      final has = _inputController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _messages.add(
      _ChatMessage(
        'assistant',
        t(
          "Namaste 🙏\n\nI'm YogaGPT, your personal yoga & wellness guide. Ask me about poses, breathing, meditation, precautions, or building your practice.",
          "नमस्ते 🙏\n\nमी योगाGPT, तुमचा वैयक्तिक योग व वेलनेस मार्गदर्शक. आसने, प्राणायाम, ध्यान, काळजी किंवा सराव याबद्दल विचारा.",
          "नमस्ते 🙏\n\nमैं योगाGPT, आपका निजी योग व वेलनेस गाइड. आसन, प्राणायाम, ध्यान, सावधानियों या अभ्यास के बारे में पूछें.",
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatMessage('user', text));
      _sending = true;
      _inputController.clear();
      _hasText = false;
    });
    _scrollToBottom();

    try {
      final history =
          _messages.map((m) => {'role': m.role, 'content': m.content}).toList();
      final reply = await ApiService.yogaGptChat(history, langCode);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage('assistant', reply));
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            'assistant',
            t(
              "Sorry, I couldn't reply right now. Please check your connection and try again.",
              "क्षमस्व, सध्या उत्तर देऊ शकत नाही. कनेक्शन तपासून पुन्हा प्रयत्न करा.",
              "क्षमा करें, अभी उत्तर नहीं दे सका. कनेक्शन जांचकर पुनः प्रयास करें.",
            ),
          ),
        );
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  // ── Lightweight markdown: **bold** + bullet lines ────────────────────────
  Widget _formatted(String text, Color color) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          if (line.trim().isEmpty)
            const SizedBox(height: 6)
          else
            _line(line, color),
      ],
    );
  }

  Widget _line(String line, Color color) {
    final trimmed = line.trimLeft();
    final isBullet = trimmed.startsWith('- ') || trimmed.startsWith('• ');
    final content = isBullet ? trimmed.substring(2) : line;

    final textWidget = RichText(
      text: TextSpan(
        style: GoogleFonts.inter(fontSize: 14.5, height: 1.5, color: color),
        children: _spans(content, color),
      ),
    );

    if (!isBullet) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: textWidget,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 9, left: 2),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: textWidget),
        ],
      ),
    );
  }

  List<TextSpan> _spans(String text, Color color) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  Widget _avatar() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: AppGradients.cardGradient,
        shape: BoxShape.circle,
        boxShadow: AppShadows.soft,
      ),
      child: const Icon(
        Icons.self_improvement_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _bubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7B73E8), Color(0xFF5348C7)],
              )
            : null,
        color: isUser ? null : AppColors.bgCard,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 5),
          bottomRight: Radius.circular(isUser ? 5 : 18),
        ),
        boxShadow: AppShadows.soft,
        border: isUser
            ? null
            : Border.all(color: AppColors.divider, width: 1),
      ),
      child: isUser
          ? Text(
              msg.content,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                height: 1.45,
                color: Colors.white,
              ),
            )
          : _formatted(msg.content, AppColors.textPrimary),
    );

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[_avatar(), const SizedBox(width: 9)],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76,
              ),
              child: bubble,
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(5),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: AppShadows.soft,
              border: Border.all(color: AppColors.divider, width: 1),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => _send(label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.accent),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _messages.length <= 1 && !_sending;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          // ── Premium header ──────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.welcomeBg,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(26),
                bottomRight: Radius.circular(26),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x338B84F8),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 16, 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Stack(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.self_improvement_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF6C63FF),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "YogaGPT",
                                style: GoogleFonts.poppins(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "AI",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            t(
                              "Your yoga & wellness guide",
                              "तुमचा योग व वेलनेस मार्गदर्शक",
                              "आपका योग व वेलनेस गाइड",
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Messages ────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                for (final m in _messages) _bubble(m),
                if (_sending) _typingBubble(),
              ],
            ),
          ),

          // ── Suggestions (first open only) ───────────────────────────────
          if (showSuggestions)
            Container(
              height: 44,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _suggestionChip(
                    t("Poses for back pain", "पाठदुखीसाठी आसने", "पीठ दर्द के आसन"),
                    Icons.healing_rounded,
                  ),
                  _suggestionChip(
                    t("Reduce stress", "तणाव कमी करा", "तनाव कम करें"),
                    Icons.spa_rounded,
                  ),
                  _suggestionChip(
                    t("Best practice time", "सरावाची योग्य वेळ", "अभ्यास का समय"),
                    Icons.schedule_rounded,
                  ),
                  _suggestionChip(
                    t("Breathing for sleep", "झोपेसाठी प्राणायाम", "नींद के लिए"),
                    Icons.bedtime_rounded,
                  ),
                ],
              ),
            ),

          // ── Input bar ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        decoration: BoxDecoration(
                          color: AppColors.bgLight,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _focusNode.hasFocus
                                ? AppColors.accent
                                : AppColors.divider,
                            width: 1.4,
                          ),
                        ),
                        child: TextField(
                          controller: _inputController,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          onTap: () => setState(() {}),
                          style: GoogleFonts.inter(
                            fontSize: 14.5,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: t(
                              "Ask about yoga…",
                              "योगाबद्दल विचारा…",
                              "योग के बारे में पूछें…",
                            ),
                            hintStyle: GoogleFonts.inter(
                              fontSize: 14.5,
                              color: AppColors.textSecondary.withOpacity(0.6),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    GestureDetector(
                      onTap: (_hasText && !_sending) ? _send : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: (_hasText && !_sending)
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF7B73E8), Color(0xFF5348C7)],
                                )
                              : null,
                          color: (_hasText && !_sending)
                              ? null
                              : AppColors.chipBg,
                          shape: BoxShape.circle,
                          boxShadow:
                              (_hasText && !_sending) ? AppShadows.button : [],
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: (_hasText && !_sending)
                              ? Colors.white
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Animated three-dot "typing" indicator
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_c.value - i * 0.2) % 1.0;
            final scale = 0.6 + 0.4 * (1 - (phase - 0.5).abs() * 2).clamp(0, 1);
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
              child: Transform.scale(
                scale: scale.toDouble(),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
