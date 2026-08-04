import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Computes an angle-based accuracy score (0–100) by comparing the user's
/// joint angles against a set of reference angles stored alongside each
/// [PoseReference].  This is combined with cosine similarity for the final
/// hybrid score.
class AngleScorer {
  /// The 8 joint triplets we evaluate.
  /// Each entry is (vertex, pointA, pointB) — the angle is at the vertex.
  static const List<(PoseLandmarkType, PoseLandmarkType, PoseLandmarkType)>
      _joints = [
    // Elbows
    (
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftWrist
    ),
    (
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightWrist
    ),
    // Knees
    (
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftAnkle
    ),
    (
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightAnkle
    ),
    // Shoulder abduction (arm raise)
    (
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftElbow
    ),
    (
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightElbow
    ),
    // Hip flexion
    (
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftKnee
    ),
    (
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightKnee
    ),
  ];

  /// Extract the 8 joint angles from a live [Pose].
  /// Returns null for any joint where landmarks are missing or low-confidence.
  static List<double?> extractAngles(Pose pose) {
    return _joints.map((triplet) {
      final vertex = pose.landmarks[triplet.$1];
      final a = pose.landmarks[triplet.$2];
      final b = pose.landmarks[triplet.$3];
      if (vertex == null || a == null || b == null) return null;
      // Require reasonable confidence for all three points
      if (vertex.likelihood < 0.4 || a.likelihood < 0.4 || b.likelihood < 0.4) {
        return null;
      }
      return _angle(a.x, a.y, vertex.x, vertex.y, b.x, b.y);
    }).toList();
  }

  /// Compare live angles against reference angles.
  /// [referenceAngles] is a list of 8 nullable doubles (null = skip that joint).
  /// Returns a score 0–100.
  static double score(List<double?> liveAngles, List<double?> referenceAngles) {
    double total = 0;
    int count = 0;
    for (int i = 0; i < liveAngles.length && i < referenceAngles.length; i++) {
      final live = liveAngles[i];
      final ref = referenceAngles[i];
      if (live == null || ref == null) continue;
      final error = (live - ref).abs();
      // Linear mapping: 0° error → 100, 180° error → 0
      final jointScore = (100 - (error / 1.8)).clamp(0.0, 100.0);
      total += jointScore;
      count++;
    }
    return count == 0 ? 0 : total / count;
  }

  /// Per-joint scores — used by the painter to colour individual limb segments.
  /// Returns a list of 8 values in [0, 100] (or null if the joint was skipped).
  static List<double?> perJointScores(
      List<double?> liveAngles, List<double?> referenceAngles) {
    return List.generate(liveAngles.length, (i) {
      final live = i < liveAngles.length ? liveAngles[i] : null;
      final ref = i < referenceAngles.length ? referenceAngles[i] : null;
      if (live == null || ref == null) return null;
      final error = (live - ref).abs();
      return (100 - (error / 1.8)).clamp(0.0, 100.0);
    });
  }

  static double _angle(
    double ax, double ay,
    double bx, double by,
    double cx, double cy,
  ) {
    final radians = atan2(cy - by, cx - bx) - atan2(ay - by, ax - bx);
    double deg = radians * 180 / pi;
    deg = deg.abs();
    if (deg > 180) deg = 360 - deg;
    return deg;
  }
}
