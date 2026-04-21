import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/health_info.dart';
import '../models/goals.dart';

class UserProvider extends ChangeNotifier {
  UserProfile profile = UserProfile();
  HealthInfo healthInfo = HealthInfo();
  Goals goals = Goals();

  // Optional local-only fields
  String ageGroup = "";
  String gender = "";

  // ── Recommendations cache (used by EditRoutineScreen) ──────────────────────
  List<Map<String, dynamic>> poseDetails = [];
  List<Map<String, dynamic>> breathingDetails = [];

  void setProfile(UserProfile p) {
    profile = p;
    notifyListeners();
  }

  void setHealthInfo(HealthInfo h) {
    healthInfo = h;
    notifyListeners();
  }

  void setGoals(Goals g) {
    goals = g;
    notifyListeners();
  }

  void setAgeGender(String age, String gen) {
    ageGroup = age;
    gender = gen;
    notifyListeners();
  }

  // ── Called from RecommendationsScreen after fetching ──────────────────────
  void setRecommendations({
    required List<Map<String, dynamic>> poses,
    required List<Map<String, dynamic>> breathing,
  }) {
    poseDetails = poses;
    breathingDetails = breathing;
    notifyListeners();
  }
}
