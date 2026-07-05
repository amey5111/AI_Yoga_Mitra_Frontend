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

  // ── Persisted medical report (AI-analyzed) ─────────────────────────────────
  Map<String, dynamic>? medicalReport;

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

  // ── Medical report ─────────────────────────────────────────────────────────
  void setMedicalReport(Map<String, dynamic>? report) {
    medicalReport = report;
    notifyListeners();
  }

  bool get hasReport =>
      medicalReport != null &&
      ((medicalReport!['knownConditions'] as List?)?.isNotEmpty == true ||
          (medicalReport!['otherConditions'] as List?)?.isNotEmpty == true ||
          (medicalReport!['summary'] ?? '').toString().isNotEmpty);

  /// Load a persisted health profile (from backend) into the in-memory models.
  void hydrateFromHealthProfile(Map<String, dynamic>? hp) {
    if (hp == null) return;
    healthInfo = HealthInfo(
      height: (hp['height'] ?? 0).toDouble(),
      weight: (hp['weight'] ?? 0).toDouble(),
      medicalConditions:
          (hp['medicalConditions'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      activityLevel: (hp['activityLevel'] ?? 'Beginner').toString(),
    );
    goals = Goals(
      focusBodyParts:
          (hp['focusBodyParts'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      tags:
          (hp['goalTags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      routineDuration: (hp['routineDuration'] ?? 30) as int,
    );
    notifyListeners();
  }
}
