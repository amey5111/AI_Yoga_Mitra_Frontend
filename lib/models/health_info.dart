class HealthInfo {
  double height;
  double weight;
  List<String> medicalConditions;
  String activityLevel;

  HealthInfo({
    this.height = 0,
    this.weight = 0,
    this.medicalConditions = const [],
    this.activityLevel = "Beginner",
  });

  Map<String, dynamic> toJson() => {
    "height": height,
    "weight": weight,
    "medical_conditions": medicalConditions,
    "activity_level": activityLevel,
  };
}
