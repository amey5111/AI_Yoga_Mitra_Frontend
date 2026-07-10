import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';

/// AI-based post-session feedback: performance summary, poses done correctly,
/// posture mistakes, areas to improve, and personalized suggestions.
class PoseResultScreen extends StatefulWidget {
  /// Each entry: {poseId, poseName, avgSimilarity, bestSimilarity,
  /// durationAchieved, targetDuration, completed, mistakes[]}
  final List<Map<String, dynamic>> results;
  const PoseResultScreen({super.key, required this.results});

  @override
  State<PoseResultScreen> createState() => _PoseResultScreenState();
}

class _PoseResultScreenState extends State<PoseResultScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _fb;

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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final provider = Provider.of<UserProvider>(context, listen: false);
      final fb = await ApiService.getSessionFeedback(
        results: widget.results,
        userId: provider.profile.userId,
        language: langCode,
      );
      if (!mounted) return;
      if (fb == null) {
        setState(() {
          _error = t("Could not load feedback.", "अभिप्राय मिळाला नाही.",
              "फीडबैक नहीं मिला.");
          _loading = false;
        });
        return;
      }
      setState(() {
        _fb = fb;
        _loading = false;
      });
      // Read the feedback aloud for voice/accessibility users
      final spoken = _spokenSummary(fb);
      VoiceService.instance.setReader(() => spoken);
      VoiceService.instance.announce(spoken);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = t("Could not load feedback.", "अभिप्राय मिळाला नाही.",
            "फीडबैक नहीं मिला.");
        _loading = false;
      });
    }
  }

  List<String> _list(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [v.toString()];
  }

  /// Build a natural spoken version of the whole feedback report.
  String _spokenSummary(Map<String, dynamic> fb) {
    final score = fb['overall_score'] ?? 0;
    final summary = (fb['performance_summary'] ?? '').toString();
    final correct = _list(fb['poses_correct']);
    final mistakes = _list(fb['mistakes']);
    final improvements = _list(fb['improvements']);
    final suggestions = _list(fb['suggestions']);
    final enc = (fb['encouragement'] ?? '').toString();
    final b = StringBuffer();
    b.write('${t("Your session score is", "तुमचा स्कोर आहे", "आपका स्कोर है")} $score. ');
    if (summary.isNotEmpty) b.write('$summary ');
    if (correct.isNotEmpty) {
      b.write('${t("Poses done correctly", "योग्य आसने", "सही आसन")}: ${correct.join(", ")}. ');
    }
    if (mistakes.isNotEmpty) {
      b.write('${t("Mistakes", "चुका", "गलतियाँ")}: ${mistakes.join(". ")}. ');
    }
    if (improvements.isNotEmpty) {
      b.write('${t("To improve", "सुधारणा", "सुधार")}: ${improvements.join(". ")}. ');
    }
    if (suggestions.isNotEmpty) {
      b.write('${t("Suggestions", "सूचना", "सुझाव")}: ${suggestions.join(". ")}. ');
    }
    if (enc.isNotEmpty) b.write(enc);
    return b.toString();
  }

  @override
  void dispose() {
    VoiceService.instance.clearReader();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: _loading
          ? _loadingView()
          : _error != null
              ? _errorView()
              : _feedbackView(),
    );
  }

  Widget _loadingView() {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.softBg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.card,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t("Analyzing your session…", "तुमच्या सत्राचे विश्लेषण…",
                  "आपके सत्र का विश्लेषण…"),
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(_error!, style: AppTextStyles.body()),
          const SizedBox(height: 18),
          AppPrimaryButton(
            label: t("Retry", "पुन्हा", "पुनः"),
            icon: Icons.refresh_rounded,
            width: 160,
            onPressed: _load,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t("Close", "बंद करा", "बंद करें")),
          ),
        ],
      ),
    );
  }

  Widget _feedbackView() {
    final fb = _fb!;
    final score = fb['overall_score'] is int
        ? fb['overall_score'] as int
        : int.tryParse('${fb['overall_score']}') ?? 0;
    final correct = _list(fb['poses_correct']);
    final summary = (fb['performance_summary'] ?? '').toString();
    final mistakes = _list(fb['mistakes']);
    final improvements = _list(fb['improvements']);
    final suggestions = _list(fb['suggestions']);
    final encouragement = (fb['encouragement'] ?? '').toString();

    return CustomScrollView(
      slivers: [
        // ── Score header ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.welcomeBg,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          t("Session Feedback", "सत्र अभिप्राय", "सत्र फीडबैक"),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 38),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Score ring
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.15),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.4), width: 3),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$score',
                              style: GoogleFonts.poppins(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              t("Score", "गुण", "स्कोर"),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.85),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (encouragement.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        encouragement,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (summary.isNotEmpty) ...[
                _summaryCard(summary),
                const SizedBox(height: 14),
              ],
              _section(
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                title: t("Poses Done Correctly", "योग्य केलेली आसने",
                    "सही किए आसन"),
                items: correct,
                emptyText: t("Keep practicing to nail your poses!",
                    "सराव करत राहा!", "अभ्यास करते रहें!"),
                bulletIsCheck: true,
              ),
              const SizedBox(height: 14),
              _section(
                icon: Icons.report_problem_rounded,
                color: const Color(0xFFFF9500),
                title: t("Common Mistakes", "सामान्य चुका", "सामान्य गलतियाँ"),
                items: mistakes,
              ),
              const SizedBox(height: 14),
              _section(
                icon: Icons.trending_up_rounded,
                color: AppColors.accent,
                title: t("Areas to Improve", "सुधारण्याचे मुद्दे",
                    "सुधार के क्षेत्र"),
                items: improvements,
              ),
              const SizedBox(height: 14),
              _section(
                icon: Icons.tips_and_updates_rounded,
                color: const Color(0xFF34C759),
                title: t("Suggestions for Next Time", "पुढील वेळेसाठी सूचना",
                    "अगली बार के लिए सुझाव"),
                items: suggestions,
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                label: t("Done", "पूर्ण", "हो गया"),
                icon: Icons.check_rounded,
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0.10),
            AppColors.lavender.withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              summary,
              style: AppTextStyles.body(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    required List<String> items,
    String? emptyText,
    bool bulletIsCheck = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTextStyles.heading3())),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(emptyText ?? '—', style: AppTextStyles.caption())
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        bulletIsCheck
                            ? Icons.check_circle_outline_rounded
                            : Icons.fiber_manual_record_rounded,
                        size: bulletIsCheck ? 15 : 8,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item, style: AppTextStyles.body())),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
