class PoseReference {
  final String poseName;

  final List<double> referenceVector;

  final double threshold;

  final int holdTime;

  /// 8 pre-computed joint angles derived from the reference vector.
  /// Matches the order of [AngleScorer._joints]:
  ///   0 leftElbow, 1 rightElbow, 2 leftKnee, 3 rightKnee,
  ///   4 leftShoulder, 5 rightShoulder, 6 leftHip, 7 rightHip
  /// Null elements mean the angle was not computable for this pose.
  final List<double?> referenceAngles;

  PoseReference({
    required this.poseName,
    required this.referenceVector,
    required this.threshold,
    required this.holdTime,
    required this.referenceAngles,
  });

  factory PoseReference.fromJson(Map<String, dynamic> json) {
    List<double?> angles = List.filled(8, null);
    if (json['referenceAngles'] != null) {
      final raw = json['referenceAngles'] as List<dynamic>;
      angles = raw
          .map((v) => v == null ? null : (v as num).toDouble())
          .toList();
    }

    return PoseReference(
      poseName: json['poseName'],
      referenceVector: List<double>.from(json['referenceVector']),
      threshold: (json['threshold'] as num).toDouble(),
      holdTime: json['holdTime'],
      referenceAngles: angles,
    );
  }
}
