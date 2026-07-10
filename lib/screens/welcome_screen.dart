import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/language_helper.dart';
import '../theme/app_theme.dart';
import '../services/voice_service.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool highlightButton = false;
  double buttonRadius = 0.0;

  String selectedLanguage = "English";

  String welcomeText = "Welcome to";
  String appName = "YOGA MITRA";
  String tagline = "Your AI powered yoga companion...";
  String loginText = "Login";
  String startText = "Let's Start";
  String selectLanguageText = "Please Select Language";

  late AnimationController _animController;
  Animation<double>? _fadeAnim;
  Animation<Offset>? _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    loadLanguage();
    _setupVoice();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          highlightButton = true;
          buttonRadius = 1.5;
        });
      }
    });
  }

  void _setupVoice() {
    final voice = VoiceService.instance;
    voice.setActions({
      'login': () {
        if (mounted) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      },
      'start': () {
        if (mounted) {
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => ProfileScreen()));
        }
      },
    });
    voice.setReader(() => LanguageHelper.t(
          "This is the Yoga Mitra welcome screen. Say login to sign in, or start to create a new account.",
          "हे योगा मित्र स्वागत स्क्रीन आहे. लॉगिन किंवा स्टार्ट म्हणा.",
          "यह योगा मित्र वेलकम स्क्रीन है. लॉगिन या स्टार्ट कहें.",
        ));

    // Greet ONCE on app launch (only when the voice assistant is on).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!voice.accessibilityMode) return;
      if (voice.welcomed) {
        // Already welcomed this launch — just resume listening quietly.
        voice.startListening();
        return;
      }
      await voice.speak(
        LanguageHelper.t(
          "Welcome to Yoga Mitra, your A I yoga companion. Say login to sign in, or say start to create a new account. Say help anytime.",
          "योगा मित्रमध्ये स्वागत आहे. साइन इन साठी लॉगिन म्हणा, किंवा नवीन खात्यासाठी स्टार्ट म्हणा. मदतीसाठी हेल्प म्हणा.",
          "योगा मित्र में स्वागत है. साइन इन के लिए लॉगिन कहें, या नए खाते के लिए स्टार्ट कहें. मदद के लिए हेल्प कहें.",
        ),
      );
    });
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  void loadLanguage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lang = prefs.getString('language');
    if (lang != null) {
      changeLanguage(lang, save: false);
    }
  }

  void saveLanguage(String lang) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('language', lang);
  }

  void changeLanguage(String lang, {bool save = true}) {
    LanguageHelper.currentLanguage = lang;
    setState(() {
      selectedLanguage = lang;
      if (lang == "English") {
        welcomeText = "Welcome to";
        appName = "YOGA MITRA";
        tagline = "Your AI powered yoga companion...";
        loginText = "Login";
        startText = "Let's Start";
        selectLanguageText = "Please Select Language";
      } else if (lang == "मराठी") {
        welcomeText = "स्वागत आहे";
        appName = "योगा मित्र";
        tagline = "तुमचा AI आधारित योगा साथीदार...";
        loginText = "लॉगिन";
        startText = "सुरू करा";
        selectLanguageText = "कृपया भाषा निवडा";
      } else if (lang == "हिंदी") {
        welcomeText = "स्वागत है";
        appName = "योगा मित्र";
        tagline = "आपका AI आधारित योगा साथी...";
        loginText = "लॉगिन";
        startText = "शुरू करें";
        selectLanguageText = "कृपया भाषा चुनें";
      }
    });
    if (save) saveLanguage(lang);
  }

  Widget _langOption(String value) {
    final isSelected = selectedLanguage == value;
    return GestureDetector(
      onTap: () => changeLanguage(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.accent : Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.welcomeBg),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Decorative blobs ───────────────────────────────────────
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
              ),
              Positioned(
                top: 80,
                left: -80,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),

              // ── Bottom illustration ────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: 0.35,
                  child: Image.asset(
                    'assets/welcome sceeen_bottom_asset.png',
                    width: size.width,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // ── Main content ───────────────────────────────────────────
              Column(
                children: [
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnim ?? const AlwaysStoppedAnimation(1.0),
                      child: SlideTransition(
                        position:
                            _slideAnim ??
                            const AlwaysStoppedAnimation(Offset.zero),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),

                              // Label pill
                              // Container(
                              //   padding: const EdgeInsets.symmetric(
                              //     horizontal: 18,
                              //     vertical: 7,
                              //   ),
                              //   decoration: BoxDecoration(
                              //     color: Colors.white.withOpacity(0.18),
                              //     borderRadius: BorderRadius.circular(99),
                              //     border: Border.all(
                              //       color: Colors.white.withOpacity(0.3),
                              //     ),
                              //   ),
                              //   child: Row(
                              //     mainAxisSize: MainAxisSize.min,
                              //     children: [
                              //       Container(
                              //         width: 7,
                              //         height: 7,
                              //         decoration: const BoxDecoration(
                              //           shape: BoxShape.circle,
                              //           color: Color(0xFF9EFF90),
                              //         ),
                              //       ),
                              //       const SizedBox(width: 8),
                              //       Text(
                              //         'AI Powered Wellness',
                              //         style: GoogleFonts.inter(
                              //           fontSize: 12,
                              //           color: Colors.white,
                              //           fontWeight: FontWeight.w500,
                              //         ),
                              //       ),
                              //     ],
                              //   ),
                              // ),
                              // const SizedBox(height: 28),

                              // Logo
                              Container(
                                width: 100,
                                height: 100,
                                padding: const EdgeInsets.all(14),
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

                              const SizedBox(height: 20),

                              // Welcome text
                              Text(
                                welcomeText,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                appName,
                                style: GoogleFonts.poppins(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Text(
                                  tagline,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withOpacity(0.8),
                                    height: 1.5,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Language selector glass card
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.28),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        selectLanguageText,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.85),
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _langOption("English"),
                                          const SizedBox(width: 10),
                                          _langOption("मराठी"),
                                          const SizedBox(width: 10),
                                          _langOption("हिंदी"),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Bottom CTA buttons ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                    child: Row(
                      children: [
                        // Login button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            ),
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.45),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  loginText,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Let's Start primary button
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(),
                              ),
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 800),
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: highlightButton
                                    ? const LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Color(0xFFEDE9FF),
                                        ],
                                      )
                                    : const LinearGradient(
                                        colors: [Colors.white, Colors.white],
                                      ),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      startText,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: AppColors.accent,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
