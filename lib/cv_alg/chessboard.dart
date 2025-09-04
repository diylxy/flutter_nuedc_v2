// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:opencv_core/opencv.dart' as cv;

class CameraCalibrateResult {
  final cv.Mat mtx;
  final cv.Mat dist;
  CameraCalibrateResult({required this.mtx, required this.dist});

  CameraCalibrateResult copyWith({cv.Mat? mtx, cv.Mat? dist}) {
    return CameraCalibrateResult(mtx: mtx ?? this.mtx, dist: dist ?? this.dist);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'mtx': mtx.toList(), 'dist': dist.toList()};
  }

  factory CameraCalibrateResult.fromMap(Map<String, dynamic> map) {
    return CameraCalibrateResult(
      mtx: cv.Mat.from2DList(
        (map['mtx'] as List<dynamic>).map((e) => (e as List<dynamic>).map((v) => v as double).toList()).toList(),
        cv.MatType.CV_32FC1,
      ),
      dist: cv.Mat.from2DList(
        (map['dist'] as List<dynamic>).map((e) => (e as List<dynamic>).map((v) => v as double).toList()).toList(),
        cv.MatType.CV_32FC1,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory CameraCalibrateResult.fromJson(String source) =>
      CameraCalibrateResult.fromMap(
        json.decode(source) as Map<String, dynamic>,
      );

  @override
  String toString() => 'CameraCalibrateResult(mtx: $mtx, dist: $dist)';

  @override
  bool operator ==(covariant CameraCalibrateResult other) {
    if (identical(this, other)) return true;

    return other.mtx == mtx && other.dist == dist;
  }

  @override
  int get hashCode => mtx.hashCode ^ dist.hashCode;
}

class ChessboardCorrector {
  final (int, int) chessboardSize;
  final double chessboardWidth;
  final imageShape = [0, 0];

  late final List<cv.Point3f> chessboardPointsPattern;
  final List<List<cv.Point3f>> objPoints = [];
  final List<List<cv.Point2f>> imgPoints = [];
  int imageCount = 0;

  ChessboardCorrector({
    this.chessboardSize = (6, 8),
    this.chessboardWidth = 21.2,
  }) {
    final int cols = chessboardSize.$1;
    final int rows = chessboardSize.$2;
    chessboardPointsPattern = List.generate(
      rows * cols,
      (i) => cv.Point3f(
        i % cols * chessboardWidth,
        i ~/ cols * chessboardWidth,
        0,
      ),
    );
    imageCount = 0;
  }

  void reset() {
    imageCount = 0;
    objPoints.clear();
    imgPoints.clear();
  }

  Future<bool> feedImage(cv.Mat gray, cv.Mat raw) async {
    imageShape[0] = gray.width;
    imageShape[1] = gray.height;

    final cornersResult = await cv.findChessboardCornersAsync(
      gray,
      chessboardSize,
    );
    await cv.drawChessboardCornersAsync(
      raw,
      chessboardSize,
      cornersResult.$2,
      cornersResult.$1,
    );

    if (cornersResult.$1) {
      final corners = await cv.cornerSubPixAsync(
        gray,
        cornersResult.$2,
        const (11, 11),
        const (-1, -1),
        (cv.TERM_MAX_ITER + cv.TERM_EPS, 30, 0.001),
      );
      objPoints.add(chessboardPointsPattern);
      imgPoints.add(corners.toList());
      imageCount += 1;
    }
    return cornersResult.$1;
  }

  Future<CameraCalibrateResult?> calculateInnerParams() async {
    if (imageCount == 0) return null;
    final result = await cv.calibrateCameraAsync(
      cv.VecVecPoint3f.fromList(objPoints),
      cv.VecVecPoint2f.fromList(imgPoints),
      (imageShape[0], imageShape[1]),
      cv.Mat.empty(),
      cv.Mat.empty(),
    );
    // ret, mtx, dist
    /*
    I/flutter (13174): 199.11066931735735
    I/flutter (13174): [[23986.993097847037, 0.0, 1196.1959426228962], [0.0, 34772.885849378195, 2237.3877000093426], [0.0, 0.0, 1.0]]
    I/flutter (13174): [[268.48509756963483, -113938.15849769469, 1.4271931656953916, 0.2591205954191337, -33362.20367735409]]
    */
    return CameraCalibrateResult(mtx: result.$2, dist: result.$3);
  }
}
