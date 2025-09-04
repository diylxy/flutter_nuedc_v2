import 'dart:math' as math;
import 'package:opencv_core/opencv.dart' as cv;
import 'package:flutter_nuedc_v2/cv_alg/constants.dart';

class CircleRadiusResult {
  final cv.Point center;
  final double radius;
  CircleRadiusResult({required this.center, required this.radius});
}

class TaskCircles {
  static CircleRadiusResult? getCircleRadius(cv.VecVecPoint contours, cv.Mat bw) {
    for (final cnt in contours) {
      if (cnt.length >= 5) {
        final ellipse = cv.fitEllipse(cnt);
        final center = ellipse.center;
        final size = ellipse.size;

        double majorAxis = size.width;
        double minorAxis = size.height;

        if ((majorAxis - minorAxis).abs() < 10 && majorAxis > 20) {
          double area = cv.contourArea(cnt);
          double perimeter = cv.arcLength(cnt, true);

          if (perimeter == 0) continue;

          double circularity = 4 * math.pi * area / (perimeter * perimeter);

          if (circularity > 0.8) {
            final centerPoint = cv.Point(center.x.toInt(), center.y.toInt());
            double radius =
                ((majorAxis + minorAxis) / 4 * paperScaleBackFactor);

            if (radius > 40.0) {
              if (bw.at<int>(centerPoint.y, centerPoint.x) == 0) {
                return CircleRadiusResult(center: centerPoint, radius: radius);
              }
            }
          }
        }
      }
    }
    return null;
  }
}
