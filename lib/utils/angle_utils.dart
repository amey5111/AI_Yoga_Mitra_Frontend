import 'dart:math';

class AngleUtils {
  static double calculateAngle(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
  ) {
    final radians = atan2(cy - by, cx - bx) - atan2(ay - by, ax - bx);

    double angle = radians * 180 / pi;

    angle = angle.abs();

    if (angle > 180) {
      angle = 360 - angle;
    }

    return angle;
  }
}
