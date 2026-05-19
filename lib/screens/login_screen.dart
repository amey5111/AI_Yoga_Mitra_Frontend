import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../models/user_profile.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import 'routine_screen.dart';
import 'profile_screen.dart';
import '../Widgets/language_switcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool _obscurePassword = true;

  Future<void> login() async {
    try {
      setState(() => loading = true);

      final response = await ApiService.login(
        emailController.text,
        passwordController.text,
      );

      final provider = Provider.of<UserProvider>(context, listen: false);

      provider.setProfile(
        UserProfile(
          userId: response["userId"],
          name: response["name"],
          email: response["email"],
        ),
      );

      provider.setAgeGender(
        response["ageGroup"] ?? "",
        response["gender"] ?? "",
      );

      final routine = await ApiService.fetchUserRoutine(response["userId"]);

      await ApiService.saveSession(
        response["userId"],
        response["name"],
        response["email"],
        response["ageGroup"] ?? "",
        response["gender"] ?? "",
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RoutineScreen(routine: routine ?? {"routine": []}),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LanguageHelper.t("Login failed", "लॉगिन अयशस्वी", "लॉगिन विफल"),
          ),
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    LanguageHelper.loadLanguage();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.softBg),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Hero header ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                  decoration: const BoxDecoration(
                    gradient: AppGradients.welcomeBg,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(36),
                      bottomRight: Radius.circular(36),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Back button row
                      // Back button row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                          LanguageSwitcher(
                            popupOffset: const Offset(25, 20),
                            onLanguageChanged: () {
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        LanguageHelper.t(
                          "Welcome Back",
                          "आपले परत स्वागत आहे ",
                          "वापसी पर स्वागत है",
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        LanguageHelper.t(
                          "Sign in to continue your yoga journey",
                          "आपल्या योगा प्रवासासाठी साइन इन करा",
                          "अपनी योगा यात्रा जारी रखने के लिए साइन इन करें",
                        ),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Form card ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// EMAIL
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: appInputDecoration(
                          label: LanguageHelper.t("Email", "ईमेल", "ईमेल"),
                          hint: "you@example.com",
                          prefixIcon: Icons.email_outlined,
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// PASSWORD
                      TextFormField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        decoration: appInputDecoration(
                          label: LanguageHelper.t(
                            "Password",
                            "पासवर्ड",
                            "पासवर्ड",
                          ),
                          hint: "••••••••",
                          prefixIcon: Icons.lock_outline_rounded,
                          suffix: GestureDetector(
                            onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            child: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      /// LOGIN BUTTON
                      AppPrimaryButton(
                        label: LanguageHelper.t("Login", "लॉगिन", "लॉगिन"),
                        onPressed: login,
                        loading: loading,
                        icon: Icons.login_rounded,
                      ),

                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              LanguageHelper.t("OR", "किंवा", "या"),
                              style: AppTextStyles.caption(),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// CREATE ACCOUNT
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          ),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: AppTextStyles.body(
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: LanguageHelper.t(
                                    "New to Yoga Mitra? ",
                                    "नवीन वापरकर्ता? ",
                                    "नया उपयोगकर्ता? ",
                                  ),
                                ),
                                TextSpan(
                                  text: LanguageHelper.t(
                                    "Create Account",
                                    "खाते तयार करा",
                                    "खाता बनाएं",
                                  ),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
