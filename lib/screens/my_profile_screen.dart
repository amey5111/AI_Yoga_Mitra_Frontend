import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import '../Widgets/language_switcher.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  String t(String en, String mr, String hn) => LanguageHelper.t(en, mr, hn);

  String getAgeDisplay(String age) {
    switch (age) {
      case "Below 10":
        return LanguageHelper.t("Below 10", "१० वर्षांखाली", "10 वर्ष से कम");
      case "11-18":
        return LanguageHelper.t("11-18", "११-१८", "11-18");
      case "19-50":
        return LanguageHelper.t("19-50", "१९-५०", "19-50");
      case "Above 50":
        return LanguageHelper.t(
          "Above 50",
          "५० वर्षांपेक्षा जास्त",
          "50 वर्ष से अधिक",
        );
      default:
        return age;
    }
  }

  String getGenderDisplay(String gender) {
    switch (gender) {
      case "Male":
        return LanguageHelper.t("Male", "पुरुष", "पुरुष");
      case "Female":
        return LanguageHelper.t("Female", "स्त्री", "महिला");
      case "Other":
        return LanguageHelper.t("Other", "इतर", "अन्य");
      default:
        return gender;
    }
  }

  @override
  Widget build(BuildContext context) {
    LanguageHelper.loadLanguage();

    final provider = Provider.of<UserProvider>(context);

    final profile = provider.profile;

    final age = provider.ageGroup;

    final gender = provider.gender;

    // Initials for avatar
    final initials = profile.name.isNotEmpty
        ? profile.name
              .trim()
              .split(' ')
              .take(2)
              .map((e) => e[0].toUpperCase())
              .join()
        : '?';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.softBg),

        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Hero profile card ────────────────────────────────────
                Container(
                  width: double.infinity,

                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),

                  decoration: const BoxDecoration(
                    gradient: AppGradients.welcomeBg,

                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),

                      bottomRight: Radius.circular(40),
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

                              child: const Icon(
                                Icons.arrow_back_rounded,

                                color: Colors.white,

                                size: 20,
                              ),
                            ),
                          ),

                          const Spacer(),

                          Text(
                            t("My Profile", "माझे प्रोफाइल", "मेरा प्रोफाइल"),

                            style: GoogleFonts.poppins(
                              fontSize: 18,

                              fontWeight: FontWeight.w600,

                              color: Colors.white,
                            ),
                          ),

                          const Spacer(),

                          LanguageSwitcher(
                            popupOffset: const Offset(25, 20),

                            onLanguageChanged: () {
                              setState(() {});
                            },
                          ),

                          const SizedBox(width: 10),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Avatar circle
                      Container(
                        width: 90,

                        height: 90,

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          color: Colors.white.withOpacity(0.25),

                          border: Border.all(
                            color: Colors.white.withOpacity(0.6),

                            width: 3,
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),

                              blurRadius: 20,

                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),

                        child: Center(
                          child: Text(
                            initials,

                            style: GoogleFonts.poppins(
                              fontSize: 32,

                              fontWeight: FontWeight.w700,

                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        profile.name.isEmpty ? '—' : profile.name,

                        style: GoogleFonts.poppins(
                          fontSize: 22,

                          fontWeight: FontWeight.w700,

                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        profile.email.isEmpty ? '—' : profile.email,

                        style: GoogleFonts.inter(
                          fontSize: 14,

                          color: Colors.white.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Info cards ───────────────────────────────────────────
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        t(
                          "Personal Information",
                          "वैयक्तिक माहिती",
                          "व्यक्तिगत जानकारी",
                        ),

                        style: AppTextStyles.heading3(),
                      ),

                      const SizedBox(height: 14),

                      _infoCard(
                        icon: Icons.person_outline_rounded,

                        label: t("Full Name", "पूर्ण नाव", "पूरा नाम"),

                        value: profile.name.isEmpty ? '—' : profile.name,
                      ),

                      _infoCard(
                        icon: Icons.email_outlined,

                        label: t("Email", "ईमेल", "ईमेल"),

                        value: profile.email.isEmpty ? '—' : profile.email,
                      ),

                      _infoCard(
                        icon: Icons.cake_outlined,

                        label: t("Age Group", "वयोगट", "आयु वर्ग"),

                        value: age.isEmpty ? '—' : getAgeDisplay(age),
                      ),

                      _infoCard(
                        icon: Icons.wc_rounded,

                        label: t("Gender", "लिंग", "लिंग"),

                        value: gender.isEmpty ? '—' : getGenderDisplay(gender),

                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 2),

      decoration: BoxDecoration(
        color: AppColors.bgCard,

        borderRadius: BorderRadius.circular(16),

        boxShadow: AppShadows.soft,
      ),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),

              decoration: BoxDecoration(
                color: AppColors.chipBg,

                borderRadius: BorderRadius.circular(10),
              ),

              child: Icon(icon, color: AppColors.accent, size: 18),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(label, style: AppTextStyles.label()),

                  const SizedBox(height: 3),

                  Text(value, style: AppTextStyles.bodyMedium()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
