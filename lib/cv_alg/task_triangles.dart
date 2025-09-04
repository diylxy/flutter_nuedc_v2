import 'dart:math' as math;
import 'package:opencv_core/opencv.dart' as cv;
import 'package:flutter_nuedc_v2/cv_alg/constants.dart';

class TriangleSizeResult {
  final cv.Point center;
  final double width;
  final cv.VecPoint approx;

  TriangleSizeResult({
    required this.center,
    required this.width,
    required this.approx,
  });
}

class TaskTriangles {
  static TriangleSizeResult? getTriangleSize(cv.VecVecPoint contours, cv.Mat gray) {
    for (final cnt in contours) {
      final approx = cv.approxPolyDP(cnt, 0.02 * cv.arcLength(cnt, true), true);
      if (approx.length == 3 && cv.contourArea(approx) > 10000) {
        final corners = cv.VecPoint2f.fromList(
          approx
              .map((pt) => cv.Point2f(pt.x.toDouble(), pt.y.toDouble()))
              .toList(),
        );
        cv.cornerSubPix(gray, corners, const (11, 11), const (-1, -1), (
          cv.TERM_MAX_ITER + cv.TERM_EPS,
          30,
          0.001,
        ));

        final a = math.sqrt(
          math.pow(corners[0].x - corners[1].x, 2) +
              math.pow(corners[0].y - corners[1].y, 2),
        );
        final b = math.sqrt(
          math.pow(corners[1].x - corners[2].x, 2) +
              math.pow(corners[1].y - corners[2].y, 2),
        );
        final c = math.sqrt(
          math.pow(corners[2].x - corners[0].x, 2) +
              math.pow(corners[2].y - corners[0].y, 2),
        );

        final lengths = [a, b, c];
        final rangeVal = lengths.reduce(math.max) - lengths.reduce(math.min);

        if (rangeVal < 10) {
          final width =
              lengths.reduce((sum, len) => sum + len) / lengths.length;
          final centerX =
              corners.map((p) => p.x).reduce((sum, x) => sum + x) / 3;
          final centerY =
              corners.map((p) => p.y).reduce((sum, y) => sum + y) / 3;
          final center = cv.Point(centerX.toInt(), centerY.toInt());

          if (gray.at<int>(center.y, center.x) < 128) {
            return TriangleSizeResult(
              center: center,
              width: width * paperScaleBackFactor,
              approx: approx,
            );
          }
        }
      }
    }
    return null;
  }
}
