import 'dart:math' as math;
import 'package:opencv_core/opencv.dart' as cv;

class EasyTrans {
  static cv.Point2f _mean(cv.VecPoint2f pts) {
    final ptsList = pts.toList();
    final n = ptsList.length;
    if (n == 0) return cv.Point2f(0, 0);
    final sumX = ptsList.map((p) => p.x).reduce((a, b) => a + b);
    final sumY = ptsList.map((p) => p.y).reduce((a, b) => a + b);
    return cv.Point2f(sumX / n, sumY / n);
  }

  static cv.VecPoint2f orderPoints(cv.VecPoint2f pts) {
    List<cv.Point2f> ptsList = pts.toList();
    // 计算中心点
    final center = _mean(pts);

    // 计算每个点相对于中心点的角度
    final angles = ptsList
        .map((p) => math.atan2(p.y - center.y, p.x - center.x))
        .toList();

    // 按角度顺时针排序
    final sortedIndices = List.generate(ptsList.length, (i) => i)
      ..sort((a, b) => angles[a].compareTo(angles[b]));

    final rect = sortedIndices.map((i) => ptsList[i]).toList();
    final sortedAngles = sortedIndices.map((i) => angles[i]).toList();

    // 找到最靠左上角的点（角度最接近135度，即第二象限45度斜线方向）
    final targetAngle = -3 * math.pi / 4;
    final angleDiffs = sortedAngles
        .map((a) => ((a - targetAngle + math.pi) % (2 * math.pi)) - math.pi)
        .map((d) => d.abs())
        .toList();
    final startIdx = angleDiffs.indexOf(angleDiffs.reduce(math.min));

    // 循环移动rect，使左上角点为第一个
    final orderedRect = [
      ...rect.sublist(startIdx),
      ...rect.sublist(0, startIdx),
    ];

    return cv.VecPoint2f.fromList(orderedRect);
  }

  static cv.VecPoint2f orderPointsRect(cv.VecPoint2f pts) {
    List<cv.Point2f> ptsList = pts.toList();
    // 计算中心点
    final center = _mean(pts);

    // 计算每个点相对于中心点的角度
    final angles = ptsList
        .map((p) => math.atan2(p.y - center.y, p.x - center.x))
        .toList();

    // 按角度顺时针排序
    final sortedIndices = List.generate(ptsList.length, (i) => i)
      ..sort((a, b) => angles[a].compareTo(angles[b]));

    final rect = sortedIndices.map((i) => ptsList[i]).toList();
    final n = rect.length;

    // 计算与下一个点和上一个点的距离
    final distsNext = List.generate(
      n,
      (i) => math.sqrt(
        math.pow(rect[i].x - rect[(i + 1) % n].x, 2) +
            math.pow(rect[i].y - rect[(i + 1) % n].y, 2),
      ),
    );
    final distsPrev = List.generate(
      n,
      (i) => math.sqrt(
        math.pow(rect[i].x - rect[(i - 1 + n) % n].x, 2) +
            math.pow(rect[i].y - rect[(i - 1 + n) % n].y, 2),
      ),
    );

    // 找到与下一个点的距离比上一个点小的点
    final candidates = <int>[];
    for (int i = 0; i < n; i++) {
      if (distsNext[i] < distsPrev[i]) {
        candidates.add(i);
      }
    }

    int startIdx;
    if (candidates.isEmpty) {
      startIdx = 0;
    } else {
      // 在候选点中选择y坐标最小的点
      double minY = rect[candidates[0]].y.toDouble();
      for (final i in candidates) {
        if (rect[i].y < minY) minY = rect[i].y.toDouble();
      }
      final minYCandidates = candidates
          .where((i) => rect[i].y == minY)
          .toList();
      startIdx = minYCandidates[0];
    }

    // 循环移动rect，使选中的点为第一个
    final orderedRect = [
      ...rect.sublist(startIdx),
      ...rect.sublist(0, startIdx),
    ];

    return cv.VecPoint2f.fromList(orderedRect);
  }

  static Future<cv.Mat> perspectiveRectangle(
    cv.Mat img,
    cv.VecPoint2f pts, {
    double width = 640,
    double height = 480,
    double expand = 5,
    bool autoRotate = true,
    bool useRect = true,
  }) async {
    cv.VecPoint2f rect;
    if (autoRotate) {
      if (useRect) {
        rect = orderPointsRect(pts);
      } else {
        rect = orderPoints(pts);
      }
    } else {
      rect = pts;
    }
    cv.VecPoint2f dst = cv.VecPoint2f.fromList([
      cv.Point2f(0, 0),
      cv.Point2f(width - 1, 0),
      cv.Point2f(width - 1, height - 1),
      cv.Point2f(0, height - 1),
    ]);
    // compute the perspective transform matrix
    final cv.Mat M = await cv.getPerspectiveTransform2fAsync(rect, dst);
    final double sx = (width - 2 * expand) / width;
    final double sy = (height - 2 * expand) / height;
    final cv.Mat S = cv.Mat.from2DList([
      [sx, 0.0, expand],
      [0.0, sy, expand],
      [0.0, 0.0, 1.0],
    ], cv.MatType.CV_64FC1);
    // Compose the transformation: H = S @ M
    final cv.Mat H = await cv.gemmAsync(S, M, 1, cv.Mat.empty(), 0);
    // Apply the perspective transformation
    return await cv.warpPerspectiveAsync(img, H, (
      width.toInt(),
      height.toInt(),
    ));
  }
}
