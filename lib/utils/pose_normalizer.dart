import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/normalized_landmark.dart';

class PoseNormalizer {
  /// Normalize a pose into a scale- and position-invariant vector.
  ///
  /// Strategy:
  ///  1. Compute a confidence-weighted centroid from the four torso anchors.
  ///  2. Scale by the hip-to-shoulder diagonal (more stable than torso height).
  ///  3. Filter out landmarks whose ML Kit likelihood is below [minLikelihood].
  ///     Filtered landmarks are set to (0, 0) so the vector length stays fixed
  ///     at 33 landmarks (66 values) — the reference data expects this length.
  static List<NormalizedLandmark> normalize(
    Pose pose, {
    double minLikelihood = 0.4,
  }) {
    final lh = pose.landmarks[PoseLandmarkType.leftHip];
    final rh = pose.landmarks[PoseLandmarkType.rightHip];
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];

    // ── Confidence-weighted centroid ──────────────────────────────────────
    double wSumX = 0, wSumY = 0, wTotal = 0;
    for (final lm in [lh, rh, ls, rs]) {
      if (lm == null) continue;
      final w = lm.likelihood.clamp(0.0, 1.0);
      wSumX += lm.x * w;
      wSumY += lm.y * w;
      wTotal += w;
    }

    // Fall back to simple average if all anchors are absent
    final centerX = wTotal > 0 ? wSumX / wTotal : 0.0;
    final centerY = wTotal > 0 ? wSumY / wTotal : 0.0;

    // ── Scale: diagonal from hip-midpoint to shoulder-midpoint ────────────
    double scale = 1.0;
    if (lh != null && rh != null && ls != null && rs != null) {
      final hipMidX = (lh.x + rh.x) / 2;
      final hipMidY = (lh.y + rh.y) / 2;
      final shoulderMidX = (ls.x + rs.x) / 2;
      final shoulderMidY = (ls.y + rs.y) / 2;
      scale = sqrt(
        pow(shoulderMidX - hipMidX, 2) + pow(shoulderMidY - hipMidY, 2),
      );
      if (scale < 1e-6) scale = 1.0; // guard divide-by-zero
    }

    // ── Build normalized vector ───────────────────────────────────────────
    final normalized = <NormalizedLandmark>[];
    for (final landmark in pose.landmarks.values) {
      if (landmark.likelihood < minLikelihood) {
        // Keep slot but zero it out — preserves fixed vector length
        normalized.add(const NormalizedLandmark(x: 0, y: 0));
      } else {
        normalized.add(NormalizedLandmark(
          x: (landmark.x - centerX) / scale,
          y: (landmark.y - centerY) / scale,
        ));
      }
    }

    return normalized;
  }
}
