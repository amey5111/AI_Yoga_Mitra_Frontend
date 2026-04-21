import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/language_helper.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool highlightButton = false;
  double buttonRadius = 0.0;

  String selectedLanguage = "English";

  // Text Variables
  String welcomeText = "Welcome to";
  String appName = "YOGA MITRA";
  String tagline = "Your AI powered yoga companion...";
  String loginText = "Login";
  String startText = "Let’s Start >";
  String selectLanguageText = "Please Select Language";

  @override
  void initState() {
    super.initState();
    loadLanguage();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          highlightButton = true;
          buttonRadius = 1.5;
        });
      }
    });
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
    // 🔥 VERY IMPORTANT FIX
    LanguageHelper.currentLanguage = lang;

    setState(() {
      selectedLanguage = lang;

      if (lang == "English") {
        welcomeText = "Welcome to";
        appName = "YOGA MITRA";
        tagline = "Your AI powered yoga companion...";
        loginText = "Login";
        startText = "Let’s Start >";
        selectLanguageText = "Please Select Language";
      } else if (lang == "मराठी") {
        welcomeText = "स्वागत आहे";
        appName = "योगा मित्र";
        tagline = "तुमचा AI आधारित योगा साथीदार...";
        loginText = "लॉगिन";
        startText = "सुरू करा >";
        selectLanguageText = "कृपया भाषा निवडा";
      } else if (lang == "हिंदी") {
        welcomeText = "स्वागत है";
        appName = "योगा मित्र";
        tagline = "आपका AI आधारित योगा साथी...";
        loginText = "लॉगिन";
        startText = "शुरू करें >";
        selectLanguageText = "कृपया भाषा चुनें";
      }
    });

    if (save) saveLanguage(lang);
  }

  Widget buildLanguageOption(String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: selectedLanguage,
          activeColor: Colors.white,
          fillColor: MaterialStateProperty.all(Colors.white),
          onChanged: (val) {
            changeLanguage(val!);
          },
        ),
        Text(value, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA3A4F4),
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Image.asset(
                'assets/welcome sceeen_bottom_asset.png',
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.cover,
              ),
            ),

            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),

                    Text(
                      welcomeText,
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Image.asset(
                      'assets/logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),

                    Text(
                      appName,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      tagline,
                      style: const TextStyle(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    Text(
                      selectLanguageText,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildLanguageOption("English"),
                        const SizedBox(width: 20),
                        buildLanguageOption("मराठी"),
                        const SizedBox(width: 20),
                        buildLanguageOption("हिंदी"),
                      ],
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 10.0,
                  left: 24,
                  right: 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        loginText,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: highlightButton
                            ? RadialGradient(
                                colors: [
                                  const Color(0xFF3E72FF),
                                  const Color(0xFF3E72FF),
                                ],
                                radius: buttonRadius,
                                center: Alignment.center,
                              )
                            : const RadialGradient(
                                colors: [Colors.white, Colors.white],
                                radius: 0.0001,
                                center: Alignment.center,
                              ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ProfileScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: highlightButton
                              ? Colors.white
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          startText,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
