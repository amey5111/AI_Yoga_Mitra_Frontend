class PoseReference {
  final String poseName;

  final List<double> referenceVector;

  final double threshold;

  final int holdTime;

  PoseReference({
    required this.poseName,
    required this.referenceVector,
    required this.threshold,
    required this.holdTime,
  });

  factory PoseReference.fromJson(Map<String, dynamic> json) {
    return PoseReference(
      poseName: json['poseName'],

      referenceVector: List<double>.from(json['referenceVector']),

      threshold: (json['threshold'] as num).toDouble(),

      holdTime: json['holdTime'],
    );
  }
}
