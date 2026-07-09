import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';

/// Practice history — every completed session the user has done, pulled from
/// the backend (saved automatically when they finish a pose session).
class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];

  String t(String en, String mr, String hn) => LanguageHelper.t(en, mr, hn);

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
      final raw = await ApiService.getUserSessions(provider.profile.userId);
      if (!mounted) return;
      setState(() {
        _sessions = raw
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = t("Could not load history.", "इतिहास लोड झाला नाही.",
            "इतिहास लोड नहीं हुआ.");
        _loading = false;
      });
    }
  }

  int _int(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse('$v') ?? 0;
  }

  String _dateLabel(dynamic iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso.toString()).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final that = DateTime(d.year, d.month, d.day);
      final diff = today.difference(that).inDays;
      final time =
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      if (diff == 0) return '${t("Today", "आज", "आज")} · $time';
      if (diff == 1) return '${t("Yesterday", "काल", "कल")} · $time';
      return '${d.day}/${d.month}/${d.year} · $time';
    } catch (_) {
      return '';
    }
  }

  Color _scoreColor(int s) {
    if (s >= 80) return AppColors.success;
    if (s >= 60) return const Color(0xFFFF9500);
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppGradients.welcomeBg,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 20, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t("Practice History", "सराव इतिहास", "अभ्यास इतिहास"),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          t("Your session progress", "तुमची प्रगती",
                              "आपकी प्रगति"),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _loading ? null : _load,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : _error != null
                    ? _errorView()
                    : _sessions.isEmpty
                        ? _emptyView()
                        : _listView(),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 46, color: AppColors.textSecondary),
          const SizedBox(height: 14),
          Text(_error!, style: AppTextStyles.body()),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: t("Retry", "पुन्हा", "पुनः"),
            icon: Icons.refresh_rounded,
            width: 160,
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.chipBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded,
                  size: 50, color: AppColors.accent),
            ),
            const SizedBox(height: 18),
            Text(
              t("No sessions yet", "अद्याप सत्रे नाहीत", "अभी तक कोई सत्र नहीं"),
              style: AppTextStyles.heading3(),
            ),
            const SizedBox(height: 6),
            Text(
              t(
                "Finish a yoga session and your\nprogress will appear here.",
                "योगा सत्र पूर्ण करा, तुमची प्रगती इथे दिसेल.",
                "योग सत्र पूरा करें, आपकी प्रगति यहाँ दिखेगी.",
              ),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listView() {
    final total = _sessions.length;
    final completed = _sessions.where((s) => s['completed'] == true).length;
    final avg = total == 0
        ? 0
        : (_sessions.fold<int>(0, (a, s) => a + _int(s['avgSimilarity'])) /
                total)
            .round();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // ── Stats summary ────────────────────────────────────────────
          Row(
            children: [
              _stat(t("Sessions", "सत्रे", "सत्र"), '$total',
                  Icons.event_available_rounded, AppColors.accent),
              const SizedBox(width: 10),
              _stat(t("Avg Score", "सरासरी", "औसत"), '$avg%',
                  Icons.speed_rounded, _scoreColor(avg)),
              const SizedBox(width: 10),
              _stat(t("Completed", "पूर्ण", "पूर्ण"), '$completed',
                  Icons.check_circle_rounded, AppColors.success),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            t("Recent Sessions", "अलीकडील सत्रे", "हाल के सत्र"),
            style: AppTextStyles.heading3(),
          ),
          const SizedBox(height: 8),
          for (final s in _sessions) _sessionCard(s),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            Text(label,
                style: AppTextStyles.caption(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> s) {
    final name = (s['poseName'] ?? 'Pose').toString();
    final acc = _int(s['avgSimilarity']);
    final best = _int(s['score']);
    final completed = s['completed'] == true;
    final held = _int(s['durationAchieved']);
    final mistakes = (s['mistakes'] as List?)?.length ?? 0;
    final date = _dateLabel(s['createdAt'] ?? s['sessionDate']);
    final color = _scoreColor(acc);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          // Score circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.4), width: 2),
            ),
            child: Center(
              child: Text(
                '$acc',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: AppTextStyles.bodyMedium(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (completed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded,
                                size: 12, color: AppColors.success),
                            const SizedBox(width: 3),
                            Text(
                              t("Done", "पूर्ण", "पूर्ण"),
                              style: AppTextStyles.caption(
                                  color: AppColors.success),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(date, style: AppTextStyles.caption()),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _tag(Icons.emoji_events_outlined,
                        '${t("Best", "सर्वोत्तम", "सर्वश्रेष्ठ")} $best%'),
                    const SizedBox(width: 8),
                    _tag(Icons.timer_outlined, '${held}s'),
                    if (mistakes > 0) ...[
                      const SizedBox(width: 8),
                      _tag(Icons.info_outline_rounded,
                          '$mistakes ${t("tips", "टिप्स", "टिप्स")}'),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(text,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent)),
        ],
      ),
    );
  }
}
