import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../models/user_profile.dart';
import '../utils/language_helper.dart';
import 'routine_screen.dart';
import 'profile_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

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
      appBar: AppBar(title: Text(LanguageHelper.t("Login", "लॉगिन", "लॉगिन"))),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            /// EMAIL
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: LanguageHelper.t("Email", "ईमेल", "ईमेल"),
              ),
            ),

            /// PASSWORD
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: LanguageHelper.t("Password", "पासवर्ड", "पासवर्ड"),
              ),
            ),

            const SizedBox(height: 30),

            /// LOGIN BUTTON
            ElevatedButton(
              onPressed: loading ? null : login,
              child: loading
                  ? const CircularProgressIndicator()
                  : Text(LanguageHelper.t("Login", "लॉगिन", "लॉगिन")),
            ),

            const SizedBox(height: 20),

            /// CREATE ACCOUNT
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: Text(
                LanguageHelper.t(
                  "Haven't created your account? Create one",
                  "नवीन वापरकर्ता / खाते तयार केले नाही? नवीन खाते तयार करा",
                  "नया वापरकर्ता खाता नहीं बनाया? नया खाता बनाएं",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
