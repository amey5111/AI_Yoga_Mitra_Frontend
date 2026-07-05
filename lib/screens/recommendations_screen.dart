import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import 'pose_detail_screen.dart';
import 'breathing_detail_screen.dart';
import 'routine_screen.dart';
import '../Widgets/normal_language_switcher.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});
  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  bool loading = true;
  String? error;
  List<dynamic> recommendations = [];
  List<Map<String, dynamic>> poseDetails = [];
  List<Map<String, dynamic>> breathingDetails = [];

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

  String get pickedLabel {
    switch (LanguageHelper.currentLanguage) {
      case "मराठी":
        return "तुमच्यासाठी निवडले कारण:";
      case "हिंदी":
        return "आपके लिए चुना गया:";
      default:
        return "Picked for you because:";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      loading = true;
      error = null;
    });
    final provider = Provider.of<UserProvider>(context, listen: false);
    try {
      final recs = await ApiService.recommend(
        provider.profile.toJson(),
        provider.healthInfo.toJson(),
        provider.goals.toJson(),
        provider.profile.userId,
      );
      recommendations = recs ?? [];
      final poseIds = recommendations
          .where((r) => r['type'] == null)
          .map<int>((r) => r['id'])
          .take(10)
          .toList();
      poseDetails.clear();
      for (final id in poseIds) {
        final pose = await ApiService.fetchPoseById(id);
        final reason = recommendations.firstWhere(
          (r) => r['id'] == id,
        )['reason'];
        pose['reason'] = reason;
        poseDetails.add(pose);
      }
      final breathingIds = recommendations
          .where((r) => r['type'] == "breathing")
          .map<int>((r) => r['id'])
          .take(5)
          .toList();
      breathingDetails.clear();
      for (final id in breathingIds) {
        final item = await ApiService.fetchBreathingById(id);
        if (item != null) {
          final reason = recommendations.firstWhere(
            (r) => r['id'] == id,
          )['reason'];
          item['reason'] = reason;
          breathingDetails.add(item);
        }
      }
      provider.setRecommendations(
        poses: poseDetails,
        breathing: breathingDetails,
      );
    } catch (e) {
      error = "Could not load recommendations.";
    }
    if (mounted) setState(() => loading = false);
  }

  Widget _poseCard(Map<String, dynamic> pose) {
    final name = pose['name']?[langCode] ?? '';
    final diff = pose['difficulty_level']?[langCode] ?? '';
    final time = pose['duration_seconds'];
    final reps = pose['repetitions'];
    final benefits = (pose['primary_benefits']?[langCode] as List?) ?? [];
    final reason = pose['reason']?[langCode] ?? '';
    final imageUrl = ApiService.resolveImageUrl(pose['image_url']);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PoseDetailScreen(poseId: pose['id'])),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.chipBg,
                      child: const Icon(
                        Icons.self_improvement_rounded,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(name, style: AppTextStyles.heading3()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (diff.isNotEmpty) AppChip(label: diff),
                  if (time != null)
                    AppChip(label: '${time}s', icon: Icons.timer_outlined),
                  if (reps != null)
                    AppChip(label: '${reps}x', icon: Icons.repeat_rounded),
                ],
              ),
            ),
            if (benefits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: benefits
                      .take(2)
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 13,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$b',
                                  style: AppTextStyles.caption(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (reason.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickedLabel,
                            style: AppTextStyles.label(color: AppColors.accent),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reason,
                            style: AppTextStyles.caption(
                              color: AppColors.accentDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _breathingCard(Map<String, dynamic> item) {
    final name = item['name']?[langCode] ?? '';
    final benefits = item['primary_benefits']?[langCode];
    final reason = item['reason']?[langCode] ?? '';
    final imageUrl = ApiService.resolveImageUrl(item['image_url']);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BreathingDetailScreen(id: item['id']),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppColors.chipBg,
                ),
                child: imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.air_rounded,
                            color: AppColors.accent,
                            size: 28,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.air_rounded,
                        color: AppColors.accent,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.bodyMedium()),
                    const SizedBox(height: 4),
                    Text(
                      benefits is List
                          ? benefits.join(", ")
                          : benefits?.toString() ?? '',
                      style: AppTextStyles.caption(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          reason,
                          style: AppTextStyles.caption(color: AppColors.accent),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (error != null)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              error!,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _loadRecommendations,
              width: 160,
            ),
          ],
        ),
      );

    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      color: AppColors.accent,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Yoga poses header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.self_improvement_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  LanguageHelper.t("Yoga Poses", "योगासने", "योगासन"),
                  style: AppTextStyles.heading2(),
                ),
                const Spacer(),
                AppChip(label: '${poseDetails.length}'),
              ],
            ),
          ),
          for (var pose in poseDetails) _poseCard(pose),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.air_rounded,
                    color: AppColors.accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  LanguageHelper.t(
                    "Breathing Techniques",
                    "प्राणायाम",
                    "श्वसन तकनीक",
                  ),
                  style: AppTextStyles.heading2(),
                ),
                const Spacer(),
                AppChip(label: '${breathingDetails.length}'),
              ],
            ),
          ),
          for (var item in breathingDetails) _breathingCard(item),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppPrimaryButton(
              label: LanguageHelper.t(
                "🧘 Generate Yoga Routine",
                "🧘 योगा दिनचर्या तयार करा",
                "🧘 योगा दिनचर्या बनाएं",
              ),
              icon: Icons.playlist_add_check_rounded,
              onPressed: () async {
                try {
                  setState(() => loading = true);
                  final poseIds = poseDetails.map<int>((p) => p['id']).toList();
                  final breathingIds = breathingDetails
                      .map<int>((b) => b['id'])
                      .toList();
                  final provider = Provider.of<UserProvider>(
                    context,
                    listen: false,
                  );
                  final duration = provider.goals.routineDuration ?? 30;
                  final routine = await ApiService.generateRoutine(
                    poseIds,
                    breathingIds,
                    duration,
                    provider.profile.userId,
                  );
                  if (!mounted) return;
                  setState(() => loading = false);
                  if (routine != null)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoutineScreen(routine: routine),
                      ),
                    );
                  else
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Failed to generate routine"),
                      ),
                    );
                } catch (e) {
                  if (!mounted) return;
                  setState(() => loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Routine generation error")),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        Text(
                          LanguageHelper.t(
                            "Recommendations",
                            "शिफारसी",
                            "सिफारिशें",
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _loadRecommendations,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          LanguageHelper.t(
                            "AI-curated for your health goals.",
                            "AI द्वारे तुमच्या आरोग्य लक्ष्यांसाठी निवडले.",
                            "AI द्वारा आपके स्वास्थ्य लक्ष्यों के लिए चुना गया",
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(width: 3),
                        NormalLanguageSwitcher(
                          onLanguageChanged: () {
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: loading
                    ? const AppLoadingIndicator(
                        message: 'Finding best yoga for you...',
                      )
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
