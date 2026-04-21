import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../utils/language_helper.dart';
import 'pose_detail_screen.dart';
import 'breathing_detail_screen.dart';
import 'routine_screen.dart';

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

  Color get purple => const Color(0xFF7C4DFF);
  Color get purpleDark => const Color(0xFF5E35B1);
  Color get chipBg => const Color(0xFFF3E5F5);

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
        return "आपके लिए चुना गया है क्योंकि:";
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
        provider.profile.userId, // ← ADD THIS
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

        // Attach AI reason to pose
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

      // ── Cache in provider so EditRoutineScreen can access without re-fetching ──
      provider.setRecommendations(
        poses: poseDetails,
        breathing: breathingDetails,
      );
    } catch (e) {
      error = "Could not load recommendations.";
    }

    if (mounted) setState(() => loading = false);
  }

  Widget _header(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 22, color: purpleDark),
          if (icon != null) const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: purpleDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _poseCard(Map<String, dynamic> pose) {
    final name = pose['name']?[langCode] ?? '';
    final diff = pose['difficulty_level']?[langCode] ?? '';
    final time = pose['duration_seconds'];
    final reps = pose['repetitions'];
    final benefits = (pose['primary_benefits']?[langCode] as List?) ?? [];
    final reason = pose['reason']?[langCode] ?? '';

    final imageUrl = ApiService.resolveImageUrl(pose['image_url']);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PoseDetailScreen(poseId: pose['id'])),
      ),
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(imageUrl, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Wrap(
                spacing: 15,
                runSpacing: 5,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 16, color: purpleDark),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          diff,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: purpleDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (time != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, size: 16, color: purpleDark),
                        const SizedBox(width: 6),
                        Text(
                          "${time}s",
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ],
                    ),
                  if (reps != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat, size: 16, color: purpleDark),
                        const SizedBox(width: 6),
                        Text(
                          "${reps}x",
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: benefits
                    .take(2)
                    .map(
                      (b) => Text(
                        "• $b",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            // ---------- AI REASON ----------
            if (reason.isNotEmpty)
              if (reason.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: purple.withOpacity(0.12),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pickedLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: purpleDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reason,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: purpleDark,
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

    return Card(
      elevation: 4,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: chipBg,
          child: Icon(Icons.self_improvement, color: purpleDark),
        ),
        title: Text(
          name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              benefits is List
                  ? benefits.join(", ")
                  : benefits?.toString() ?? '',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            if (reason.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickedLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: purpleDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: purpleDark,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: purpleDark),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BreathingDetailScreen(id: item['id']),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (error != null) {
      return Center(child: Text(error!));
    }

    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      child: ListView(
        children: [
          _header(
            LanguageHelper.t("Yoga Poses", "योगासने", "योगासन"),
            icon: Icons.self_improvement,
          ),
          for (var pose in poseDetails) _poseCard(pose),
          const SizedBox(height: 10),
          _header(
            LanguageHelper.t(
              "Breathing Techniques",
              "प्राणायाम",
              "श्वसन तकनीक",
            ),
            icon: Icons.air,
          ),
          for (var item in breathingDetails) _breathingCard(item),

          const SizedBox(height: 20),

          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.playlist_add_check),
              label: Text(
                LanguageHelper.t(
                  "🧘‍♀️ Generate Yoga Routine",
                  "🧘‍♀️ योगा दिनचर्या तयार करा",
                  "🧘‍♀️ योगा दिनचर्या बनाएं",
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                try {
                  setState(() {
                    loading = true;
                  });

                  // Collect pose IDs
                  final poseIds = poseDetails.map<int>((p) => p['id']).toList();

                  // Collect breathing IDs
                  final breathingIds = breathingDetails
                      .map<int>((b) => b['id'])
                      .toList();

                  // Get routine duration from user goals
                  final provider = Provider.of<UserProvider>(
                    context,
                    listen: false,
                  );

                  final duration = provider.goals.routineDuration ?? 30;

                  // Call backend routine generator
                  final routine = await ApiService.generateRoutine(
                    poseIds,
                    breathingIds,
                    duration,
                    provider.profile.userId,
                  );

                  if (!mounted) return;

                  setState(() {
                    loading = false;
                  });

                  if (routine != null) {
                    // Navigate to Routine Screen (we will build this next)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoutineScreen(routine: routine),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Failed to generate routine"),
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;

                  setState(() {
                    loading = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Routine generation error")),
                  );
                }
              },
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          LanguageHelper.t("Recommendations", "शिफारसी", "सिफारिशें"),
        ),
        backgroundColor: purple,
        foregroundColor: Colors.white,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }
}
