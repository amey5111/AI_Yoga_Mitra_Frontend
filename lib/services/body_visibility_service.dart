import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class BodyVisibilityResult {
  final bool isVisible;
  final String message;

  const BodyVisibilityResult({required this.isVisible, required this.message});
}

class BodyVisibilityService {
  /// Minimum ML Kit landmark likelihood to consider a point detected.
  static const double _minLikelihood = 0.30;

  /// Core torso anchors (must be visible to track pose)
  static const _coreAnchors = [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
  ];

  /// Secondary limbs (nudge user if low confidence, but keep tracking enabled)
  static const _limbPoints = [
    (PoseLandmarkType.leftKnee, 'left knee'),
    (PoseLandmarkType.rightKnee, 'right knee'),
    (PoseLandmarkType.leftAnkle, 'left ankle'),
    (PoseLandmarkType.rightAnkle, 'right ankle'),
    (PoseLandmarkType.leftWrist, 'left wrist'),
    (PoseLandmarkType.rightWrist, 'right wrist'),
  ];

  static BodyVisibilityResult validate(Pose pose) {
    final landmarks = pose.landmarks;

    // 1. Check core torso anchors
    for (final type in _coreAnchors) {
      final point = landmarks[type];
      if (point == null || point.likelihood < _minLikelihood) {
        return const BodyVisibilityResult(
          isVisible: false,
          message: 'Step back into camera view',
        );
      }
    }

    // 2. Check limbs for specific nudges
    for (final (type, name) in _limbPoints) {
      final point = landmarks[type];
      if (point == null || point.likelihood < _minLikelihood) {
        return BodyVisibilityResult(
          isVisible: true,
          message: 'Make $name visible',
        );
      }
    }

    return const BodyVisibilityResult(
      isVisible: true,
      message: 'Full body detected ✓',
    );
  }
}
