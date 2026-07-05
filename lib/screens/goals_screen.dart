import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/goals.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import '../services/api_service.dart';
import '../widgets/language_switcher.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String level = "Beginner";
  int routineDuration = 30;
  final timeController = TextEditingController(text: "30");

  List<String> painAreas = [];
  List<String> goalsList = [];

  final pains = ["Back", "Neck", "Knee", "Shoulder", "Waist", "Wrist"];
  final goalsOptions = [
    "Flexibility",
    "Stress Relief",
    "Strength",
    "Posture Correction",
    "Weight Loss",
  ];
  final levels = ["Beginner", "Intermediate", "Advanced"];

  final List<IconData> painIcons = [
    Icons.accessibility_new_rounded,
    Icons.self_improvement,
    Icons.directions_run_rounded,
    Icons.sports_gymnastics,
    Icons.fitness_center_rounded,
    Icons.pan_tool_outlined,
  ];

  final List<IconData> goalIcons = [
    Icons.airline_seat_flat_angled_rounded,
    Icons.spa_rounded,
    Icons.fitness_center_rounded,
    Icons.straighten_rounded,
    Icons.monitor_weight_outlined,
  ];

  String getLevelDisplay(String level) {
    switch (level) {
      case "Beginner":
        return LanguageHelper.t("Beginner", "प्राथमिक", "शुरुआती");
      case "Intermediate":
        return LanguageHelper.t("Intermediate", "मध्यम", "मध्यम");
      case "Advanced":
        return LanguageHelper.t("Advanced", "प्रगत", "प्रगत");
      default:
        return level;
    }
  }

  String getPainDisplay(String pain) {
    switch (pain) {
      case "Back":
        return LanguageHelper.t("Back", "पाठ", "पीठ");
      case "Neck":
        return LanguageHelper.t("Neck", "मान", "गर्दन");
      case "Knee":
        return LanguageHelper.t("Knee", "गुडघा", "घुटना");
      case "Shoulder":
        return LanguageHelper.t("Shoulder", "खांदा", "कंधा");
      case "Waist":
        return LanguageHelper.t("Waist", "कंबर", "कमर");
      case "Wrist":
        return LanguageHelper.t("Wrist", "मनगट", "कलाई");
      default:
        return pain;
    }
  }

  String getGoalDisplay(String goal) {
    switch (goal) {
      case "Flexibility":
        return LanguageHelper.t("Flexibility", "लवचिकता", "लचीलापन");
      case "Stress Relief":
        return LanguageHelper.t("Stress Relief", "ताण कमी", "तनाव राहत");
      case "Strength":
        return LanguageHelper.t("Strength", "शक्ती", "ताकत");
      case "Posture Correction":
        return LanguageHelper.t(
          "Posture Correction",
          "स्थिती सुधारणा",
          "मुद्रा सुधार",
        );
      case "Weight Loss":
        return LanguageHelper.t("Weight Loss", "वजन कमी", "वजन घटाना");
      default:
        return goal;
    }
  }

  void finish() {
    final provider = Provider.of<UserProvider>(context, listen: false);
    provider.setGoals(
      Goals(
        routineDuration: routineDuration,
        focusBodyParts: painAreas,
        tags: goalsList,
      ),
    );

    // Persist the full health profile so it survives across sessions
    if (provider.profile.userId.isNotEmpty) {
      ApiService.saveHealthProfile(provider.profile.userId, {
        'height': provider.healthInfo.height,
        'weight': provider.healthInfo.weight,
        'activityLevel': level,
        'medicalConditions': provider.healthInfo.medicalConditions,
        'focusBodyParts': painAreas,
        'goalTags': goalsList,
        'routineDuration': routineDuration,
      });
    }

    // End onboarding at the shell, opening the Explore (Recommendations) tab
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 1)),
      (route) => false,
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Text(title, style: AppTextStyles.heading3()),
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
              // ── Header ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: const BoxDecoration(
                  gradient: AppGradients.welcomeBg,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
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

                        // Reusable Language Switcher
                        LanguageSwitcher(
                          popupOffset: const Offset(25, 20),
                          onLanguageChanged: () {
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LanguageHelper.t(
                        "Your Goals",
                        "तुमचे आरोग्य ध्येय ",
                        "आपके लक्ष्य",
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LanguageHelper.t(
                        "Personalize your wellness journey",
                        "आपला निरोगी होण्यासाठीचा प्रवास वैयक्तिकृत करा",
                        "अपनी आरोग्य यात्रा को वैयक्तिकृत करें",
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _activeDot(),
                        _line(),
                        _activeDot(),
                        _line(),
                        _activeDot(),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Body ──────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Yoga Level
                      _sectionHeader(
                        LanguageHelper.t("Yoga Level", "योग स्तर", "योग स्तर"),
                        Icons.bar_chart_rounded,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: levels.map((l) {
                            final sel = level == l;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => level = l),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.accent
                                        : AppColors.bgCard,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: sel
                                          ? AppColors.accent
                                          : AppColors.divider,
                                      width: 1.5,
                                    ),
                                    boxShadow: sel
                                        ? AppShadows.button
                                        : AppShadows.soft,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        l == "Beginner"
                                            ? Icons.star_border_rounded
                                            : l == "Intermediate"
                                            ? Icons.star_half_rounded
                                            : Icons.star_rounded,
                                        color: sel
                                            ? Colors.white
                                            : AppColors.accent,
                                        size: 22,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        getLevelDisplay(l),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: sel
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Daily Time
                      _sectionHeader(
                        LanguageHelper.t(
                          "Daily Time (min)",
                          "दररोज वेळ (मिनिटे)",
                          "दैनिक समय (मिनट)",
                        ),
                        Icons.timer_outlined,
                      ),
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _stepBtn(Icons.remove_rounded, () {
                              if (routineDuration > 5) {
                                setState(() {
                                  routineDuration--;
                                  timeController.text = routineDuration
                                      .toString();
                                });
                              }
                            }),
                            Expanded(
                              child: Center(
                                child: SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: timeController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                    ),
                                    onChanged: (v) {
                                      final val = int.tryParse(v);
                                      if (val != null) routineDuration = val;
                                    },
                                  ),
                                ),
                              ),
                            ),
                            _stepBtn(Icons.add_rounded, () {
                              setState(() {
                                routineDuration++;
                                timeController.text = routineDuration
                                    .toString();
                              });
                            }),
                          ],
                        ),
                      ),

                      // Pain Areas
                      _sectionHeader(
                        LanguageHelper.t(
                          "Pain Areas",
                          "वेदना क्षेत्रे",
                          "दर्द क्षेत्र",
                        ),
                        Icons.healing_rounded,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(pains.length, (i) {
                            final p = pains[i];
                            final sel = painAreas.contains(p);
                            return AppChip(
                              label: getPainDisplay(p),
                              selected: sel,
                              icon: painIcons[i],
                              onTap: () => setState(
                                () => sel
                                    ? painAreas.remove(p)
                                    : painAreas.add(p),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Goals
                      _sectionHeader(
                        LanguageHelper.t(
                          "Health Goals",
                          "आरोग्य लक्ष्ये",
                          "स्वास्थ्य लक्ष्य",
                        ),
                        Icons.flag_rounded,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(goalsOptions.length, (i) {
                            final g = goalsOptions[i];
                            final sel = goalsList.contains(g);
                            return AppChip(
                              label: getGoalDisplay(g),
                              selected: sel,
                              icon: goalIcons[i],
                              onTap: () => setState(
                                () => sel
                                    ? goalsList.remove(g)
                                    : goalsList.add(g),
                              ),
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AppPrimaryButton(
                          label: LanguageHelper.t(
                            "Get My Recommendations",
                            "शिफारसी मिळवा",
                            "सिफारिशें प्राप्त करें",
                          ),
                          onPressed: finish,
                          icon: Icons.auto_awesome_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 1.2),
        ),
        child: Icon(icon, color: AppColors.accent, size: 20),
      ),
    );
  }

  Widget _activeDot() => Container(
    width: 28,
    height: 28,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
    ),
    child: const Center(
      child: Icon(Icons.check_rounded, size: 16, color: AppColors.accent),
    ),
  );

  Widget _line() => Container(
    width: 40,
    height: 2,
    margin: const EdgeInsets.only(left: 4, right: 4),
    color: Colors.white.withOpacity(0.4),
  );
}
