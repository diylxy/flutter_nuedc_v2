import 'dart:math' as math;
import 'package:flutter_nuedc_v2/cv_alg/chessboard.dart';
import 'package:flutter_nuedc_v2/cv_alg/constants.dart';
import 'package:flutter_nuedc_v2/cv_alg/coord_utils.dart';
import 'package:flutter_nuedc_v2/cv_alg/easy_trans.dart';
import 'package:opencv_core/opencv.dart' as cv;

class ClipPaperResult {
  final cv.Mat clipped;
  final CoordinateDesc coord;

  ClipPaperResult({required this.clipped, required this.coord});
}

class PaperFinder {
  Future<cv.VecPoint2f> _getEdgeCorners(
    cv.Mat gray,
    cv.Mat edged, {
    bool weak = false,
    cv.Mat? frame,
  }) async {
    final contourResult = await cv.findContoursAsync(
      edged,
      cv.RETR_LIST,
      cv.CHAIN_APPROX_SIMPLE,
    );
    final contours = contourResult.$1;
    final List<cv.VecPoint> rects = [];

    for (final cnt in contours) {
      final approx = cv.approxPolyDP(cnt, 0.02 * cv.arcLength(cnt, true), true);
      if (approx.length == 4 && cv.isContourConvex(approx)) {
        final area = cv.contourArea(approx);
        assert(area > 0);
        if (weak) {
          if (area < 10000) {
            continue;
          }
        } else {
          if (area < 200 * 200) {
            continue;
          }
        }
        if (area > gray.rows * gray.cols * 0.8) continue;
        rects.add(approx);
      }
    }
    var maxArea = 0.0;
    var maxAreaRect = cv.VecPoint2f(); // 如果没有找到有效角点，返回空List
    for (final inner in rects) {
      // 计算四个点的重心
      double cx = 0, cy = 0;
      for (final pt in inner) {
        cx += pt.x;
        cy += pt.y;
      }
      cx /= 4;
      cy /= 4;

      bool allPointsValid = true;
      for (final pt in inner) {
        int x = pt.x.round();
        int y = pt.y.round();
        double dx = cx - x;
        double dy = cy - y;
        double length = math.sqrt(dx * dx + dy * dy);
        int ox, oy;
        if (length == 0) {
          ox = x;
          oy = y;
        } else {
          if (weak) {
            ox = (x + dx / length * 8).round();
            oy = (y + dy / length * 8).round();
          } else {
            ox = (x + dx / length * 20).round();
            oy = (y + dy / length * 15).round();
          }
        }
        if (oy >= 0 && oy < gray.rows && ox >= 0 && ox < gray.cols) {
          // Access pixel value in gray
          int pixel = gray.at<int>(oy, ox);
          if (pixel <= 128) {
            allPointsValid = false;
            break;
          }
        } else {
          allPointsValid = false;
          break;
        }
      }
      if (allPointsValid) {
        // 亚像素级角点精确化
        final corners = cv.VecPoint2f.fromList(
          inner
              .map((pt) => cv.Point2f(pt.x.toDouble(), pt.y.toDouble()))
              .toList(),
        );
        // if (weak == false) {
        cv.cornerSubPix(gray, corners, const (5, 5), const (-1, -1), (
          cv.TERM_MAX_ITER + cv.TERM_EPS,
          30,
          0.001,
        ));
        // }
        final area = cv.contourArea(inner);
        if (area > maxArea) {
          maxAreaRect = corners;
          maxArea = area;
        }
      } else {
        if (frame != null) {
          await cv.drawContoursAsync(
            frame,
            cv.VecVecPoint.fromVecPoint(inner),
            -1,
            cv.Scalar(0, 0, 255),
            thickness: 10,
          );
        }
      }
    }
    return maxAreaRect;
  }

  Future<CoordinateDesc> _getDists(
    cv.VecPoint2f innerCorners,
    cv.Mat mtx,
    cv.Mat dist,
  ) async {
    final cv.VecPoint2f sortedPoints = EasyTrans.orderPointsRect(innerCorners);
    final cv.Mat realPts = cv.Mat.from2DList([
      [-paperWidth / 2, -paperHeight.toDouble(), 0.0],
      [paperWidth / 2, -paperHeight.toDouble(), 0.0],
      [paperWidth / 2, 0.0, 0.0],
      [-paperWidth / 2, 0.0, 0.0],
    ], cv.MatType.CV_32FC1);
    // 求解旋转和平移向量
    final solvePnPResult = cv.solvePnP(
      realPts,
      cv.Mat.from2DList(
        sortedPoints.map((e) => [e.x, e.y]),
        cv.MatType.CV_32FC1,
      ),
      mtx,
      dist,
    );
    final rvec = solvePnPResult.$2;
    final tvec = solvePnPResult.$3;

    // 计算旋转矩阵
    final R = cv.Rodrigues(rvec);

    return CoordinateDesc(R: R, rvec: rvec, tvec: tvec);
  }

  Future<ClipPaperResult?> clipPaper(
    cv.Mat gray,
    CameraCalibrateResult calibrateData, {
    int cannyLow = 200,
    int cannyHigh = 500,
    int bwThresh = 127,
    bool weak = false,
    cv.Mat? frame,
  }) async {
    cv.Mat bw = cv.Mat.empty();
    if (weak) {
      bw = await cv.cannyAsync(gray, cannyLow.toDouble(), cannyHigh.toDouble());
    } else {
      (_, bw) = await cv.thresholdAsync(
        gray,
        bwThresh.toDouble(),
        255,
        cv.THRESH_BINARY,
      );
    }
    final innerCorners = await _getEdgeCorners(
      gray,
      bw,
      weak: weak,
      frame: frame,
    );
    if (innerCorners.isNotEmpty) {
      final result = await _getDists(
        innerCorners,
        calibrateData.mtx,
        calibrateData.dist,
      );

      // 透视变换出A4纸内部区域
      final clipped = await EasyTrans.perspectiveRectangle(
        gray,
        innerCorners,
        width: paperWidth * paperScaleFactor,
        height: paperHeight * paperScaleFactor,
        expand: 0,
      );
      return ClipPaperResult(clipped: clipped, coord: result);
    }
    return null;
  }
}
