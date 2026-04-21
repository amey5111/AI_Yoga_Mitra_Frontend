import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../utils/language_helper.dart';
import 'pose_detail_screen.dart';
import 'breathing_detail_screen.dart';

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

  Color get purple => const Color(0xFF7C4DFF);
  Color get purpleDark => const Color(0xFF5E35B1);

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

    debugPrint("=== _buildOtherRecommendations called");
    debugPrint("=== routineItems: ${_routineItems.length}");
    debugPrint("=== provider.poseDetails: ${provider.poseDetails.length}");
    debugPrint(
      "=== provider.breathingDetails: ${provider.breathingDetails.length}",
    );

    final Set<int> routineIds = _routineItems
        .map((e) => _toInt(e['id']))
        .toSet();

    _otherPoses = provider.poseDetails
        .where((p) => !routineIds.contains(_toInt(p['id'])))
        .map((p) {
          final copy = Map<String, dynamic>.from(p);
          copy['type'] = 'pose';
          return copy;
        })
        .toList();

    _otherBreathing = provider.breathingDetails
        .where((b) => !routineIds.contains(_toInt(b['id'])))
        .map((b) {
          final copy = Map<String, dynamic>.from(b);
          copy['type'] = 'breathing';
          return copy;
        })
        .toList();

    debugPrint("=== routineIds: $routineIds");
    debugPrint("=== otherPoses: ${_otherPoses.length}");
    debugPrint("=== otherBreathing: ${_otherBreathing.length}");
  }

  void _removeFromRoutine(int index) {
    final removed = Map<String, dynamic>.from(_routineItems[index]);
    setState(() {
      _routineItems.removeAt(index);
      if (removed['type'] == 'breathing') {
        _otherBreathing.add(removed);
      } else {
        _otherPoses.add(removed);
      }
    });
  }

  void _addToRoutine(Map<String, dynamic> item, bool isBreathing) {
    final copy = Map<String, dynamic>.from(item);
    copy['type'] = isBreathing ? 'breathing' : 'pose';
    final itemId = _toInt(copy['id']);

    setState(() {
      _routineItems.add(copy);
      if (isBreathing) {
        _otherBreathing.removeWhere((b) => _toInt(b['id']) == itemId);
      } else {
        _otherPoses.removeWhere((p) => _toInt(p['id']) == itemId);
      }
    });
  }

  Future<void> _updateRoutine() async {
    if (_routineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              "Please add at least one item to your routine.",
              "किमान एक आयटम दिनचर्येत जोडा.",
              "कृपया कम से कम एक आइटम दिनचर्या में जोड़ें।",
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

    debugPrint("=== Updating: poseIds=$poseIds breathingIds=$breathingIds");

    try {
      final newRoutine = await ApiService.updateUserRoutine(
        userId,
        poseIds,
        breathingIds,
      );

      debugPrint("=== newRoutine: $newRoutine");
      debugPrint("=== newRoutine keys: ${newRoutine?.keys}");

      if (!mounted) return;
      setState(() => _updating = false);

      if (newRoutine != null) {
        // ── Pop back to RoutineScreen and pass the new routine as result ──
        // RoutineScreen's editRoutine handler awaits this push and then
        // calls _loadRoutine() which fetches fresh from DB
        Navigator.pop(context, newRoutine);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                "Failed to update routine. Please try again.",
                "दिनचर्या अपडेट करणे अयशस्वी. पुन्हा प्रयत्न करा.",
                "दिनचर्या अपडेट करना विफल। कृपया पुनः प्रयास करें।",
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("=== _updateRoutine error: $e");
      if (!mounted) return;
      setState(() => _updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              "Something went wrong. Please try again.",
              "काहीतरी चूक झाली. पुन्हा प्रयत्न करा.",
              "कुछ गलत हो गया। कृपया पुनः प्रयास करें।",
            ),
          ),
        ),
      );
    }
  }

  String _formatDuration(Map<String, dynamic> item) {
    final secs = (item['duration'] ?? item['duration_seconds'] ?? 60) as num;
    final mins = (secs / 60).round();
    return "$mins ${t('mins', 'मिनिटे', 'मिनट')}";
  }

  void _openVideo(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildRoutineItem(Map<String, dynamic> item, int index) {
    final name = item['name']?[langCode] ?? '';
    final duration = _formatDuration(item);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Index circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: purple, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              "${index + 1}",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "${t('Duration', 'कालावधी', 'समय')} : $duration",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // Remove button
          TextButton(
            onPressed: () => _removeFromRoutine(index),
            style: TextButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              t("Remove", "काढा", "हटाएं"),
              style: GoogleFonts.inter(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> item, bool isBreathing) {
    final name = item['name']?[langCode] ?? '';
    final secs = (item['duration_seconds'] ?? 60) as num;
    final mins = (secs / 60).round();
    final durationStr = "$mins ${t('mins', 'मिनिटे', 'मिनट')}";
    final typeLabel = isBreathing
        ? t("Breathing", "प्राणायाम", "श्वसन")
        : t("Yoga", "योग", "योग");
    final reason = item['reason']?[langCode] ?? '';
    final imageUrl = ApiService.resolveImageUrl(item['image_url']);
    final video = item['video']?[langCode]?['youtube_url'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (imageUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Row(
              children: [
                Text(
                  typeLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "•",
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                const SizedBox(width: 8),
                Text(
                  "${t('Duration', 'कालावधी', 'समय')} : $durationStr",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Info / Video / Add to Routine row
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(
              children: [
                // Info
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => isBreathing
                          ? BreathingDetailScreen(id: _toInt(item['id']))
                          : PoseDetailScreen(poseId: _toInt(item['id'])),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description,
                          size: 14,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t("Info", "माहिती", "जानकारी"),
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Video
                InkWell(
                  onTap: () => _openVideo(video),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.play_circle,
                          size: 14,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t("Video", "व्हिडिओ", "वीडियो"),
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Add to Routine
                ElevatedButton(
                  onPressed: () => _addToRoutine(item, isBreathing),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    t(
                      "Add to Routine",
                      "दिनचर्येत जोडा",
                      "दिनचर्या में जोड़ें",
                    ),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Reason banner
          if (reason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: purple.withOpacity(0.07),
              child: Text(
                "${t('Best for you because:', 'तुमच्यासाठी सर्वोत्तम:', 'आपके लिए सर्वोत्तम:')} $reason",
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: purpleDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasOthers = _otherPoses.isNotEmpty || _otherBreathing.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          t(
            "Customize your Yoga Routine",
            "तुमची योगा दिनचर्या सानुकूलित करा",
            "अपनी योगा दिनचर्या अनुकूलित करें",
          ),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 16),
              children: [
                // ── Current routine items ────────────────────────────
                if (_routineItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        t(
                          "Your routine is empty.\nAdd poses from below.",
                          "तुमची दिनचर्या रिकामी आहे.\nखाली पोझेस जोडा.",
                          "आपकी दिनचर्या खाली है।\nनीचे से जोड़ें।",
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  for (int i = 0; i < _routineItems.length; i++)
                    _buildRoutineItem(_routineItems[i], i),

                // ── Other recommendations ────────────────────────────
                if (hasOthers) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("✨ ", style: TextStyle(fontSize: 18)),
                        Expanded(
                          child: Text(
                            t(
                              "Other Yoga and Breathing Techniques recommended for you",
                              "तुमच्यासाठी सुचवलेले इतर योगासने आणि प्राणायाम",
                              "आपके लिए सुझाई गई अन्य योगासन और श्वसन तकनीकें",
                            ),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: purpleDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (var p in _otherPoses) _buildRecommendationCard(p, false),
                  for (var b in _otherBreathing)
                    _buildRecommendationCard(b, true),
                ] else if (_routineItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        t(
                          "All recommendations are in your routine!",
                          "सर्व शिफारसी तुमच्या दिनचर्येत आहेत!",
                          "सभी सिफारिशें आपकी दिनचर्या में हैं!",
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: purpleDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),

      // ── Sticky Update Routine button ──────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: _updating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text("✨", style: TextStyle(fontSize: 18)),
              label: Text(
                _updating
                    ? t("Updating...", "अपडेट होत आहे...", "अपडेट हो रहा है...")
                    : t(
                        "Update Routine",
                        "दिनचर्या अपडेट करा",
                        "दिनचर्या अपडेट करें",
                      ),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              onPressed: _updating ? null : _updateRoutine,
            ),
          ),
        ),
      ),
    );
  }
}
