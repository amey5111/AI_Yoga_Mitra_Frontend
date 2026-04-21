import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import '../models/user_profile.dart';
import '../utils/language_helper.dart';
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

  String? ageGroup;
  String? gender;

  /// 🔹 INTERNAL ENGLISH VALUES (Backend Safe)
  final ageOptions = ["Below 10", "11-18", "19-50", "Above 50"];

  final genderOptions = ["Male", "Female", "Other"];

  /// 🔹 AGE DISPLAY
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

  /// 🔹 GENDER DISPLAY
  String getGenderDisplay(String g) {
    switch (g) {
      case "Male":
        return LanguageHelper.t("Male", "पुरुष", "पुरुष");
      case "Female":
        return LanguageHelper.t("Female", "स्त्री", "महिला");
      case "Other":
        return LanguageHelper.t("Other", "इतर", "अन्य");
      default:
        return g;
    }
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    try {
      final response = await ApiService.register(
        name,
        email,
        password,
        ageGroup ?? "",
        gender ?? "",
      );

      final provider = Provider.of<UserProvider>(context, listen: false);

      provider.setProfile(
        UserProfile(
          userId: response["userId"],
          name: response["name"],
          email: response["email"],
          password: password,
        ),
      );

      provider.setAgeGender(ageGroup ?? "", gender ?? "");

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HealthInfoScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    LanguageHelper.loadLanguage();

    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageHelper.t("Profile", "प्रोफाइल", "प्रोफ़ाइल")),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                /// 🔹 NAME
                TextFormField(
                  decoration: InputDecoration(
                    labelText: LanguageHelper.t("Name", "नाव", "नाम"),
                  ),
                  validator: (v) => v!.isEmpty
                      ? LanguageHelper.t("Required", "आवश्यक", "आवश्यक")
                      : null,
                  onSaved: (v) => name = v!,
                ),

                /// 🔹 EMAIL
                TextFormField(
                  decoration: InputDecoration(
                    labelText: LanguageHelper.t("Email", "ईमेल", "ईमेल"),
                  ),
                  validator: (v) => v!.isEmpty
                      ? LanguageHelper.t("Required", "आवश्यक", "आवश्यक")
                      : null,
                  onSaved: (v) => email = v!,
                ),

                /// 🔹 PASSWORD
                TextFormField(
                  decoration: InputDecoration(
                    labelText: LanguageHelper.t(
                      "Password",
                      "पासवर्ड",
                      "पासवर्ड",
                    ),
                  ),
                  obscureText: true,
                  validator: (v) => v!.isEmpty
                      ? LanguageHelper.t("Required", "आवश्यक", "आवश्यक")
                      : null,
                  onSaved: (v) => password = v!,
                ),

                const SizedBox(height: 20),

                /// 🔹 AGE GROUP (Translated Display, English Stored)
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: LanguageHelper.t(
                      "Age Group",
                      "वयोगट",
                      "आयु वर्ग",
                    ),
                  ),
                  items: ageOptions
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(getAgeDisplay(e)), // Translated UI
                        ),
                      )
                      .toList(),
                  onChanged: (v) => ageGroup = v, // English stored
                ),

                const SizedBox(height: 10),

                /// 🔹 GENDER (Translated Display, English Stored)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(LanguageHelper.t("Gender", "लिंग", "लिंग")),
                    Row(
                      children: genderOptions
                          .map(
                            (g) => Row(
                              children: [
                                Radio<String>(
                                  value: g,
                                  groupValue: gender,
                                  onChanged: (v) => setState(() => gender = v),
                                ),
                                Text(getGenderDisplay(g)), // Translated UI
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                ElevatedButton(
                  onPressed: submit,
                  child: Text(LanguageHelper.t("Next", "पुढे", "आगे")),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
