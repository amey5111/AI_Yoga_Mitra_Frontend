import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/language_helper.dart';

class BreathingDetailScreen extends StatefulWidget {
  final int id;
  const BreathingDetailScreen({super.key, required this.id});

  @override
  State<BreathingDetailScreen> createState() => _BreathingDetailScreenState();
}

class _BreathingDetailScreenState extends State<BreathingDetailScreen> {
  Map<String, dynamic>? technique;
  bool loading = true;

  Color get purple => const Color(0xFF7C4DFF);
  Color get purpleDark => const Color(0xFF5E35B1);
  Color get chipBg => const Color(0xFFF3E5F5);
  Color get youtubeRed => const Color(0xFFE10600);

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

  String get videoSoonText {
    switch (LanguageHelper.currentLanguage) {
      case "मराठी":
        return "🎬 व्हिडिओ लवकरच येईल";
      case "हिंदी":
        return "🎬 वीडियो जल्द ही आएगा";
      default:
        return "🎬 Video will come soon";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTech();
  }

  Future<void> _loadTech() async {
    try {
      final t = await ApiService.fetchBreathingById(widget.id);
      technique = t;
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: purpleDark,
        ),
      ),
    );
  }

  Widget _section(String title, dynamic data) {
    if (data == null) return const SizedBox.shrink();

    List items = [];

    if (data is List) {
      items = data;
    } else {
      items = [data];
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (var e in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  e is Map ? "• ${e.values.join(" : ")}" : "• $e",
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVideoSheet(Map<String, dynamic> videos) async {
    String selectedLang = "en";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final video = videos[selectedLang];

            String formatDuration(int seconds) {
              final minutes = seconds ~/ 60;
              final remaining = seconds % 60;
              return "${minutes}:${remaining.toString().padLeft(2, '0')}";
            }

            String formatDate(String isoDate) {
              final date = DateTime.parse(isoDate);
              return "${date.day}/${date.month}/${date.year}";
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              builder: (_, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),

                      /// LANGUAGE BUTTONS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ["en", "hn", "mr"].map((code) {
                          final isSelected = selectedLang == code;
                          final label = code == "en"
                              ? "EN"
                              : code == "hn"
                              ? "हिंदी"
                              : "मराठी";

                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected
                                  ? purple
                                  : Colors.grey.shade200,
                            ),
                            onPressed: () {
                              setModalState(() {
                                selectedLang = code;
                              });
                            },
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      if (video == null)
                        Expanded(
                          child: Center(
                            child: Text(
                              videoSoonText,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.parse(video['youtube_url']);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.network(
                                          video['thumbnail'],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                Text(
                                  video['title'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  video['channel_name'],
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),

                                const SizedBox(height: 12),

                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _chip(
                                      "Duration: ${formatDuration(video['duration_seconds'])}",
                                    ),
                                    _chip(
                                      "Published: ${formatDate(video['published_at'])}",
                                    ),
                                    _chip("License: ${video['license']}"),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                Center(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: youtubeRed,
                                    ),
                                    onPressed: () async {
                                      final uri = Uri.parse(
                                        video['youtube_url'],
                                      );
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    child: const Text("Watch on YouTube"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (technique == null) {
      return const Scaffold(body: Center(child: Text("Technique not found")));
    }

    final t = technique!;
    final imageUrl = t['image_url'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: purple,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                t['name']?[langCode] ?? "",
                style: const TextStyle(color: Colors.white),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    Image.network(imageUrl, fit: BoxFit.cover),
                  Container(color: Colors.black26),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 10,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (t['category'] != null)
                        _chip(
                          "${LanguageHelper.t("Category", "वर्ग", "श्रेणी")}: ${t['category']?[langCode] ?? ""}",
                        ),
                      if (t['difficulty_level'] != null)
                        _chip(
                          "${LanguageHelper.t("Level", "पातळी", "स्तर")}: ${t['difficulty_level']?[langCode] ?? ""}",
                        ),
                      if (t['duration_seconds'] != null)
                        _chip("Time: ${t['duration_seconds']}s"),
                      if (t['repetitions'] != null)
                        _chip("Reps: ${t['repetitions']}"),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _section(
                  LanguageHelper.t(
                    "Primary Benefits",
                    "मुख्य फायदे",
                    "मुख्य लाभ",
                  ),
                  t['primary_benefits']?[langCode],
                ),

                _section(
                  LanguageHelper.t(
                    "Detailed Benefits",
                    "सविस्तर फायदे",
                    "विस्तृत लाभ",
                  ),
                  t['detailed_benefits']?[langCode],
                ),

                _section(
                  LanguageHelper.t(
                    "Target Systems",
                    "प्रभावित प्रणाली",
                    "लक्षित तंत्र",
                  ),
                  t['target_systems']?[langCode],
                ),

                _section(
                  LanguageHelper.t("Instructions", "सूचना", "निर्देश"),
                  t['instructions']?[langCode],
                ),

                _section(
                  LanguageHelper.t(
                    "Breathing Pattern",
                    "श्वसन पद्धत",
                    "श्वसन पैटर्न",
                  ),
                  t['breathing_pattern']?[langCode],
                ),

                _section(
                  LanguageHelper.t(
                    "Focus Points",
                    "एकाग्रता बिंदू",
                    "ध्यान बिंदु",
                  ),
                  t['focus_points']?[langCode],
                ),

                _section(
                  LanguageHelper.t("Precautions", "काळजी", "सावधानियां"),
                  t['precautions']?[langCode],
                ),

                _section(
                  LanguageHelper.t(
                    "Contraindications",
                    "टाळावयाच्या अवस्था",
                    "वर्जनाएं",
                  ),
                  t['contraindications']?[langCode],
                ),

                _section(
                  LanguageHelper.t("Modifications", "पर्याय", "संशोधन"),
                  t['modifications']?[langCode],
                ),

                _section(
                  LanguageHelper.t(
                    "Props Needed",
                    "आवश्यक साहित्य",
                    "आवश्यक उपकरण",
                  ),
                  t['props_needed']?[langCode],
                ),

                _section(
                  LanguageHelper.t(
                    "Time of Practice",
                    "सराव करण्याची वेळ",
                    "अभ्यास का समय",
                  ),
                  t['time_of_practice']?[langCode],
                ),

                const SizedBox(height: 20),

                if (t['video'] != null)
                  Center(
                    child: ElevatedButton(
                      onPressed: () => _openVideoSheet(t['video']),
                      child: const Text("Watch YouTube Video"),
                    ),
                  ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
