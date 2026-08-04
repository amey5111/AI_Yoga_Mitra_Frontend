
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Segments to draw, grouped by body region.
/// Each entry is (start, end, jointIndex).
/// [jointIndex] maps to [AngleScorer._joints] — -1 means no joint mapping (use overall score).
const _segments = [
  // HEAD
  (PoseLandmarkType.leftEar, PoseLandmarkType.leftEye, -1),
  (PoseLandmarkType.leftEye, PoseLandmarkType.nose, -1),
  (PoseLandmarkType.nose, PoseLandmarkType.rightEye, -1),
  (PoseLandmarkType.rightEye, PoseLandmarkType.rightEar, -1),
  // SHOULDERS
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, -1),
  // LEFT ARM — joints 0 (left elbow) and 4 (left shoulder abduction)
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, 4),
  (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, 0),
  // RIGHT ARM — joints 1 (right elbow) and 5 (right shoulder abduction)
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, 5),
  (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, 1),
  // TORSO
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, 6),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, 7),
  (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, -1),
  // LEFT LEG — joints 2 (left knee) and 6 (left hip)
  (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, 6),
  (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, 2),
  // RIGHT LEG — joints 3 (right knee) and 7 (right hip)
  (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, 7),
  (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, 3),
  // FEET
  (PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel, -1),
  (PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex, -1),
  (PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel, -1),
  (PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex, -1),
  // HANDS
  (PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky, -1),
  (PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex, -1),
  (PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky, -1),
  (PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex, -1),
];

/// A fully upgraded skeleton painter that:
///
/// 1. Correctly maps ML Kit pixel coordinates onto the widget canvas using
///    the actual camera image size (accounts for the rotated preview).
/// 2. Colours every limb segment individually based on per-joint accuracy.
/// 3. Adds a soft glow on lines when the overall score is high.
/// 4. Only repaints when the pose actually changes.
class PosePainter extends CustomPainter {
  final Pose pose;

  /// Overall smoothed similarity score (0–100) — drives line colour and glow.
  final double similarityScore;

  /// Per-joint scores from [AngleScorer.perJointScores] (8 values, nullable).
  /// Used to colour individual segments.
  final List<double?> perJointScores;

  /// The pixel dimensions of the image that ML Kit processed.
  /// On Android in landscape the image arrives rotated, so
  /// [imageWidth] is the SHORT side and [imageHeight] is the LONG side
  /// of the actual camera frame (before rotation).
  final Size imageSize;

  const PosePainter({
    required this.pose,
    required this.similarityScore,
    required this.perJointScores,
    required this.imageSize,
  });

  // ── Coordinate transform ────────────────────────────────────────────────
  //
  // The camera preview is rendered like this in the screen:
  //
  //   SizedBox(width: previewSize.height, height: previewSize.width)
  //     └── FittedBox(fit: BoxFit.cover)
  //
  // ML Kit returns coordinates in the camera-image space.
  // On Android the front camera in landscape delivers frames where:
  //   • image.width  = short side (e.g. 480)
  //   • image.height = long  side (e.g. 640)
  // and the preview is presented rotated 90°, so we display it as
  //   width = image.height, height = image.width.
  //
  // After FittedBox(cover) that SizedBox is scaled to fill the canvas.
  //
  // Therefore to map an ML Kit point (px, py) to canvas (cx, cy):
  //   cx = (px / imageWidth)  * canvasWidth   [px moves along short axis]
  //   cy = (py / imageHeight) * canvasHeight  [py moves along long  axis]
  //
  // Front-camera mirroring: ML Kit already mirrors landmark X for the front
  // camera on Android when the sensor orientation is accounted for, BUT the
  // CameraPreview widget also mirrors the display. The two effects cancel out,
  // so we do NOT need an explicit horizontal flip here.

  Offset _toCanvas(PoseLandmark lm, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    return Offset(lm.x * scaleX, lm.y * scaleY);
  }

  // ── Colour helpers ──────────────────────────────────────────────────────

  /// Maps a score in [0, 100] to a colour.
  static Color _scoreColor(double score) {
    if (score >= 90) return const Color(0xFF00FF88); // bright mint — excellent
    if (score >= 80) return const Color(0xFF7FFF00); // chartreuse — good
    if (score >= 60) return const Color(0xFFFFAA00); // amber — close
    return const Color(0xFFFF3B30);                  // red — not matching
  }

  // ── Paint helpers ───────────────────────────────────────────────────────

  Paint _linePaint(Color color, {bool glow = false}) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.92)
      ..strokeWidth = glow ? 3.5 : 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (glow) {
      p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    }
    return p;
  }

  Paint _dotPaint(Color color) => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  // ── Draw helpers ────────────────────────────────────────────────────────

  void _drawSegment(
    Canvas canvas,
    Size size,
    PoseLandmarkType startType,
    PoseLandmarkType endType,
    double segmentScore,
  ) {
    final startLm = pose.landmarks[startType];
    final endLm = pose.landmarks[endType];
    if (startLm == null || endLm == null) return;
    // Skip landmarks with very low confidence
    if (startLm.likelihood < 0.3 || endLm.likelihood < 0.3) return;

    final start = _toCanvas(startLm, size);
    final end = _toCanvas(endLm, size);
    final color = _scoreColor(segmentScore);

    // Draw glow pass when overall accuracy is high
    if (similarityScore >= 80) {
      canvas.drawLine(start, end, _linePaint(color, glow: true));
    }
    // Solid line on top
    canvas.drawLine(start, end, _linePaint(color));
  }

  void _drawJoints(Canvas canvas, Size size) {
    for (final lm in pose.landmarks.values) {
      if (lm.likelihood < 0.3) continue;
      final pt = _toCanvas(lm, size);
      final color = _scoreColor(similarityScore);
      // Glow dot
      canvas.drawCircle(pt, 7, _dotPaint(color.withValues(alpha: 0.25)));
      // Solid inner dot
      canvas.drawCircle(pt, 4, _dotPaint(color));
      // White centre pinpoint
      canvas.drawCircle(pt, 1.5, _dotPaint(Colors.white));
    }
  }

  // ── Main paint ──────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    for (final seg in _segments) {
      final startType = seg.$1;
      final endType = seg.$2;
      final jointIdx = seg.$3;

      // Resolve per-segment score
      double segScore = similarityScore;
      if (jointIdx >= 0 && jointIdx < perJointScores.length) {
        segScore = perJointScores[jointIdx] ?? similarityScore;
      }

      _drawSegment(canvas, size, startType, endType, segScore);
    }

    _drawJoints(canvas, size);
  }

  @override
  bool shouldRepaint(covariant PosePainter old) {
    // Only repaint if the pose data or score actually changed
    return old.pose != pose ||
        old.similarityScore != similarityScore ||
        old.perJointScores != perJointScores;
  }
}
