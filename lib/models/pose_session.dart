class PoseSession {
  final String userId;

  final int poseId;

  final String poseName;

  final int score;

  final double avgSimilarity;

  final int durationAchieved;

  final bool completed;

  final List<String> mistakes;

  final String level;

  final DateTime sessionDate;

  PoseSession({
    required this.userId,
    required this.poseId,
    required this.poseName,
    required this.score,
    required this.avgSimilarity,
    required this.durationAchieved,
    required this.completed,
    required this.mistakes,
    required this.level,
    required this.sessionDate,
  });

  factory PoseSession.fromJson(Map<String, dynamic> json) {
    return PoseSession(
      userId: json["userId"],
      poseId: json["poseId"],
      poseName: json["poseName"] ?? "",
      score: json["score"] ?? 0,
      avgSimilarity: (json["avgSimilarity"] ?? 0).toDouble(),
      durationAchieved: json["durationAchieved"] ?? 0,
      completed: json["completed"] ?? false,
      mistakes: List<String>.from(json["mistakes"] ?? []),
      level: json["level"] ?? "beginner",
      sessionDate: DateTime.parse(json["sessionDate"]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "userId": userId,
      "poseId": poseId,
      "poseName": poseName,
      "score": score,
      "avgSimilarity": avgSimilarity,
      "durationAchieved": durationAchieved,
      "completed": completed,
      "mistakes": mistakes,
      "level": level,
      "sessionDate": sessionDate.toIso8601String(),
    };
  }
}
