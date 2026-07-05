import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';

class DietScreen extends StatefulWidget {
  final bool embedded;
  const DietScreen({super.key, this.embedded = false});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _plan;
  String _planText = '';

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

  bool _started = false;

  @override
  void initState() {
    super.initState();
    // As an always-built shell tab, don't hit the AI on every app open —
    // wait for the user to tap "Generate". When pushed standalone, auto-run.
    if (!widget.embedded) {
      _started = true;
      _generate();
    } else {
      _loading = false;
    }
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _started = true;
      _error = null;
    });

    try {
      final provider = Provider.of<UserProvider>(context, listen: false);

      // Pull medical-report data so the diet is report-driven when available
      final report = provider.medicalReport;
      final reportSummary = (report?['summary'] ?? '').toString();
      final reportConditions = <String>[
        ...((report?['knownConditions'] as List?) ?? const [])
            .map((e) => e.toString()),
        ...((report?['otherConditions'] as List?) ?? const [])
            .map((e) => e.toString()),
      ];

      final result = await ApiService.dietRecommend(
        userProfile: {
          'ageGroup': provider.ageGroup,
          'gender': provider.gender,
        },
        healthInfo: provider.healthInfo.toJson(),
        goals: provider.goals.toJson(),
        language: langCode,
        reportSummary: reportSummary,
        reportConditions: reportConditions,
      );

      if (!mounted) return;
      if (result == null) {
        setState(() {
          _error = t(
            "Could not generate diet plan. Try again.",
            "आहार योजना तयार करता आली नाही. पुन्हा प्रयत्न करा.",
            "डाइट प्लान नहीं बन सका. पुनः प्रयास करें.",
          );
          _loading = false;
        });
        return;
      }

      setState(() {
        _plan = result['plan'] as Map<String, dynamic>?;
        _planText = (result['planText'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = t(
          "Could not generate diet plan. Try again.",
          "आहार योजना तयार करता आली नाही. पुन्हा प्रयत्न करा.",
          "डाइट प्लान नहीं बन सका. पुनः प्रयास करें.",
        );
        _loading = false;
      });
    }
  }

  List<String> _stringList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [v.toString()];
  }

  Widget _sectionCard(String title, IconData icon, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppColors.accent, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTextStyles.heading3())),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 5),
                    child: Icon(Icons.circle, size: 6, color: AppColors.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item, style: AppTextStyles.body())),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _intro() {
    final provider = Provider.of<UserProvider>(context, listen: false);
    final hasReport = provider.hasReport;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.restaurant_menu_rounded,
                  size: 52, color: Color(0xFF34C759)),
            ),
            const SizedBox(height: 18),
            Text(
              t("Your Personalized Diet", "तुमचा वैयक्तिक आहार",
                  "आपका वैयक्तिक आहार"),
              style: AppTextStyles.heading3(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasReport
                  ? t(
                      "AI will craft an Indian diet plan based on your medical report, health and goals.",
                      "AI तुमच्या अहवाल, आरोग्य व लक्ष्यांनुसार भारतीय आहार योजना तयार करेल.",
                      "AI आपकी रिपोर्ट, स्वास्थ्य व लक्ष्यों अनुसार भारतीय डाइट प्लान बनाएगा.",
                    )
                  : t(
                      "AI will craft an Indian diet plan based on your health info and goals.",
                      "AI तुमच्या आरोग्य माहिती व लक्ष्यांनुसार भारतीय आहार योजना तयार करेल.",
                      "AI आपकी स्वास्थ्य जानकारी व लक्ष्यों अनुसार भारतीय डाइट प्लान बनाएगा.",
                    ),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(),
            ),
            if (hasReport) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 6),
                    Text(
                      t("Using your report", "तुमचा अहवाल वापरत आहे",
                          "आपकी रिपोर्ट से"),
                      style: AppTextStyles.caption(color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            AppPrimaryButton(
              label: t("Generate Diet Plan", "आहार योजना तयार करा",
                  "डाइट प्लान बनाएं"),
              icon: Icons.auto_awesome_rounded,
              width: 250,
              onPressed: _generate,
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (!_started) return _intro();
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.restaurant_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(_error!, style: AppTextStyles.body()),
            const SizedBox(height: 20),
            AppPrimaryButton(
              label: t("Retry", "पुन्हा", "पुनः"),
              icon: Icons.refresh_rounded,
              onPressed: _generate,
              width: 160,
            ),
          ],
        ),
      );
    }

    // fallback: raw text
    if (_plan == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(_planText, style: AppTextStyles.body()),
      );
    }

    final meals = (_plan!['meals'] as Map<String, dynamic>?) ?? {};

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      children: [
        _sectionCard(
          t("Daily Guidelines", "दैनंदिन मार्गदर्शन", "दैनिक दिशानिर्देश"),
          Icons.tips_and_updates_outlined,
          _stringList(_plan!['daily_guidelines']),
        ),
        _sectionCard(
          t("Breakfast", "नाश्ता", "नाश्ता"),
          Icons.free_breakfast_outlined,
          _stringList(meals['breakfast']),
        ),
        _sectionCard(
          t("Mid-Morning", "सकाळचा खाऊ", "मध्य-सुबह"),
          Icons.apple_rounded,
          _stringList(meals['mid_morning']),
        ),
        _sectionCard(
          t("Lunch", "दुपारचे जेवण", "दोपहर का भोजन"),
          Icons.lunch_dining_outlined,
          _stringList(meals['lunch']),
        ),
        _sectionCard(
          t("Evening Snack", "संध्याकाळचा खाऊ", "शाम का नाश्ता"),
          Icons.emoji_food_beverage_outlined,
          _stringList(meals['evening_snack']),
        ),
        _sectionCard(
          t("Dinner", "रात्रीचे जेवण", "रात का भोजन"),
          Icons.dinner_dining_outlined,
          _stringList(meals['dinner']),
        ),
        _sectionCard(
          t("Foods To Avoid", "टाळावेत असे पदार्थ", "इनसे बचें"),
          Icons.do_not_disturb_alt_rounded,
          _stringList(_plan!['foods_to_avoid']),
        ),
        if ((_plan!['hydration'] ?? '').toString().isNotEmpty)
          _sectionCard(t("Hydration", "पाणी", "जल सेवन"), Icons.water_drop_outlined, [
            _plan!['hydration'].toString(),
          ]),
        if ((_plan!['note'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _plan!['note'].toString(),
                      style: AppTextStyles.caption(),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
              // ── Header ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                decoration: const BoxDecoration(
                  gradient: AppGradients.welcomeBg,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    if (!widget.embedded) ...[
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
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t("Diet Plan", "आहार योजना", "डाइट प्लान"),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            t(
                              "AI-personalized for your goals & health",
                              "तुमच्या लक्ष्यांसाठी AI-वैयक्तिकृत",
                              "आपके लक्ष्यों के लिए AI-वैयक्तिकृत",
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _loading ? null : _generate,
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
              ),
              Expanded(
                child: _loading
                    ? AppLoadingIndicator(
                        message: t(
                          "Creating your diet plan...",
                          "तुमची आहार योजना तयार होत आहे...",
                          "आपका डाइट प्लान बन रहा है...",
                        ),
                      )
                    : _content(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
