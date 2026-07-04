import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final Pose pose;

  PosePainter(this.pose);

  Offset _point(PoseLandmarkType type) {
    final landmark = pose.landmarks[type];

    if (landmark == null) {
      return Offset.zero;
    }

    return Offset(landmark.x, landmark.y);
  }

  void _drawLine(
    Canvas canvas,
    Paint paint,
    PoseLandmarkType start,
    PoseLandmarkType end,
  ) {
    final startPoint = pose.landmarks[start];

    final endPoint = pose.landmarks[end];

    if (startPoint == null || endPoint == null) {
      return;
    }

    canvas.drawLine(
      Offset(startPoint.x, startPoint.y),
      Offset(endPoint.x, endPoint.y),
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // ==========================
    // HEAD
    // ==========================

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.leftEye,
      PoseLandmarkType.rightEye,
    );

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.leftEye,
      PoseLandmarkType.nose,
    );

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.rightEye,
      PoseLandmarkType.nose,
    );

    // ==========================
    // SHOULDERS
    // ==========================

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    );

    // ==========================
    // LEFT ARM
    // ==========================

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftElbow,
    );

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.leftWrist,
    );

    // ==========================
    // RIGHT ARM
    // ==========================

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightElbow,
    );

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.rightWrist,
    );

    // ==========================
    // TORSO
    // ==========================

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.leftHip,
    );

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
    );

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    );

    // ==========================
    // LEFT LEG
    // ==========================

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
    );

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    );

    // ==========================
    // RIGHT LEG
    // ==========================

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
    );

    _drawLine(
      canvas,
      linePaint,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
    );

    // ==========================
    // DRAW JOINTS
    // ==========================

    for (final landmark in pose.landmarks.values) {
      canvas.drawCircle(Offset(landmark.x, landmark.y), 6, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
