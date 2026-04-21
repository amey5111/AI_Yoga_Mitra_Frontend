import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../utils/language_helper.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  String t(String en, String mr, String hn) {
    return LanguageHelper.t(en, mr, hn);
  }

  String getAgeDisplay(String age) {
    switch (age) {
      case "Below 10":
        return t("Below 10", "१० वर्षांखाली", "10 वर्ष से कम");
      case "11-18":
        return t("11-18", "११-१८", "11-18");
      case "19-50":
        return t("19-50", "१९-५०", "19-50");
      case "Above 50":
        return t("Above 50", "५० वर्षांपेक्षा जास्त", "50 वर्ष से अधिक");
      default:
        return age;
    }
  }

  String getGenderDisplay(String gender) {
    switch (gender) {
      case "Male":
        return t("Male", "पुरुष", "पुरुष");
      case "Female":
        return t("Female", "स्त्री", "महिला");
      case "Other":
        return t("Other", "इतर", "अन्य");
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

    return Scaffold(
      appBar: AppBar(
        title: Text(t("My Profile", "माझे प्रोफाइल", "मेरा प्रोफाइल")),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            profileField(t("Name", "नाव", "नाम"), profile.name),
            profileField(t("Email", "ईमेल", "ईमेल"), profile.email),
            profileField(
              t("Age Group", "वयोगट", "आयु वर्ग"),
              getAgeDisplay(age),
            ),
            profileField(t("Gender", "लिंग", "लिंग"), getGenderDisplay(gender)),
          ],
        ),
      ),
    );
  }

  Widget profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: Text(value.isEmpty ? "-" : value),
          ),
        ],
      ),
    );
  }
}
