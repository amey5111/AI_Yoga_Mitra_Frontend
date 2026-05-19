import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';

class BreathingDetailScreen extends StatefulWidget {
  final int id;
  const BreathingDetailScreen({super.key, required this.id});
  @override
  State<BreathingDetailScreen> createState() => _BreathingDetailScreenState();
}

class _BreathingDetailScreenState extends State<BreathingDetailScreen> {
  Map<String, dynamic>? technique;
  bool loading = true;

  String get langCode {
    switch (LanguageHelper.currentLanguage) {
      case "मराठी": return "mr";
      case "हिंदी": return "hn";
      default: return "en";
    }
  }

  String get videoSoonText {
    switch (LanguageHelper.currentLanguage) {
      case "मराठी": return "🎬 व्हिडिओ लवकरच येईल";
      case "हिंदी": return "🎬 वीडियो जल्द आएगा";
      default: return "🎬 Video coming soon";
    }
  }

  @override
  void initState() { super.initState(); _loadTech(); }

  Future<void> _loadTech() async {
    try { final t = await ApiService.fetchBreathingById(widget.id); technique = t; } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Widget _chip(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: AppColors.accent), const SizedBox(width: 5)],
        Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
      ]),
    );
  }

  Widget _section(String title, dynamic data) {
    if (data == null) return const SizedBox.shrink();
    List items = data is List ? data : [data];
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(16), boxShadow: AppShadows.soft),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.heading3()),
            const SizedBox(height: 12),
            for (var e in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.circle, size: 6, color: AppColors.accent)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e is Map ? e.values.join(" : ") : '$e', style: AppTextStyles.body())),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVideoSheet(Map<String, dynamic> videos) async {
    String selectedLang = "en";
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final video = videos[selectedLang];
          String formatDuration(int s) { final m = s ~/ 60; final r = s % 60; return "$m:${r.toString().padLeft(2, '0')}"; }
          String formatDate(String iso) { final d = DateTime.parse(iso); return "${d.day}/${d.month}/${d.year}"; }
          return DraggableScrollableSheet(
            expand: false, initialChildSize: 0.78,
            builder: (_, sc) => Container(
              decoration: const BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(99))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ["en", "hn", "mr"].map((code) {
                      final isSel = selectedLang == code;
                      final label = code == "en" ? "EN" : code == "hn" ? "हिंदी" : "मराठी";
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedLang = code),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(color: isSel ? AppColors.accent : AppColors.chipBg, borderRadius: BorderRadius.circular(99)),
                          child: Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: isSel ? Colors.white : AppColors.accent)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (video == null)
                    Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.videocam_off_rounded, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(videoSoonText, style: AppTextStyles.heading3(color: AppColors.textSecondary)),
                    ])))
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        controller: sc, padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () async { final uri = Uri.parse(video['youtube_url']); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(alignment: Alignment.center, children: [
                                  Image.network(video['thumbnail'], fit: BoxFit.cover),
                                  Container(width: 64, height: 64, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36)),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(video['title'], style: AppTextStyles.heading3()),
                            const SizedBox(height: 6),
                            Text(video['channel_name'], style: AppTextStyles.caption()),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _chip("Duration: ${formatDuration(video['duration_seconds'])}", icon: Icons.timer_outlined),
                              _chip("Published: ${formatDate(video['published_at'])}", icon: Icons.calendar_today_outlined),
                              _chip(video['license'], icon: Icons.verified_outlined),
                            ]),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE10600), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)),
                                onPressed: () async { final uri = Uri.parse(video['youtube_url']); if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication); },
                                icon: const Icon(Icons.play_circle_rounded),
                                label: Text("Watch on YouTube", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: AppLoadingIndicator());
    if (technique == null) return Scaffold(appBar: AppBar(), body: Center(child: Text("Technique not found", style: AppTextStyles.heading3(color: AppColors.textSecondary))));

    final t = technique!;
    final imageUrl = t['image_url'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280, pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle), child: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(t['name']?[langCode] ?? '', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
              background: Stack(fit: StackFit.expand, children: [
                if (imageUrl != null)
                  Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: AppGradients.routineCard)))
                else
                  Container(decoration: const BoxDecoration(gradient: AppGradients.routineCard)),
                Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.55)]))),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    if (t['category'] != null) _chip("${LanguageHelper.t("Category", "वर्ग", "श्रेणी")}: ${t['category']?[langCode] ?? ''}", icon: Icons.category_outlined),
                    if (t['difficulty_level'] != null) _chip("${LanguageHelper.t("Level", "पातळी", "स्तर")}: ${t['difficulty_level']?[langCode] ?? ''}", icon: Icons.bolt_rounded),
                    if (t['duration_seconds'] != null) _chip("${t['duration_seconds']}s", icon: Icons.timer_outlined),
                    if (t['repetitions'] != null) _chip("${t['repetitions']}x", icon: Icons.repeat_rounded),
                  ]),
                ),
                const SizedBox(height: 8),
                _section(LanguageHelper.t("Primary Benefits", "मुख्य फायदे", "मुख्य लाभ"), t['primary_benefits']?[langCode]),
                _section(LanguageHelper.t("Detailed Benefits", "सविस्तर फायदे", "विस्तृत लाभ"), t['detailed_benefits']?[langCode]),
                _section(LanguageHelper.t("Target Systems", "प्रभावित प्रणाली", "लक्षित तंत्र"), t['target_systems']?[langCode]),
                _section(LanguageHelper.t("Instructions", "सूचना", "निर्देश"), t['instructions']?[langCode]),
                _section(LanguageHelper.t("Breathing Pattern", "श्वसन पद्धत", "श्वसन पैटर्न"), t['breathing_pattern']?[langCode]),
                _section(LanguageHelper.t("Focus Points", "एकाग्रता बिंदू", "ध्यान बिंदु"), t['focus_points']?[langCode]),
                _section(LanguageHelper.t("Precautions", "काळजी", "सावधानियां"), t['precautions']?[langCode]),
                _section(LanguageHelper.t("Contraindications", "टाळावयाच्या अवस्था", "वर्जनाएं"), t['contraindications']?[langCode]),
                _section(LanguageHelper.t("Modifications", "पर्याय", "संशोधन"), t['modifications']?[langCode]),
                _section(LanguageHelper.t("Props Needed", "आवश्यक साहित्य", "उपकरण"), t['props_needed']?[langCode]),
                _section(LanguageHelper.t("Time of Practice", "सराव वेळ", "अभ्यास समय"), t['time_of_practice']?[langCode]),
                const SizedBox(height: 16),
                if (t['video'] != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppPrimaryButton(
                      label: LanguageHelper.t("Watch YouTube Video", "व्हिडिओ पाहा", "वीडियो देखें"),
                      icon: Icons.play_circle_rounded,
                      onPressed: () => _openVideoSheet(t['video']),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
