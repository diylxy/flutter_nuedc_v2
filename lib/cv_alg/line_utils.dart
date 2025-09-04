import 'package:opencv_core/opencv.dart' as cv;

class LineUtils {
  /// 计算两直线的交点，输入为两条直线的端点 [a1, a2], [b1, b2]，每个点为 [x, y]。
  /// 返回交点 [x, y]，如果无交点则返回 null。
  static cv.Point2f? lineIntersection(
    cv.Point2f a1,
    cv.Point2f a2,
    cv.Point2f b1,
    cv.Point2f b2,
  ) {
    // 构造齐次坐标
    List<cv.Point2f> s = [a1, a2, b1, b2];
    List<List<double>> h = s
        .map((p) => [p.x, p.y, 1.0])
        .toList(); // 每个点加上齐次分量

    // 计算两条直线的齐次表达
    List<double> l1 = [
      h[0][1] * h[1][2] - h[0][2] * h[1][1],
      h[0][2] * h[1][0] - h[0][0] * h[1][2],
      h[0][0] * h[1][1] - h[0][1] * h[1][0],
    ];
    List<double> l2 = [
      h[2][1] * h[3][2] - h[2][2] * h[3][1],
      h[2][2] * h[3][0] - h[2][0] * h[3][2],
      h[2][0] * h[3][1] - h[2][1] * h[3][0],
    ];

    // 两直线的交点（齐次坐标）
    List<double> p = [
      l1[1] * l2[2] - l1[2] * l2[1],
      l1[2] * l2[0] - l1[0] * l2[2],
      l1[0] * l2[1] - l1[1] * l2[0],
    ];

    if (p[2].abs() < 1e-8) {
      return null; // 平行或重合，无交点
    }
    return cv.Point2f(p[0] / p[2], p[1] / p[2]);
  }

  /// 计算两条射线的交点（如果存在），否则返回 null。
  /// a1, a2: 第一条射线的起点和方向上的另一点
  /// b1, b2: 第二条射线的起点和方向上的另一点
  static cv.Point2f? rayIntersection(
    cv.Point2f a1,
    cv.Point2f a2,
    cv.Point2f b1,
    cv.Point2f b2,
  ) {
    final pt = lineIntersection(a1, a2, b1, b2);
    if (pt == null) return null;

    final da = [a2.x - a1.x, a2.y - a1.y];
    final db = [b2.x - b1.x, b2.y - b1.y];

    double dotA = (pt.x - a1.x) * da[0] + (pt.y - a1.y) * da[1];
    double dotB = (pt.x - b1.x) * db[0] + (pt.y - b1.y) * db[1];

    if (dotA < 0 || dotB < 0) return null;
    return pt;
  }

  /// 计算两条直线的夹角（忽略方向），输入角度范围为[-180, 180]。
  /// 返回夹角范围为[0, 90]。
  static double angleBetweenLines(double angle1, double angle2) {
    double diff = (angle1 - angle2).abs();
    diff = diff % 180;
    if (diff > 90) diff = 180 - diff;
    return diff;
  }
}
