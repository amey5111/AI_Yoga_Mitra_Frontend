import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import 'pose_detail_screen.dart';
import 'breathing_detail_screen.dart';
import '../Widgets/language_switcher.dart';

class EditRoutineScreen extends StatefulWidget {
  final List<Map<String, dynamic>> routineSteps;
  const EditRoutineScreen({super.key, required this.routineSteps});
  @override
  State<EditRoutineScreen> createState() => _EditRoutineScreenState();
}

class _EditRoutineScreenState extends State<EditRoutineScreen> {
  late List<Map<String, dynamic>> _routineItems;
  List<Map<String, dynamic>> _otherPoses = [];
  List<Map<String, dynamic>> _otherBreathing = [];
  bool _updating = false;

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

  String t(String en, String mr, String hn) => LanguageHelper.t(en, mr, hn);
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? -1;
  }

  @override
  void initState() {
    super.initState();
    _routineItems = widget.routineSteps
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _buildOtherRecommendations();
  }

  void _buildOtherRecommendations() {
    final provider = Provider.of<UserProvider>(context, listen: false);
    final Set<int> routineIds = _routineItems
        .map((e) => _toInt(e['id']))
        .toSet();
    _otherPoses = provider.poseDetails
        .where((p) => !routineIds.contains(_toInt(p['id'])))
        .map((p) {
          final c = Map<String, dynamic>.from(p);
          c['type'] = 'pose';
          return c;
        })
        .toList();
    _otherBreathing = provider.breathingDetails
        .where((b) => !routineIds.contains(_toInt(b['id'])))
        .map((b) {
          final c = Map<String, dynamic>.from(b);
          c['type'] = 'breathing';
          return c;
        })
        .toList();
  }

  void _removeFromRoutine(int index) {
    final removed = Map<String, dynamic>.from(_routineItems[index]);
    setState(() {
      _routineItems.removeAt(index);
      if (removed['type'] == 'breathing')
        _otherBreathing.add(removed);
      else
        _otherPoses.add(removed);
    });
  }

  void _addToRoutine(Map<String, dynamic> item, bool isBreathing) {
    final copy = Map<String, dynamic>.from(item);
    copy['type'] = isBreathing ? 'breathing' : 'pose';
    final itemId = _toInt(copy['id']);
    setState(() {
      _routineItems.add(copy);
      if (isBreathing)
        _otherBreathing.removeWhere((b) => _toInt(b['id']) == itemId);
      else
        _otherPoses.removeWhere((p) => _toInt(p['id']) == itemId);
    });
  }

  Future<void> _updateRoutine() async {
    if (_routineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              "Add at least one item.",
              "किमान एक योगा प्रकार जोडा.",
              "कम से कम एक योगा प्रकार जोड़ें।",
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _updating = true);
    final provider = Provider.of<UserProvider>(context, listen: false);
    final userId = provider.profile.userId;
    final poseIds = _routineItems
        .where((e) => e['type'] != 'breathing')
        .map<int>((e) => _toInt(e['id']))
        .where((id) => id != -1)
        .toList();
    final breathingIds = _routineItems
        .where((e) => e['type'] == 'breathing')
        .map<int>((e) => _toInt(e['id']))
        .where((id) => id != -1)
        .toList();
    try {
      final newRoutine = await ApiService.updateUserRoutine(
        userId,
        poseIds,
        breathingIds,
      );
      if (!mounted) return;
      setState(() => _updating = false);
      if (newRoutine != null)
        Navigator.pop(context, newRoutine);
      else
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t("Update failed.", "अपडेट अयशस्वी.", "अपडेट विफल।")),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t("Something went wrong.", "काहीतरी चूक झाली.", "कुछ गलत हो गया।"),
          ),
        ),
      );
    }
  }

  String _formatDuration(Map<String, dynamic> item) {
    final secs = (item['duration'] ?? item['duration_seconds'] ?? 60) as num;
    return "${(secs / 60).round()} ${t('mins', 'मिनिटे', 'मिनट')}";
  }

  void _openVideo(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildRoutineItem(Map<String, dynamic> item, int index) {
    final name = item['name']?[langCode] ?? '';
    final isBreathing = item['type'] == 'breathing';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: AppGradients.cardGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTextStyles.bodyMedium()),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        isBreathing
                            ? Icons.air_rounded
                            : Icons.self_improvement_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(item),
                        style: AppTextStyles.caption(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _removeFromRoutine(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t("Remove", "काढा", "हटाएं"),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> item, bool isBreathing) {
    final name = item['name']?[langCode] ?? '';
    final secs = (item['duration_seconds'] ?? 60) as num;
    final durationStr = "${(secs / 60).round()} ${t('mins', 'मिनिटे', 'मिनट')}";
    final reason = item['reason']?[langCode] ?? '';
    final imageUrl = ApiService.resolveImageUrl(item['image_url']);
    final video = item['video']?[langCode]?['youtube_url'];

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.chipBg,
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.heading3()),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          AppChip(
                            label: isBreathing
                                ? t("Breathing", "प्राणायाम", "श्वसन")
                                : t("Yoga", "योग", "योग"),
                          ),
                          const SizedBox(width: 8),
                          AppChip(
                            label: durationStr,
                            icon: Icons.timer_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Row(
              children: [
                _miniBtn(
                  Icons.description_outlined,
                  t("Info", "माहिती", "जानकारी"),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => isBreathing
                          ? BreathingDetailScreen(id: _toInt(item['id']))
                          : PoseDetailScreen(poseId: _toInt(item['id'])),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _miniBtn(
                  Icons.play_circle_outline_rounded,
                  t("Video", "व्हिडिओ", "वीडियो"),
                  () => _openVideo(video),
                  isRed: true,
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _addToRoutine(item, isBreathing),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    t("Add", "जोडा", "जोड़ें"),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (reason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.07),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: AppTextStyles.caption(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isRed = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isRed ? Colors.red.withOpacity(0.08) : AppColors.chipBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isRed ? Colors.redAccent : AppColors.accent,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isRed ? Colors.redAccent : AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasOthers = _otherPoses.isNotEmpty || _otherBreathing.isNotEmpty;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.softBg),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  gradient: AppGradients.welcomeBg,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
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
                          child: Text(
                            t(
                              "Customize Routine",
                              "दिनचर्या सानुकूलित करा",
                              "दिनचर्या अनुकूलित करें",
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        LanguageSwitcher(
                          onLanguageChanged: () {
                            setState(() {});
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.list_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),

                              const SizedBox(width: 6),

                              Text(
                                '${_routineItems.length} ${t("items", "योगा प्रकार", "योगा प्रकार")}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 12, bottom: 100),
                  children: [
                    if (_routineItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.playlist_add_rounded,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t(
                                "Your routine is empty.\nAdd poses from below.",
                                "तुमची दिनचर्या रिकामी आहे.\nखाली पोझेस जोडा.",
                                "आपकी दिनचर्या खाली है।\nनीचे से जोड़ें।",
                              ),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (int i = 0; i < _routineItems.length; i++)
                        _buildRoutineItem(_routineItems[i], i),
                    if (hasOthers) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t(
                                  "Other Recommendations For You",
                                  "तुमच्यासाठी सुचवलेले इतर",
                                  "आपके लिए अन्य सुझाव",
                                ),
                                style: AppTextStyles.heading3(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (var p in _otherPoses)
                        _buildRecommendationCard(p, false),
                      for (var b in _otherBreathing)
                        _buildRecommendationCard(b, true),
                    ] else if (_routineItems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: AppChip(
                            label: t(
                              "All recommendations added!",
                              "सर्व शिफारसी जोडल्या!",
                              "सभी सिफारिशें जोड़ी गईं!",
                            ),
                            selected: true,
                            icon: Icons.check_rounded,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: AppPrimaryButton(
            label: _updating
                ? t("Updating...", "अपडेट होत आहे...", "अपडेट हो रहा है...")
                : t(
                    "✨ Update Routine",
                    "✨ दिनचर्या अपडेट करा",
                    "✨ दिनचर्या अपडेट करें",
                  ),
            onPressed: _updating ? null : _updateRoutine,
            loading: _updating,
          ),
        ),
      ),
    );
  }
}
