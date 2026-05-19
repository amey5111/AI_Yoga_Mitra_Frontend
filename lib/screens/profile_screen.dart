import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../models/user_profile.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import 'health_info_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  String name = '';
  String email = '';
  String password = '';
  bool _obscurePassword = true;

  String? ageGroup;
  String? gender;

  final ageOptions = ["Below 10", "11-18", "19-50", "Above 50"];
  final genderOptions = ["Male", "Female", "Other"];

  String getAgeDisplay(String age) {
    switch (age) {
      case "Below 10": return LanguageHelper.t("Below 10", "१० वर्षांखाली", "10 वर्ष से कम");
      case "11-18":    return LanguageHelper.t("11-18", "११-१८", "11-18");
      case "19-50":    return LanguageHelper.t("19-50", "१९-५०", "19-50");
      case "Above 50": return LanguageHelper.t("Above 50", "५० वर्षांपेक्षा जास्त", "50 वर्ष से अधिक");
      default:         return age;
    }
  }

  String getGenderDisplay(String g) {
    switch (g) {
      case "Male":   return LanguageHelper.t("Male", "पुरुष", "पुरुष");
      case "Female": return LanguageHelper.t("Female", "स्त्री", "महिला");
      case "Other":  return LanguageHelper.t("Other", "इतर", "अन्य");
      default:       return g;
    }
  }

  IconData _genderIcon(String g) {
    switch (g) {
      case "Male":   return Icons.male_rounded;
      case "Female": return Icons.female_rounded;
      default:       return Icons.person_outline_rounded;
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      final response = await ApiService.register(
        name, email, password, ageGroup ?? "", gender ?? "",
      );

      final provider = Provider.of<UserProvider>(context, listen: false);
      provider.setProfile(UserProfile(
        userId: response["userId"],
        name: response["name"],
        email: response["email"],
        password: password,
      ));
      provider.setAgeGender(ageGroup ?? "", gender ?? "");

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HealthInfoScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _stepIndicator(int step, String label, bool active) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.accent : AppColors.chipBg,
            boxShadow: active ? AppShadows.button : [],
          ),
          child: Center(
            child: Text(
              '$step',
              style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    LanguageHelper.loadLanguage();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.softBg),
        child: SafeArea(
          child: Column(
            children: [
              // ── Hero header ──────────────────────────────────────────
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
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LanguageHelper.t("Create Account", "खाते तयार करा", "खाता बनाएं"),
                      style: GoogleFonts.poppins(
                        fontSize: 24, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LanguageHelper.t(
                        "Tell us about yourself to get started",
                        "सुरू करण्यासाठी स्वतःबद्दल सांगा",
                        "शुरू करने के लिए अपने बारे में बताएं",
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Step indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _stepIndicator(1, LanguageHelper.t("Profile", "प्रोफाइल", "प्रोफ़ाइल"), true),
                        Container(width: 40, height: 2, color: Colors.white.withOpacity(0.3),
                            margin: const EdgeInsets.only(bottom: 18, left: 6, right: 6)),
                        _stepIndicator(2, LanguageHelper.t("Health", "आरोग्य", "स्वास्थ्य"), false),
                        Container(width: 40, height: 2, color: Colors.white.withOpacity(0.3),
                            margin: const EdgeInsets.only(bottom: 18, left: 6, right: 6)),
                        _stepIndicator(3, LanguageHelper.t("Goals", "लक्ष्ये", "लक्ष्य"), false),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Form ────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        TextFormField(
                          decoration: appInputDecoration(
                            label: LanguageHelper.t("Full Name", "पूर्ण नाव", "पूरा नाम"),
                            hint: LanguageHelper.t("Your name", "आपले नाव", "आपका नाम"),
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                          validator: (v) => v!.isEmpty
                              ? LanguageHelper.t("Required", "आवश्यक", "आवश्यक") : null,
                          onSaved: (v) => name = v!,
                        ),
                        const SizedBox(height: 14),

                        // Email
                        TextFormField(
                          keyboardType: TextInputType.emailAddress,
                          decoration: appInputDecoration(
                            label: LanguageHelper.t("Email", "ईमेल", "ईमेल"),
                            hint: "you@example.com",
                            prefixIcon: Icons.email_outlined,
                          ),
                          validator: (v) => v!.isEmpty
                              ? LanguageHelper.t("Required", "आवश्यक", "आवश्यक") : null,
                          onSaved: (v) => email = v!,
                        ),
                        const SizedBox(height: 14),

                        // Password
                        TextFormField(
                          obscureText: _obscurePassword,
                          decoration: appInputDecoration(
                            label: LanguageHelper.t("Password", "पासवर्ड", "पासवर्ड"),
                            hint: "••••••••",
                            prefixIcon: Icons.lock_outline_rounded,
                            suffix: GestureDetector(
                              onTap: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              child: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textSecondary, size: 20,
                              ),
                            ),
                          ),
                          validator: (v) => v!.isEmpty
                              ? LanguageHelper.t("Required", "आवश्यक", "आवश्यक") : null,
                          onSaved: (v) => password = v!,
                        ),
                        const SizedBox(height: 20),

                        // Age Group
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.bgLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.divider, width: 1.2),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: ageGroup,
                            decoration: InputDecoration(
                              labelText: LanguageHelper.t("Age Group", "वयोगट", "आयु वर्ग"),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 4),
                              prefixIcon: Icon(Icons.cake_outlined,
                                  color: AppColors.accent.withOpacity(0.7), size: 20),
                            ),
                            isExpanded: true,
                            icon: const Icon(Icons.expand_more_rounded,
                                color: AppColors.textSecondary),
                            items: ageOptions.map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(getAgeDisplay(e)),
                            )).toList(),
                            onChanged: (v) => setState(() => ageGroup = v),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Gender
                        Text(
                          LanguageHelper.t("Gender", "लिंग", "लिंग"),
                          style: AppTextStyles.bodyMedium(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: genderOptions.map((g) {
                            final sel = gender == g;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => gender = g),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: sel ? AppColors.accent : AppColors.bgLight,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: sel ? AppColors.accent : AppColors.divider,
                                      width: 1.5,
                                    ),
                                    boxShadow: sel ? AppShadows.button : [],
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        _genderIcon(g),
                                        color: sel ? Colors.white : AppColors.accent,
                                        size: 22,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        getGenderDisplay(g),
                                        style: GoogleFonts.inter(
                                          fontSize: 12, fontWeight: FontWeight.w600,
                                          color: sel ? Colors.white : AppColors.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 32),

                        AppPrimaryButton(
                          label: LanguageHelper.t("Next: Health Info", "पुढे: आरोग्य माहिती", "आगे: स्वास्थ्य जानकारी"),
                          onPressed: submit,
                          icon: Icons.arrow_forward_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
