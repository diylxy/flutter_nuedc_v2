import 'dart:math' as math;

import 'package:opencv_core/opencv.dart' as cv;

import 'package:flutter_nuedc_v2/cv_alg/constants.dart';
import 'package:flutter_nuedc_v2/cv_alg/digit_recognizer_cnn.dart';
import 'package:flutter_nuedc_v2/cv_alg/easy_trans.dart';
import 'package:flutter_nuedc_v2/cv_alg/line_utils.dart';

class MultiRectanglesResult {
  final cv.Point2f center;
  final double size;
  final int? number;

  MultiRectanglesResult({
    required this.center,
    required this.size,
    this.number,
  });
}

class TaskMultiRectangles {
  DigitRecognizerCnn recognizer = DigitRecognizerCnn();

  double radiansToDegrees(double radians) {
    return radians * (180 / math.pi);
  }

  cv.Point2f normalizeVector(cv.Point2f v) {
    final norm = math.sqrt(v.x * v.x + v.y * v.y) + 1e-8;
    return cv.Point2f(v.x / norm, v.y / norm);
  }

  double angleBetween(cv.Point2f v1, cv.Point2f v2) {
    v1 = normalizeVector(v1);
    v2 = normalizeVector(v2);
    final dot = (v1.x * v2.x + v1.y * v2.y).clamp(-1.0, 1.0);
    return radiansToDegrees(math.acos(dot));
  }

  bool canFormRectangle(List<double> angles) {
    final n = angles.length;
    final anglePairs = <double>[];
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        anglePairs.add(LineUtils.angleBetweenLines(angles[i], angles[j]));
      }
    }
    final rightAngles = anglePairs.where((a) => (a - 90).abs() < 5).toList();
    return rightAngles.length == 4;
  }

  bool isSquare(cv.VecPoint2f points) {
    // final List<double> sideLengths = [];
    double max = 0;
    double min = double.maxFinite;
    for (var i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      double distance = math.sqrt(
        math.pow(p2.x - p1.x, 2) + math.pow(p2.y - p1.y, 2),
      );
      if (max < distance) max = distance;
      if (min > distance) min = distance;
      // sideLengths.add(distance);
    }
    if (max - min > 10) {
      return false;
    }
    if (min < minRectPixels) {
      return false;
    }
    return true;
  }

  double contourArea(cv.VecPoint contour) {
    double signedArea = 0.0;
    for (int i = 0; i < contour.size(); i++) {
      cv.Point p1 = contour[i];
      cv.Point p2 = contour[(i + 1) % contour.length];
      signedArea += (p1.x * p2.y - p2.x * p1.y);
    }
    return signedArea / 2.0;
  }

  bool checkOuterAngle(
    cv.VecPoint2f rectangle,
    cv.VecPoint2f points,
    List<double> angles,
  ) {
    for (int i = 0; i < points.length; ++i) {
      if (angles[i] == 0) {
        if (cv.pointPolygonTest(
              rectangle
                  .map((e) => cv.Point(e.x.toInt(), e.y.toInt()))
                  .toList()
                  .asVec(),
              points[i],
              true,
            ) >=
            20) {
          return false;
        }
      }
    }
    return true;
  }

  /// 使用两个相邻点 [pa] [pb] 经过[p0]，构建一个正方形
  cv.VecPoint2f? constructSquareBy2VertexesAndDir(
    cv.Point2f pa,
    cv.Point2f pb,
    cv.Point2f p0,
  ) {
    // 计算p1到p2的向量和长度
    final edgeVec = cv.Point2f(pb.x - pa.x, pb.y - pa.y);
    final edgeLen = math.sqrt(edgeVec.x * edgeVec.x + edgeVec.y * edgeVec.y);
    if (edgeLen == 0) return null;

    // 单位方向向量
    final edgeDir = cv.Point2f(edgeVec.x / edgeLen, edgeVec.y / edgeLen);

    // 计算p1p0的方向向量
    var dir1 = cv.Point2f(p0.x - pa.x, p0.y - pa.y);
    final dir1Len = math.sqrt(dir1.x * dir1.x + dir1.y * dir1.y) + 1e-8;
    dir1 = cv.Point2f(dir1.x / dir1Len, dir1.y / dir1Len);

    // 修正方向向量，使其与p1p2垂直，且不偏移超过90度
    var perp = cv.Point2f(-edgeDir.y, edgeDir.x);

    // 选择与原始dir1夹角小于90度的垂直方向
    if (perp.x * dir1.x + perp.y * dir1.y < 0) {
      perp = cv.Point2f(-perp.x, -perp.y);
    }

    // 构造正方形的四个顶点
    final q1 = pa;
    final q2 = pb;
    final q0 = cv.Point2f(pa.x + perp.x * edgeLen, pa.y + perp.y * edgeLen);
    final q3 = cv.Point2f(pb.x + perp.x * edgeLen, pb.y + perp.y * edgeLen);

    return cv.VecPoint2f.fromList([q0, q1, q2, q3]);
  }

  Future<cv.VecVecPoint2f> getRectangles(
    cv.Mat gray,
    cv.VecVecPoint contours, {
    cv.Mat? clippedBGR,
  }) async {
    final List<cv.VecPoint> approxRects = [];
    final List<cv.VecPoint> approxWhiteRects = [];
    for (final cnt in contours) {
      final epsilon = 10.0;
      final minArea = 10000.0;
      final maxArea = gray.shape[0] * gray.shape[1] * 0.95;
      final approx = await cv.approxPolyDPAsync(cnt, epsilon, true);
      double area = contourArea(approx);
      // 小于0表示白色在黑色内，逆时针
      if (area < -2000 && area > -maxArea) {
        if (approx.length < 10) {
          approxWhiteRects.add(approx);
        }
      }
      if (area < minArea || area > maxArea) {
        if (area > maxArea) {}
        continue;
      }
      approxRects.add(approx);
    }
    final rectangles = <cv.VecPoint2f>[];
    for (final rectPending in approxRects) {
      // 对每个点进行亚像素拟合
      final points = cv.VecPoint2f.fromList(
        rectPending
            .map((e) => cv.Point2f(e.x.toDouble(), e.y.toDouble()))
            .toList(),
      );
      cv.cornerSubPix(gray, points, const (11, 11), const (-1, -1), (
        cv.TERM_MAX_ITER + cv.TERM_EPS,
        30,
        0.001,
      ));
      final n = points.length;
      final anglesInfo = <double>[];
      final orpanVertexesMap = <int>[];
      final newRects = <cv.VecPoint2f>[];
      // 计算全部顶点角度信息
      for (int i = 0; i < n; i++) {
        final p0 = points[(i - 1 + n) % n];
        final pa = points[i];
        final pb = points[(i + 1) % n];
        final v1 = cv.Point2f(p0.x - pa.x, p0.y - pa.y);
        final v2 = cv.Point2f(pb.x - pa.x, pb.y - pa.y);
        final det = v1.x * v2.y - v1.y * v2.x;
        final dot = v1.x * v2.x + v1.y * v2.y;
        double angle = radiansToDegrees(math.atan2(det, dot)); // atan2带符号，判断内外角
        angle = -angle;
        if (angle < 85.0 || angle > 95.0) {
          // 不是内90度角，跳过
          anglesInfo.add(0);
          orpanVertexesMap.add(-1);
          cv.circle(
            clippedBGR!,
            cv.Point(pa.x.round(), pa.y.round()),
            2,
            cv.Scalar(0, 0, 255), // 红色
            thickness: -1,
          );
          continue;
        }
        cv.circle(
          clippedBGR!,
          cv.Point(pa.x.round(), pa.y.round()),
          2,
          cv.Scalar(255, 255, 0), // 蓝色
          thickness: -1,
        );
        anglesInfo.add(angle);
        orpanVertexesMap.add(1);
      }
      // 查找相邻点
      for (int i = 0; i < n; i++) {
        final thisIdx = i;
        final nextIdx = (i + 1) % n;
        final prevIdx = (i - 1 + n) % n;
        final a1 = anglesInfo[thisIdx];
        final a2 = anglesInfo[nextIdx];
        final pa = points[i];
        final p0 = points[prevIdx];
        final pb = points[nextIdx];
        if (a1 <= 0 || a2 <= 0) continue;
        // 认为a1、a2处有正方形
        // 移除孤立点标记
        orpanVertexesMap[thisIdx] = 0;
        orpanVertexesMap[nextIdx] = 0;
        final square = constructSquareBy2VertexesAndDir(pa, pb, p0);
        if (square == null) continue;
        if (checkOuterAngle(square, points, anglesInfo)) {
          newRects.add(square);
        }
      }
      // 查找孤立点
      final orpanIndices = List.generate(
        orpanVertexesMap.length,
        (i) => i,
      ).where((i) => orpanVertexesMap[i] == 1).toList();
      final opLen = orpanIndices.length;
      for (int i = 0; i < opLen; i++) {
        for (int j = 0; j < opLen; j++) {
          final oi = orpanIndices[i];
          final oj = orpanIndices[j];
          final p0a = points[(oi - 1 + n) % n];
          final pa = points[oi];
          final p2a = points[(oi + 1) % n];
          final p0b = points[(oj - 1 + n) % n];
          final pb = points[oj];
          final p2b = points[(oj + 1) % n];
          // 计算v1的两条边向量
          final vec1a = cv.Point2f(p0a.x - pa.x, p0a.y - pa.y);
          final vec1b = cv.Point2f(p2a.x - pa.x, p2a.y - pa.y);
          // 计算v2的两条边向量
          final vec2a = cv.Point2f(p0b.x - pb.x, p0b.y - pb.y);
          final vec2b = cv.Point2f(p2b.x - pb.x, p2b.y - pb.y);
          bool found = false;

          for (final a in [vec1a, vec1b]) {
            for (final b in [vec2a, vec2b]) {
              final ang = angleBetween(a, b);
              // 判断是否平行或垂直
              if ((ang).abs() < 5 ||
                  (ang - 180).abs() < 5 ||
                  (ang - 90).abs() < 5) {
                found = true;
                break;
              }
            }
            if (found) {
              break;
            }
          }

          if (found == false) continue;
          final ptsPairs = [
            [pa, p0a],
            [pa, p2a],
            [pb, p0b],
            [pb, p2b],
          ];
          final intersects = <cv.Point2f>[];

          for (int p = 0; p < 2; p++) {
            for (int q = 2; q < 4; q++) {
              final ptIntersect = LineUtils.rayIntersection(
                ptsPairs[p][0],
                ptsPairs[p][1],
                ptsPairs[q][0],
                ptsPairs[q][1],
              );
              if (ptIntersect != null) {
                intersects.add(ptIntersect);
              }
            }
          }

          final intersectsConfirmed = <cv.Point2f>[];
          final dists0 = intersects
              .map(
                (pt) => math.sqrt(
                  math.pow(pa.x - pt.x, 2) + math.pow(pa.y - pt.y, 2),
                ),
              )
              .toList();
          final dists1 = intersects
              .map(
                (pt) => math.sqrt(
                  math.pow(pb.x - pt.x, 2) + math.pow(pb.y - pt.y, 2),
                ),
              )
              .toList();
          final distPeer = math.sqrt(
            math.pow(pa.x - pb.x, 2) + math.pow(pa.y - pb.y, 2),
          );
          final distTarget = distPeer / math.sqrt(2);
          for (int p = 0; p < intersects.length; p++) {
            if (dists0[p] < 10 || dists1[p] < 10) {
              continue;
            }
            if ((dists0[p] - dists1[p]).abs() < 8) {
              if ((dists0[p] - distTarget).abs() < 8) {
                intersectsConfirmed.add(intersects[p]);
              }
            }
          }

          if (intersectsConfirmed.length == 2) {
            final square = cv.VecPoint2f.fromList([
              pa,
              intersectsConfirmed[0],
              pb,
              intersectsConfirmed[1],
            ]);
            if (checkOuterAngle(square, points, anglesInfo)) {
              newRects.add(square);
            }
            orpanVertexesMap[oi] = 0;
            orpanVertexesMap[oj] = 0;
          }
        }
      }
      // 查找孤立边
      final orphanEdges = <List<cv.Point2f>>[];
      final orpanVertexesCount = orpanVertexesMap.length;
      for (int i = 0; i < orpanVertexesCount; i++) {
        final curr = orpanVertexesMap[i];
        final nextIdx = (i + 1) % n;
        final nextVal = orpanVertexesMap[nextIdx];
        // 连续两个非零点之间的边为孤立边
        if (curr != 0 && nextVal != 0) {
          final p1 = points[i];
          final p2 = points[nextIdx];
          orphanEdges.add([p1, p2]);
        }
      }
      // 查找孔洞边
      final foundHole = <cv.VecPoint>[];
      for (final whiteContour in approxWhiteRects) {
        // 判断白色轮廓的所有点是否都在rectPending内部
        bool allInside = true;
        for (final pt in whiteContour) {
          // 使用cv.pointPolygonTest判断点是否在rectPending内部
          if (cv.pointPolygonTest(
                rectPending,
                cv.Point2f(pt.x.toDouble(), pt.y.toDouble()),
                false,
              ) <
              0) {
            allInside = false;
            break;
          }
        }
        if (allInside) {
          // 亚像素细化
          final whitePoints = cv.VecPoint2f.fromList(
            whiteContour
                .map((pt) => cv.Point2f(pt.x.toDouble(), pt.y.toDouble()))
                .toList(),
          );
          cv.cornerSubPix(gray, whitePoints, const (5, 5), const (-1, -1), (
            cv.TERM_EPS + cv.TERM_MAX_ITER,
            30,
            0.01,
          ));
          // 按顺序连接成边，加入orphanEdges
          final nWhite = whitePoints.length;
          for (int i = 0; i < nWhite; i++) {
            final p1 = whitePoints[i];
            final p2 = whitePoints[(i + 1) % nWhite];
            final distance = math.sqrt(
              math.pow(p1.x - p2.x, 2) + math.pow(p1.y - p2.y, 2),
            );
            if (distance >= 10) {
              orphanEdges.add([p1, p2]);
            }
          }
          foundHole.add(whiteContour);
        }
      }
      // 从approxWhiteRects中移除foundHole中的每个元素
      for (final hole in foundHole) {
        approxWhiteRects.remove(hole);
      }
      // 对orphanEdges中的每4对边，尝试延长并求交点
      final edgeAngles = orphanEdges.map((edge) {
        final p1 = edge[0];
        final p2 = edge[1];
        final vec = cv.Point2f(p2.x - p1.x, p2.y - p1.y);
        return radiansToDegrees(math.atan2(vec.y, vec.x));
      }).toList();

      final usedEdges = <int>{};
      if (orphanEdges.length >= 4) {
        final combinations = <List<int>>[];
        for (int i = 0; i < orphanEdges.length; i++) {
          for (int j = i + 1; j < orphanEdges.length; j++) {
            for (int k = j + 1; k < orphanEdges.length; k++) {
              for (int l = k + 1; l < orphanEdges.length; l++) {
                combinations.add([i, j, k, l]);
              }
            }
          }
        }

        for (final groupIndices in combinations) {
          if (groupIndices.any((idx) => usedEdges.contains(idx))) {
            continue;
          }

          final group = groupIndices.map((idx) => orphanEdges[idx]).toList();
          final anglesGroup = groupIndices
              .map((idx) => edgeAngles[idx])
              .toList();

          // 判断是否满足条件
          if (canFormRectangle(anglesGroup)) {
            final intersections = cv.VecPoint2f();
            for (int groupId1 = 0; groupId1 < 4; groupId1++) {
              for (int groupId2 = groupId1 + 1; groupId2 < 4; groupId2++) {
                final p1 = group[groupId1][0];
                final p2 = group[groupId1][1];
                final q1 = group[groupId2][0];
                final q2 = group[groupId2][1];
                final pt = LineUtils.lineIntersection(p1, p2, q1, q2);
                if (pt != null &&
                    pt.x >= 0 &&
                    pt.x < gray.shape[1] &&
                    pt.y >= 0 &&
                    pt.y < gray.shape[0]) {
                  intersections.add(pt);
                }
              }
            }

            if (intersections.length == 4) {
              final square = EasyTrans.orderPoints(intersections);
              if (isSquare(square)) {
                if (checkOuterAngle(square, points, anglesInfo)) {
                  newRects.add(square);
                }
                usedEdges.addAll(groupIndices);
              }
            }
          }
        }
      }
      // 所有正方形查找完成，开始修正
      // 修正newRects中的点为points中更精确的点
      for (int rectIdx = 0; rectIdx < newRects.length; rectIdx++) {
        final rect = newRects[rectIdx];
        for (int ptIdx = 0; ptIdx < rect.length; ptIdx++) {
          final pt = rect[ptIdx];
          double minDist = double.maxFinite;
          int minIdx = -1;
          for (int i = 0; i < points.length; i++) {
            if (orpanVertexesMap[i] == -1) {
              continue;
            }
            final p = points[i];
            final dist = math.sqrt(
              math.pow(pt.x - p.x, 2) + math.pow(pt.y - p.y, 2),
            );
            if (dist < minDist && dist < 10) {
              minDist = dist;
              minIdx = i;
            }
          }
          if (minIdx != -1) {
            newRects[rectIdx][ptIdx] = points[minIdx];
          }
        }
      }
      // rect_corrections 列表与 newRects 顺序对应，记录每个正方形被修正的次数
      // 只保留修正次数较多的正方形（有公共点时）
      // 统计每个正方形被修正的次数（即有多少顶点被points中的点替换）
      final rectCorrections = <int>[];
      for (final rect in newRects) {
        int count = 0;
        for (final pt in rect) {
          for (final p in points) {
            final dist = math.sqrt(
              math.pow(pt.x - p.x, 2) + math.pow(pt.y - p.y, 2),
            );
            if (dist < 1e-4) {
              count++;
              break;
            }
          }
        }
        rectCorrections.add(count);
      }
      final keepIndices = Set<int>.from(
        List.generate(newRects.length, (i) => i),
      );

      for (int i = 0; i < newRects.length; i++) {
        for (int j = i + 1; j < newRects.length; j++) {
          if (!keepIndices.contains(i) || !keepIndices.contains(j)) {
            continue;
          }
          // 判断是否有公共点
          int common = 0;
          for (final pti in newRects[i]) {
            for (final ptj in newRects[j]) {
              if (math.sqrt(
                    math.pow(pti.x - ptj.x, 2) + math.pow(pti.y - ptj.y, 2),
                  ) <
                  1e-4) {
                common++;
              }
            }
          }
          if (common >= 1) {
            // 保留修正次数多的
            if (rectCorrections[i] >= rectCorrections[j]) {
              keepIndices.remove(j);
            } else {
              keepIndices.remove(i);
            }
          }
        }
      }
      rectangles.addAll(keepIndices.map((idx) => newRects[idx]));
    }
    // 判断rectangles四个角点向中心偏移10像素的位置是否为黑色
    final filteredRectangles = <cv.VecPoint2f>[];
    for (final rect in rectangles) {
      final poly = rect.toList();
      final center = cv.Point2f(
        poly.map((p) => p.x).reduce((a, b) => a + b) / poly.length,
        poly.map((p) => p.y).reduce((a, b) => a + b) / poly.length,
      );
      var valid = true;
      for (final pt in poly) {
        final v = cv.Point2f(pt.x - center.x, pt.y - center.y);
        final norm = math.sqrt(v.x * v.x + v.y * v.y) + 1e-5;
        final offsetPt = cv.Point2f(
          center.x + v.x * ((norm - 10) / norm),
          center.y + v.y * ((norm - 10) / norm),
        );
        final x = offsetPt.x.round();
        final y = offsetPt.y.round();
        // 检查是否在图像范围内
        if (x < 0 || x >= gray.shape[1] || y < 0 || y >= gray.shape[0]) {
          valid = false;
          break;
        }
        // 判断偏移点是否为黑色（灰度值小于阈值）
        if (gray.at<int>(y, x) > 127) {
          valid = false;
          break;
        }
      }
      if (valid) {
        filteredRectangles.add(rect);
      }
    }
    return filteredRectangles.map((e) => e.toList()).toList().asVec();
  }

  Future<List<MultiRectanglesResult>> getRectangleSizeAndClipInnerWhiteNumbers(
    cv.VecVecPoint2f rectangles,
    cv.Mat clipped,
    cv.Mat bw,
  ) async {
    await recognizer.init();
    final results = <MultiRectanglesResult>[];

    for (final rect in rectangles) {
      // Calculate the average side length of the square
      final poly = rect.toList();
      final sideLengths = List.generate(
        4,
        (i) => math.sqrt(
          math.pow(poly[i].x - poly[(i + 1) % 4].x, 2) +
              math.pow(poly[i].y - poly[(i + 1) % 4].y, 2),
        ),
      );
      final size = sideLengths.reduce((a, b) => a + b) / sideLengths.length;

      const epsilon = 1e-5; // Prevent division by zero
      final offsetPoly = <cv.Point2f>[];
      final center = cv.Point2f(
        poly.map((p) => p.x).reduce((a, b) => a + b) / poly.length,
        poly.map((p) => p.y).reduce((a, b) => a + b) / poly.length,
      );

      for (final pt in poly) {
        final v = cv.Point2f(pt.x - center.x, pt.y - center.y);
        final norm = math.sqrt(v.x * v.x + v.y * v.y) + epsilon;
        final offsetPt = cv.Point2f(
          center.x + v.x * ((norm - 20) / norm),
          center.y + v.y * ((norm - 20) / norm),
        );
        offsetPoly.add(offsetPt);
      }

      // Create a mask for the offset polygon
      final mask = cv.Mat.zeros(bw.rows, bw.cols, cv.MatType.CV_8UC1);
      final offsetPolyInt = cv.VecVecPoint.fromList([
        offsetPoly.map((pt) => cv.Point(pt.x.round(), pt.y.round())).toList(),
      ]);
      cv.fillPoly(mask, offsetPolyInt, cv.Scalar.all(255));

      // Retain only the square's interior
      final roi = cv.bitwiseAND(bw, bw, mask: mask);

      // Find contours of white regions (holes)
      final contours = await cv.findContoursAsync(
        roi,
        cv.RETR_EXTERNAL,
        cv.CHAIN_APPROX_SIMPLE,
      );

      if (contours.$1.isNotEmpty) {
        final allPoints = cv.VecPoint.fromList(
          contours.$1.expand((cnt) => cnt).toList(),
        );
        final minRect = cv.minAreaRect(allPoints);
        final box = cv.boxPoints(minRect);

        final persp = await EasyTrans.perspectiveRectangle(
          clipped,
          box,
          width: 24,
          height: 24,
          expand: 5,
        );

        final number = await recognizer.inference(persp);
        results.add(
          MultiRectanglesResult(center: center, size: size, number: number),
        );
      } else {
        results.add(
          MultiRectanglesResult(center: center, size: size, number: null),
        );
      }
    }

    return results;
  }
}
