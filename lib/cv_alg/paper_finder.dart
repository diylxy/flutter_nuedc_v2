import 'dart:math' as math;
import 'package:flutter_nuedc_v2/cv_alg/constants.dart';
import 'package:flutter_nuedc_v2/cv_alg/coord_utils.dart';
import 'package:flutter_nuedc_v2/cv_alg/easy_trans.dart';
import 'package:opencv_core/opencv.dart' as cv;

class ClipPaperResult {
  final cv.Mat clipped;
  final CoordinateDesc coord;
  final List<cv.Mat> dists;

  ClipPaperResult({
    required this.clipped,
    required this.coord,
    required this.dists,
  });
}

class PaperFinder {
  int paperWidth = 170;
  int paperHeight = 257;

  Future<cv.VecPoint2f> getEdgeCorners(
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
        }
        if (area < 200 * 200) {
          continue;
        }
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
          ox = (x + dx / length * 20).round();
          oy = (y + dy / length * 15).round();
        }
        if (oy >= 0 && oy < gray.rows && ox >= 0 && ox < gray.cols) {
          // Access pixel value in gray
          int pixel = gray.at<int>(oy, ox);
          if (pixel <= 80) {
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
        cv.cornerSubPix(gray, corners, const (11, 11), const (-1, -1), (
          cv.TERM_MAX_ITER + cv.TERM_EPS,
          30,
          0.001,
        ));
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

  Future<(CoordinateDesc, List<cv.Mat>)> getDists(
    cv.VecPoint2f innerCorners,
    cv.Mat mtx,
    cv.Mat dist,
  ) async {
    final cv.VecPoint2f sortedPoints = EasyTrans.orderPointsRect(innerCorners);
    final cv.Mat realPts = cv.Mat.from2DList([
      [0.0, 0.0, 0.0],
      [paperWidth.toDouble(), 0.0, 0.0],
      [paperWidth.toDouble(), paperHeight.toDouble(), 0.0],
      [0.0, paperHeight.toDouble(), 0.0],
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

    // 计算4条边的中点三维坐标和距离
    final List<cv.Mat> dists = [];
    for (int edgeIdx = 0; edgeIdx < 4; edgeIdx++) {
      final pt1 = realPts.row(edgeIdx);
      final pt2 = realPts.row((edgeIdx + 1) % 4);
      // 物体坐标系下的中点
      final midpointObj = (pt1.addMat(
        pt2,
      )).divideF32(2.0).convertTo(cv.MatType.CV_64FC1);

      // 将中点从物体坐标系变换到相机坐标系
      final midpointObjReshaped = midpointObj.reshape(1, 3); // shape (3, 1)
      final midpointCam = cv.gemm(R, midpointObjReshaped, 1.0, tvec, 1.0);
      dists.add(midpointCam);
    }
    return (CoordinateDesc(R: R, rvec: rvec, tvec: tvec), dists);
  }

  Future<ClipPaperResult?> clipPaper(
    cv.Mat gray,
    cv.Mat mtx,
    cv.Mat dist, {
    bool weak = false,
    cv.Mat? frame,
  }) async {
    final bw = await cv.thresholdAsync(gray, 60, 255, cv.THRESH_BINARY);
    final innerCorners = await getEdgeCorners(
      gray,
      bw.$2,
      weak: weak,
      frame: frame,
    );
    if (innerCorners.isNotEmpty) {
      final result = await getDists(innerCorners, mtx, dist);

      // 透视变换出A4纸内部区域
      final clipped = await EasyTrans.perspectiveRectangle(
        gray,
        innerCorners,
        width: paperWidth * paperScaleFactor,
        height: paperHeight * paperScaleFactor,
        expand: 0,
      );

      return ClipPaperResult(
        clipped: clipped,
        coord: result.$1,
        dists: result.$2,
      );
    }
    return null;
  }
}
