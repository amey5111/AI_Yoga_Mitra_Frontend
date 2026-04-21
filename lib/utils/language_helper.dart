import 'package:shared_preferences/shared_preferences.dart';

class LanguageHelper {
  static String currentLanguage = "English";

  static Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    currentLanguage = prefs.getString("language") ?? "English";
  }

  static String t(String en, String mr, String hi) {
    switch (currentLanguage) {
      case "मराठी":
        return mr;
      case "हिंदी":
        return hi;
      default:
        return en;
    }
  }
}
