import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../services/reminder_service.dart';
import '../services/reminder_storage.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'health_info_screen.dart';
import 'progress_dashboard_screen.dart';
import '../services/voice_service.dart';
import '../Widgets/normal_language_switcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    // Let the "logout" voice command work from anywhere
    VoiceService.instance.addAction('logout', () => _logout());
    // Voice: edit health data ("change weight to 50", "gender male")
    VoiceService.instance.setProfileEditHandler(_handleVoiceEdit);
  }

  int? _parseNumber(String s) {
    final digit = RegExp(r'\d+').firstMatch(s);
    if (digit != null) return int.tryParse(digit.group(0)!);
    const units = {
      'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
      'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
      'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
      'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
    };
    const tens = {
      'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60,
      'seventy': 70, 'eighty': 80, 'ninety': 90,
    };
    int current = 0;
    bool found = false;
    for (final w in s.split(RegExp(r'\s+'))) {
      if (tens.containsKey(w)) {
        current += tens[w]!;
        found = true;
      } else if (units.containsKey(w)) {
        current += units[w]!;
        found = true;
      } else if (w == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
        found = true;
      }
    }
    return found ? current : null;
  }

  Future<void> _persistHealth(UserProvider provider) async {
    try {
      await ApiService.saveHealthProfile(provider.profile.userId, {
        'height': provider.healthInfo.height,
        'weight': provider.healthInfo.weight,
        'activityLevel': provider.healthInfo.activityLevel,
        'medicalConditions': provider.healthInfo.medicalConditions,
        'focusBodyParts': provider.goals.focusBodyParts,
        'goalTags': provider.goals.tags,
        'routineDuration': provider.goals.routineDuration,
      });
    } catch (_) {}
  }

  Future<void> _handleVoiceEdit(String raw) async {
    final s = raw.toLowerCase();
    final provider = Provider.of<UserProvider>(context, listen: false);
    final voice = VoiceService.instance;
    final n = _parseNumber(s);

    final isHeight = s.contains('height') ||
        s.contains('hight') ||
        s.contains('उंची') ||
        s.contains('ऊंचाई');
    // "weight" is often misheard as "wait" — treat it as weight when a number
    // is present and it isn't a height command.
    if (!isHeight &&
        (s.contains('weight') || s.contains('वजन') || s.contains('wait'))) {
      if (n == null) {
        await voice.speak(t("Say the weight, like change weight to 60.",
            "वजन सांगा, उदा. वजन ६० करा.", "वजन बताएं, जैसे वजन 60 करें."));
        return;
      }
      final w = n.clamp(20, 200).toDouble();
      provider.setHealthInfo(provider.healthInfo..weight = w);
      await _persistHealth(provider);
      if (mounted) setState(() {});
      await voice.speak(t("Weight set to ${w.toInt()} kilograms.",
          "वजन ${w.toInt()} किलो केले.", "वजन ${w.toInt()} किलो कर दिया."));
      return;
    }
    if (isHeight) {
      if (n == null) {
        await voice.speak(t("Say the height in inches, like change height to 65.",
            "उंची इंचात सांगा, उदा. उंची ६५ करा.",
            "ऊंचाई इंच में बताएं, जैसे ऊंचाई 65 करें."));
        return;
      }
      final h = n.clamp(36, 96).toDouble();
      provider.setHealthInfo(provider.healthInfo..height = h);
      await _persistHealth(provider);
      if (mounted) setState(() {});
      await voice.speak(t("Height set to ${h.toInt()} inches.",
          "उंची ${h.toInt()} इंच केली.", "ऊंचाई ${h.toInt()} इंच कर दी."));
      return;
    }
    if (s.contains('female') || s.contains('महिला') || s.contains('स्त्री')) {
      provider.setAgeGender(provider.ageGroup, 'Female');
      if (mounted) setState(() {});
      await voice.speak(t("Gender set to female.", "लिंग स्त्री केले.",
          "लिंग महिला कर दिया."));
      return;
    }
    if (s.contains('male') || s.contains('पुरुष')) {
      provider.setAgeGender(provider.ageGroup, 'Male');
      if (mounted) setState(() {});
      await voice.speak(t("Gender set to male.", "लिंग पुरुष केले.",
          "लिंग पुरुष कर दिया."));
      return;
    }
    await voice.speak(t("Say change weight, height, or gender.",
        "वजन, उंची किंवा लिंग बदला म्हणा.",
        "वजन, ऊंचाई या लिंग बदलें कहें."));
  }

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

  static const _mimeByExt = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _uploadReport() async {
    if (_analyzing) return;
    final provider = Provider.of<UserProvider>(context, listen: false);

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
        _snack(t("Use PDF, JPG or PNG.", "PDF, JPG किंवा PNG वापरा.",
            "PDF, JPG या PNG उपयोग करें."));
        return;
      }
      if (bytes.length > 10 * 1024 * 1024) {
        _snack(t("File too large (max 10 MB).", "फाईल खूप मोठी (कमाल १० MB).",
            "फ़ाइल बहुत बड़ी (अधिकतम 10 MB)."));
        return;
      }

      setState(() => _analyzing = true);

      final analysis = await ApiService.analyzeHealthReport(
        fileBase64: base64Encode(bytes),
        mimeType: mime,
        language: langCode,
      );

      final report = {
        'knownConditions':
            (analysis['knownConditions'] as List? ?? []).map((e) => e.toString()).toList(),
        'otherConditions':
            (analysis['otherConditions'] as List? ?? []).map((e) => e.toString()).toList(),
        'summary': (analysis['summary'] ?? '').toString(),
        'cautions': (analysis['cautions'] ?? '').toString(),
        'fileName': file.name,
        'uploadedAt': DateTime.now().toIso8601String(),
      };

      // Persist to backend + merge conditions into health info
      await ApiService.saveMedicalReport(provider.profile.userId, report);

      final known = (report['knownConditions'] as List).cast<String>();
      final merged = <String>{
        ...provider.healthInfo.medicalConditions,
        ...known,
      }.toList();
      provider.setHealthInfo(
        provider.healthInfo..medicalConditions = merged,
      );
      await ApiService.saveHealthProfile(provider.profile.userId, {
        'height': provider.healthInfo.height,
        'weight': provider.healthInfo.weight,
        'activityLevel': provider.healthInfo.activityLevel,
        'medicalConditions': merged,
        'focusBodyParts': provider.goals.focusBodyParts,
        'goalTags': provider.goals.tags,
        'routineDuration': provider.goals.routineDuration,
      });

      if (!mounted) return;
      provider.setMedicalReport(report);
      setState(() => _analyzing = false);
      _snack(t("Report saved ✓", "अहवाल जतन झाला ✓", "रिपोर्ट सहेजी गई ✓"));
    } catch (e) {
      if (!mounted) return;
      setState(() => _analyzing = false);
      _snack(t("Analysis failed. Try a clearer file.",
          "विश्लेषण अयशस्वी. स्पष्ट फाईल वापरा.",
          "विश्लेषण विफल. साफ़ फ़ाइल आज़माएं."));
    }
  }

  Future<void> _deleteReport() async {
    final provider = Provider.of<UserProvider>(context, listen: false);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(t("Delete Report?", "अहवाल हटवायचा?", "रिपोर्ट हटाएं?"),
            style: AppTextStyles.heading3()),
        content: Text(
          t(
            "This will remove the analyzed medical report from your profile.",
            "हे तुमच्या प्रोफाइलमधून विश्लेषित वैद्यकीय अहवाल काढून टाकेल.",
            "यह आपकी प्रोफ़ाइल से विश्लेषित मेडिकल रिपोर्ट हटा देगा.",
          ),
          style: AppTextStyles.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t("Cancel", "रद्द करा", "रद्द करें")),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t("Delete", "हटवा", "हटाएं")),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await ApiService.deleteMedicalReport(provider.profile.userId);
      provider.setMedicalReport(null);
      _snack(t("Report deleted", "अहवाल हटवला", "रिपोर्ट हटाई गई"));
    } catch (_) {
      _snack(t("Could not delete report", "अहवाल हटवता आला नाही",
          "रिपोर्ट नहीं हटा सके"));
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProgressDashboardScreen()),
    );
  }

  Future<void> _logout() async {
    final provider = Provider.of<UserProvider>(context, listen: false);
    final userId = provider.profile.userId;
    final existing = await ReminderStorage.loadReminder(userId);
    if (existing != null) {
      final days = List<int>.from(existing['days'] as List);
      final idOffset = userId.hashCode.abs() % 1000;
      final ids = List.generate(days.length, (i) => idOffset + i);
      await ReminderService.cancelForIds(ids);
    }
    await ApiService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final profile = provider.profile;
    final report = provider.medicalReport;
    final hasReport = provider.hasReport;

    final initials = profile.name.isNotEmpty
        ? profile.name.trim().split(' ').take(2).map((e) => e[0].toUpperCase()).join()
        : '?';

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
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          t("Profile & Settings", "प्रोफाइल व सेटिंग्ज",
                              "प्रोफ़ाइल व सेटिंग्स"),
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        NormalLanguageSwitcher(
                          onLanguageChanged: () => setState(() {}),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.22),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 2.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      profile.name.isEmpty ? '—' : profile.name,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      profile.email.isEmpty ? '—' : profile.email,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              children: [
                // ── PRACTICE HISTORY ────────────────────────────────────
                GestureDetector(
                  onTap: _openHistory,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppGradients.cardGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppShadows.button,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.insights_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t("Practice History", "सराव इतिहास",
                                    "अभ्यास इतिहास"),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t("Your past sessions & progress",
                                    "मागील सत्रे व प्रगती",
                                    "पिछले सत्र व प्रगति"),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── VOICE / ACCESSIBILITY ───────────────────────────────
                _sectionLabel(
                  Icons.accessibility_new_rounded,
                  t("Accessibility", "प्रवेशयोग्यता", "सुगम्यता"),
                ),
                const SizedBox(height: 8),
                AppCard(
                  margin: EdgeInsets.zero,
                  child: AnimatedBuilder(
                    animation: VoiceService.instance,
                    builder: (context, _) {
                      final on = VoiceService.instance.accessibilityMode;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.chipBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.record_voice_over_rounded,
                                    color: AppColors.accent, size: 18),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t("Voice Mode", "व्हॉईस मोड", "वॉइस मोड"),
                                      style: AppTextStyles.bodyMedium(),
                                    ),
                                    Text(
                                      t(
                                        "Control the app by speaking",
                                        "बोलून अ‍ॅप वापरा",
                                        "बोलकर ऐप चलाएं",
                                      ),
                                      style: AppTextStyles.caption(),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: on,
                                activeColor: AppColors.accent,
                                onChanged: (v) =>
                                    VoiceService.instance.setAccessibilityMode(v),
                              ),
                            ],
                          ),
                          if (on) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.07),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.tips_and_updates_outlined,
                                      color: AppColors.accent, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t(
                                        'Try saying: "home", "explore", "diet", "assistant", "start", "read", or "help".',
                                        'म्हणा: "होम", "एक्सप्लोर", "डाएट", "असिस्टंट", "स्टार्ट", "रीड" किंवा "हेल्प".',
                                        'कहें: "होम", "एक्सप्लोर", "डाइट", "असिस्टेंट", "स्टार्ट", "रीड" या "हेल्प".',
                                      ),
                                      style: AppTextStyles.caption(
                                          color: AppColors.accent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // ── MEDICAL REPORT SECTION ──────────────────────────────
                _sectionLabel(
                  Icons.description_outlined,
                  t("Medical Report (AI)", "वैद्यकीय अहवाल (AI)",
                      "मेडिकल रिपोर्ट (AI)"),
                ),
                const SizedBox(height: 8),
                AppCard(
                  margin: EdgeInsets.zero,
                  child: hasReport
                      ? _reportView(report!)
                      : _reportEmpty(),
                ),

                const SizedBox(height: 20),

                // ── HEALTH INFO ─────────────────────────────────────────
                _sectionLabel(
                  Icons.favorite_outline_rounded,
                  t("Health Info", "आरोग्य माहिती", "स्वास्थ्य जानकारी"),
                ),
                const SizedBox(height: 8),
                AppCard(
                  margin: EdgeInsets.zero,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HealthInfoScreen(editMode: true),
                    ),
                  ),
                  child: Row(
                    children: [
                      _miniStat(
                        t("Height", "उंची", "ऊंचाई"),
                        provider.healthInfo.height > 0
                            ? '${provider.healthInfo.height.toStringAsFixed(0)}"'
                            : '—',
                      ),
                      _divider(),
                      _miniStat(
                        t("Weight", "वजन", "वजन"),
                        provider.healthInfo.weight > 0
                            ? '${provider.healthInfo.weight.toStringAsFixed(0)}kg'
                            : '—',
                      ),
                      _divider(),
                      _miniStat(
                        t("Conditions", "स्थिती", "स्थितियाँ"),
                        '${provider.healthInfo.medicalConditions.length}',
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── ACCOUNT ─────────────────────────────────────────────
                _sectionLabel(
                  Icons.settings_outlined,
                  t("Account", "खाते", "खाता"),
                ),
                const SizedBox(height: 8),
                AppCard(
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _row(
                        Icons.cake_outlined,
                        t("Age Group", "वयोगट", "आयु वर्ग"),
                        provider.ageGroup.isEmpty ? '—' : provider.ageGroup,
                      ),
                      const Divider(height: 1),
                      _row(
                        Icons.wc_rounded,
                        t("Gender", "लिंग", "लिंग"),
                        provider.gender.isEmpty ? '—' : provider.gender,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── PINNED LOGOUT (always visible above the nav bar) ────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(
                    t("Logout", "लॉगआउट", "लॉगआउट"),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  onPressed: _logout,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Report sub-widgets ─────────────────────────────────────────────────
  Widget _reportEmpty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(
            "Upload a PDF or photo of your medical report. AI will detect your conditions automatically.",
            "PDF किंवा अहवालाचा फोटो अपलोड करा. AI तुमच्या स्थिती ओळखेल.",
            "PDF या रिपोर्ट की फोटो अपलोड करें. AI आपकी स्थितियाँ पहचानेगा.",
          ),
          style: AppTextStyles.caption(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _analyzing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(
              _analyzing
                  ? t("Analyzing…", "तपासत आहे…", "जाँच हो रही है…")
                  : t("Upload Report", "अहवाल अपलोड करा", "रिपोर्ट अपलोड करें"),
            ),
            onPressed: _analyzing ? null : _uploadReport,
          ),
        ),
      ],
    );
  }

  Widget _reportView(Map<String, dynamic> report) {
    final known =
        (report['knownConditions'] as List? ?? []).map((e) => e.toString()).toList();
    final others =
        (report['otherConditions'] as List? ?? []).map((e) => e.toString()).toList();
    final summary = (report['summary'] ?? '').toString();
    final cautions = (report['cautions'] ?? '').toString();
    final fileName = (report['fileName'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t("Report analyzed", "अहवाल विश्लेषित", "रिपोर्ट विश्लेषित"),
                    style: AppTextStyles.bodyMedium(),
                  ),
                  if (fileName.isNotEmpty)
                    Text(fileName,
                        style: AppTextStyles.caption(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        if (known.isNotEmpty || others.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in [...known, ...others])
                AppChip(label: c, selected: true),
            ],
          ),
        ],
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(summary, style: AppTextStyles.caption()),
        ],
        if (cautions.isNotEmpty) ...[
          const SizedBox(height: 10),
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
                    color: AppColors.warning, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(cautions, style: AppTextStyles.caption())),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: _analyzing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(t("Replace", "बदला", "बदलें"),
                    style: const TextStyle(fontSize: 13)),
                onPressed: _analyzing ? null : _uploadReport,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: Text(t("Delete", "हटवा", "हटाएं"),
                    style: const TextStyle(fontSize: 13)),
                onPressed: _analyzing ? null : _deleteReport,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Small helpers ──────────────────────────────────────────────────────
  Widget _sectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(text, style: AppTextStyles.heading3()),
      ],
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: AppColors.divider,
        margin: const EdgeInsets.symmetric(horizontal: 6),
      );

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          const SizedBox(width: 14),
          Text(label, style: AppTextStyles.bodyMedium()),
          const Spacer(),
          Text(value, style: AppTextStyles.body(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
