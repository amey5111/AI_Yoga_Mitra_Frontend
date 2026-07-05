import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/user_provider.dart';
import '../models/health_info.dart';
import '../services/api_service.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import 'goals_screen.dart';
import '../widgets/language_switcher.dart';

class HealthInfoScreen extends StatefulWidget {
  /// When true, the screen edits an existing profile (prefilled) and saves
  /// back instead of continuing the signup wizard.
  final bool editMode;
  const HealthInfoScreen({super.key, this.editMode = false});

  @override
  State<HealthInfoScreen> createState() => _HealthInfoScreenState();
}

class _HealthInfoScreenState extends State<HealthInfoScreen> {
  double height = 60.0;
  double weight = 60.0;

  final heightController = TextEditingController();
  final weightController = TextEditingController();
  List<String> selectedConditions = [];
  final otherController = TextEditingController();
  bool _analyzingReport = false;
  bool _saving = false;

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

  final List<String> conditions = [
    "Diabetes",
    "Thyroid",
    "High BP",
    "PCOS",
    "Arthritis",
    "Asthma",
    "Leg Injury",
  ];

  final List<IconData> conditionIcons = [
    Icons.bloodtype_outlined,
    Icons.monitor_heart_outlined,
    Icons.favorite_outline,
    Icons.female_rounded,
    Icons.accessibility_new_rounded,
    Icons.air_outlined,
    Icons.directions_walk_outlined,
  ];

  String getConditionDisplay(String condition) {
    switch (condition) {
      case "Diabetes":
        return LanguageHelper.t("Diabetes", "मधुमेह", "मधुमेह");
      case "Thyroid":
        return LanguageHelper.t("Thyroid", "थायरॉईड", "थायरॉइड");
      case "High BP":
        return LanguageHelper.t("High BP", "उच्च रक्तदाब", "उच्च रक्तचाप");
      case "PCOS":
        return LanguageHelper.t("PCOS", "पीसीओएस", "पीसीओएस");
      case "Arthritis":
        return LanguageHelper.t("Arthritis", "सांधेदुखी", "गठिया");
      case "Asthma":
        return LanguageHelper.t("Asthma", "दमा", "दमा");
      case "Leg Injury":
        return LanguageHelper.t("Leg Injury", "पायाला दुखापत", "पैर की चोट");
      default:
        return condition;
    }
  }

  @override
  void initState() {
    super.initState();
    // Prefill from the stored profile (edit mode, or returning users)
    final provider = Provider.of<UserProvider>(context, listen: false);
    final hi = provider.healthInfo;
    if (hi.height > 0) height = hi.height;
    if (hi.weight > 0) weight = hi.weight;
    for (final c in hi.medicalConditions) {
      if (conditions.contains(c)) {
        selectedConditions.add(c);
      } else if (c.trim().isNotEmpty) {
        otherController.text = otherController.text.isEmpty
            ? c
            : '${otherController.text}, $c';
      }
    }
    heightController.text = height.toStringAsFixed(1);
    weightController.text = weight.toStringAsFixed(1);
  }

  void updateHeight(double value) {
    if (value < 10) return;
    setState(() {
      height = value;
      heightController.text = value.toStringAsFixed(1);
    });
  }

  void updateWeight(double value) {
    if (value < 5) return;
    setState(() {
      weight = value;
      weightController.text = value.toStringAsFixed(1);
    });
  }

  /* ── Medical Report Upload & AI analysis ─────────────────────────────── */

  static const _mimeByExt = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  Future<void> _uploadReport() async {
    if (_analyzingReport) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      final ext = (file.extension ?? '').toLowerCase();
      final mime = _mimeByExt[ext];

      if (bytes == null || mime == null) {
        _showSnack(
          LanguageHelper.t(
            "Could not read file. Use PDF, JPG or PNG.",
            "फाईल वाचता आली नाही. PDF, JPG किंवा PNG वापरा.",
            "फ़ाइल नहीं पढ़ सके. PDF, JPG या PNG उपयोग करें.",
          ),
        );
        return;
      }

      if (bytes.length > 10 * 1024 * 1024) {
        _showSnack(
          LanguageHelper.t(
            "File too large (max 10 MB).",
            "फाईल खूप मोठी आहे (कमाल १० MB).",
            "फ़ाइल बहुत बड़ी है (अधिकतम 10 MB).",
          ),
        );
        return;
      }

      setState(() => _analyzingReport = true);

      final analysis = await ApiService.analyzeHealthReport(
        fileBase64: base64Encode(bytes),
        mimeType: mime,
        language: langCode,
      );

      if (!mounted) return;

      final known = (analysis['knownConditions'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      final others = (analysis['otherConditions'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      final summary = (analysis['summary'] ?? '').toString();
      final cautions = (analysis['cautions'] ?? '').toString();

      setState(() {
        _analyzingReport = false;
        for (final c in known) {
          if (conditions.contains(c) && !selectedConditions.contains(c)) {
            selectedConditions.add(c);
          }
        }
        if (others.isNotEmpty) {
          final existing = otherController.text.trim();
          final merged = [
            if (existing.isNotEmpty) existing,
            ...others,
          ].join(', ');
          otherController.text = merged;
        }
      });

      // Persist the report to the backend + provider (survives sessions,
      // editable/deletable later from Settings)
      final provider = Provider.of<UserProvider>(context, listen: false);
      final reportMap = {
        'knownConditions': known,
        'otherConditions': others,
        'summary': summary,
        'cautions': cautions,
        'fileName': file.name,
        'uploadedAt': DateTime.now().toIso8601String(),
      };
      provider.setMedicalReport(reportMap);
      if (provider.profile.userId.isNotEmpty) {
        try {
          await ApiService.saveMedicalReport(
            provider.profile.userId,
            reportMap,
          );
        } catch (_) {}
      }

      // Result dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LanguageHelper.t(
                    "Report Analyzed",
                    "अहवाल तपासला",
                    "रिपोर्ट का विश्लेषण हुआ",
                  ),
                  style: AppTextStyles.heading3(),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (known.isNotEmpty || others.isNotEmpty) ...[
                  Text(
                    LanguageHelper.t(
                      "Conditions detected & pre-filled:",
                      "आढळलेल्या व भरलेल्या स्थिती:",
                      "पाई गई और भरी गई स्थितियाँ:",
                    ),
                    style: AppTextStyles.bodyMedium(),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in [...known, ...others])
                        AppChip(label: c, selected: true),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (summary.isNotEmpty) ...[
                  Text(summary, style: AppTextStyles.body()),
                  const SizedBox(height: 10),
                ],
                if (cautions.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(cautions, style: AppTextStyles.caption()),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LanguageHelper.t("OK", "ठीक आहे", "ठीक है")),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzingReport = false);
      _showSnack(
        LanguageHelper.t(
          "Report analysis failed. Try a clearer photo.",
          "अहवाल विश्लेषण अयशस्वी. स्पष्ट फोटो वापरून पहा.",
          "रिपोर्ट विश्लेषण विफल. साफ़ फोटो आज़माएं.",
        ),
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> next() async {
    final provider = Provider.of<UserProvider>(context, listen: false);
    List<String> finalConditions = [...selectedConditions];
    if (otherController.text.isNotEmpty) {
      finalConditions.addAll(
        otherController.text
            .split(",")
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }
    provider.setHealthInfo(
      HealthInfo(
        height: height,
        weight: weight,
        medicalConditions: finalConditions,
        activityLevel: provider.healthInfo.activityLevel,
      ),
    );

    if (widget.editMode) {
      // Persist and return to settings
      setState(() => _saving = true);
      try {
        await ApiService.saveHealthProfile(provider.profile.userId, {
          'height': height,
          'weight': weight,
          'activityLevel': provider.healthInfo.activityLevel,
          'medicalConditions': finalConditions,
          'focusBodyParts': provider.goals.focusBodyParts,
          'goalTags': provider.goals.tags,
          'routineDuration': provider.goals.routineDuration,
        });
      } catch (_) {}
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.pop(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GoalsScreen()),
    );
  }

  Widget _metricCard({
    required String label,
    required String unit,
    required double value,
    required double min,
    required double max,
    required IconData icon,
    required TextEditingController controller,
    required Function(double) onChanged,
    required Function(double) onStep,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Text(label, style: AppTextStyles.heading3()),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _stepBtn(Icons.remove_rounded, () => onStep(value - 0.5)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  onChanged: (v) {
                    final val = double.tryParse(v);
                    if (val != null) onChanged(val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              _stepBtn(Icons.add_rounded, () => onStep(value + 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              trackHeight: 4,
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.chipBg,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withOpacity(0.12),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${min.toInt()}', style: AppTextStyles.caption()),
              Text('${max.toInt()}', style: AppTextStyles.caption()),
            ],
          ),
        ],
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
                        "Health Info",
                        "आरोग्य माहिती",
                        "स्वास्थ्य जानकारी",
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
                        "Help us personalize your yoga routine",
                        "आपली योगा दिनचर्या वैयक्तिकृत करण्यात मदत करा",
                        "आपकी योगा दिनचर्या को व्यक्तिगत बनाने में मदद करें",
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _dot(true),
                        _line(),
                        _dot(true),
                        _line(),
                        _dot(false),
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
                      const SizedBox(height: 16),

                      _metricCard(
                        label: LanguageHelper.t("Height", "उंची", "ऊंचाई"),
                        unit: LanguageHelper.t("inches", "इंच", "इंच"),
                        value: height,
                        min: 36,
                        max: 96,
                        icon: Icons.height_rounded,
                        controller: heightController,
                        onChanged: (v) => setState(() {
                          height = v;
                          heightController.text = v.toStringAsFixed(1);
                        }),
                        onStep: updateHeight,
                      ),

                      _metricCard(
                        label: LanguageHelper.t("Weight", "वजन", "वजन"),
                        unit: "kg",
                        value: weight,
                        min: 20,
                        max: 180,
                        icon: Icons.monitor_weight_outlined,
                        controller: weightController,
                        onChanged: (v) => setState(() {
                          weight = v;
                          weightController.text = v.toStringAsFixed(1);
                        }),
                        onStep: updateWeight,
                      ),

                      // ── AI Medical Report Upload ─────────────────────
                      AppCard(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.cardGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.upload_file_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    LanguageHelper.t(
                                      "Upload Medical Report (AI)",
                                      "वैद्यकीय अहवाल अपलोड करा (AI)",
                                      "मेडिकल रिपोर्ट अपलोड करें (AI)",
                                    ),
                                    style: AppTextStyles.heading3(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              LanguageHelper.t(
                                "Upload a PDF or photo of your report — AI will detect your conditions and fill them below automatically.",
                                "PDF किंवा अहवालाचा फोटो अपलोड करा — AI तुमच्या स्थिती ओळखून खाली आपोआप भरेल.",
                                "PDF या रिपोर्ट की फोटो अपलोड करें — AI आपकी स्थितियाँ पहचानकर नीचे स्वतः भर देगा.",
                              ),
                              style: AppTextStyles.caption(),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _analyzingReport ? null : _uploadReport,
                                icon: _analyzingReport
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.accent,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.document_scanner_outlined,
                                        size: 18,
                                      ),
                                label: Text(
                                  _analyzingReport
                                      ? LanguageHelper.t(
                                          "Analyzing report...",
                                          "अहवाल तपासत आहे...",
                                          "रिपोर्ट की जाँच हो रही है...",
                                        )
                                      : LanguageHelper.t(
                                          "Choose PDF / Image",
                                          "PDF / फोटो निवडा",
                                          "PDF / फोटो चुनें",
                                        ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.chipBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.medical_information_outlined,
                                color: AppColors.accent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              LanguageHelper.t(
                                "Medical Conditions",
                                "वैद्यकीय स्थिती",
                                "चिकित्सा स्थितियाँ",
                              ),
                              style: AppTextStyles.heading3(),
                            ),
                          ],
                        ),
                      ),

                      // Condition chips
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(conditions.length, (i) {
                            final c = conditions[i];
                            final sel = selectedConditions.contains(c);
                            return GestureDetector(
                              onTap: () => setState(() {
                                sel
                                    ? selectedConditions.remove(c)
                                    : selectedConditions.add(c);
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppColors.accent
                                      : AppColors.bgCard,
                                  borderRadius: BorderRadius.circular(12),
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      conditionIcons[i],
                                      size: 16,
                                      color: sel
                                          ? Colors.white
                                          : AppColors.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      getConditionDisplay(c),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextFormField(
                          controller: otherController,
                          decoration: appInputDecoration(
                            label: LanguageHelper.t(
                              "Other conditions (comma separated)",
                              "इतर (स्वल्पविरामाने वेगळे करा)",
                              "अन्य (कॉमा से अलग करें)",
                            ),
                            prefixIcon: Icons.add_circle_outline_rounded,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.accent.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: AppColors.accent,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  LanguageHelper.t(
                                    "Your health data is securely stored locally on your device.",
                                    "आपला आरोग्य डेटा आपल्या डिव्हाइसवर सुरक्षित आहे.",
                                    "आपका स्वास्थ्य डेटा आपके डिवाइस पर सुरक्षित है.",
                                  ),
                                  style: AppTextStyles.caption(
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: AppPrimaryButton(
                          label: widget.editMode
                              ? LanguageHelper.t(
                                  "Save Changes", "बदल जतन करा", "बदलाव सहेजें")
                              : LanguageHelper.t(
                                  "Next: Goals", "पुढे: लक्ष्ये", "आगे: लक्ष्य"),
                          onPressed: _saving ? null : next,
                          loading: _saving,
                          icon: widget.editMode
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
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

  Widget _dot(bool active) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? Colors.white : Colors.white.withOpacity(0.3),
    ),
    child: Center(
      child: Icon(
        Icons.check_rounded,
        size: 16,
        color: active ? AppColors.accent : Colors.transparent,
      ),
    ),
  );

  Widget _line() => Container(
    width: 40,
    height: 2,
    margin: const EdgeInsets.only(bottom: 0, left: 4, right: 4),
    color: Colors.white.withOpacity(0.3),
  );
}
