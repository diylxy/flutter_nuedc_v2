import 'package:camera/camera.dart';
import 'package:flutter_nuedc_v2/controller/camera_manager.dart';
import 'package:flutter_nuedc_v2/controller/threed_controller.dart';
import 'package:flutter_nuedc_v2/controller/main_page_controller.dart';
import 'package:flutter_nuedc_v2/cv_alg/chessboard.dart';
import 'package:flutter_nuedc_v2/cv_alg/constants.dart';
import 'package:flutter_nuedc_v2/cv_alg/coord_utils.dart';
import 'package:flutter_nuedc_v2/cv_alg/paper_finder.dart';
import 'package:flutter_nuedc_v2/cv_alg/task_circles.dart';
import 'package:flutter_nuedc_v2/cv_alg/task_multi_rectangles.dart';
import 'package:flutter_nuedc_v2/cv_alg/task_triangles.dart';
import 'package:flutter_nuedc_v2/utils/image_utils.dart';
import 'package:flutter_nuedc_v2/utils/user_preference.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'package:opencv_core/opencv.dart' as cv;

class Local {
  static void hello() {
    MainPageController.to.pythonHello.value = true;
  }

  static void setChessboardCount(int count) {
    MainPageController.to.chessBoardCount.value = count;
  }

  static void setLinearErrorInfo(String value) {
    MainPageController.to.linearErrorInfo.value = value;
  }

  static void setCircularErrorInfo(String value) {
    MainPageController.to.circularErrorInfo.value = value;
  }

  static void message(String message) {
    Get.snackbar('Python', message);
  }

  static void update3D(List R, List rvec, List tvec) {
    // R 是 3x3 旋转矩阵，转换为四元数
    final quaternion = MainPageController.matrixToQuaternion([
      List<double>.from(R[0]),
      List<double>.from(R[1]),
      List<double>.from(R[2]),
    ]);

    // 沿y轴旋转180度
    // 180度绕y轴的四元数为 [0, 0, 1, 0] (w, x, y, z)
    // 四元数乘法: q' = q * q_y180
    final double qw = quaternion[0];
    final double qx = quaternion[1];
    final double qy = quaternion[2];
    final double qz = quaternion[3];

    // q_y180 = [0, 0, 1, 0]
    final double qw2 = 0;
    final double qx2 = 1;
    final double qy2 = 0;
    final double qz2 = 0;

    // 四元数乘法
    final double rw = qw * qw2 - qx * qx2 - qy * qy2 - qz * qz2;
    final double rx = qw * qx2 + qx * qw2 + qy * qz2 - qz * qy2;
    final double ry = qw * qy2 - qx * qz2 + qy * qw2 + qz * qx2;
    final double rz = qw * qz2 + qx * qy2 - qy * qx2 + qz * qw2;

    final rotatedQuaternion = [rw, rx, ry, rz];
    ThreedController.to.controller.setAnglesObject(
      w: -rotatedQuaternion[1],
      x: -rotatedQuaternion[0],
      y: rotatedQuaternion[2],
      z: -rotatedQuaternion[3],
    );
    // print(tvec);
    // print(rotatedQuaternion.toString());
    // debugPrint(tvec.toString());
  }

  static void updateMeasurement(
    int mode,
    double D,
    double x,
    double angle,
    double xangle,
  ) {
    MainPageController.to.currentMode = OneshotMode.fromInt(mode);
    MainPageController.to.distance.value = D;
    MainPageController.to.minSize.value = x;
    MainPageController.to.yAngle.value = angle;
    MainPageController.to.xAngle.value = xangle;
  }

  static void oneshotFailed() {
    MainPageController.to.currentMode = OneshotMode.any;
  }
}

PaperFinder paperFinder = PaperFinder();
TaskMultiRectangles taskMultiRectangles = TaskMultiRectangles();
int targetNumber = -1;

class Python {
  static void onInit() async {
    await Future.delayed(Duration(seconds: 1));
    UserPreferenceService.to.loadSettings();
    CameraManager.to.selectedCamera = 0;
    Local.hello();
  }

  static Future<(cv.Mat?, ClipPaperResult?)> _clipPaper() async {
    CameraCalibrateResult? calibData = UserPreferenceService.to.calibData;
    if (calibData == null) {
      Local.message('请先标定棋盘格');
      return (null, null);
    }
    if (CameraManager.to.cameraController == null) {
      Local.message('请先在设置中选择相机');
      return (null, null);
    }
    if (CameraManager.to.cameraController!.value.isTakingPicture) {
      Local.message('请等待上次测量完成');
      return (null, null);
    }
    final file = await CameraManager.to.cameraController!.takePicture();
    // final frame = await cv.imreadAsync(file.path);
    final rawFrame = await cv.imreadAsync(file.path);
    final frame = cv.undistort(rawFrame, calibData.mtx, calibData.dist);
    final gray = await cv.cvtColorAsync(frame, cv.COLOR_BGR2GRAY);
    return (
      frame,
      await paperFinder.clipPaper(
        gray,
        calibData,
        frame: frame,
        bwThresh: UserPreferenceService.to.bwThresholdPaper,
      ),
    );
  }

  static (double, CoordinateDesc) _getCalibratedD(
    CoordinateDesc coord, {
    bool useLinearCalibrator = true,
  }) {
    double D = 0.0;
    if (UserPreferenceService.to.coordBase != null) {
      coord = coord.of(UserPreferenceService.to.coordBase!);
      D = UserPreferenceService.to.worldOriginOffset;
    }
    D += coord.getDistanceZ();
    if (useLinearCalibrator) {
      D = UserPreferenceService.to.linearErrorCalibrator.correct(D);
      D += UserPreferenceService.to.circularErrorCalibrator.correct(
        coord.getYAngleDegree(),
      );
    }
    return (D, coord);
  }

  static Future<void> doClearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      dir.deleteSync(recursive: true);
      dir.createSync();
    } on MissingPlatformDirectoryException {
      Local.message("平台不支持此操作");
    }
  }

  static void worldOriginCalib(double value) async {
    final clipPaperResult = await _clipPaper();
    if (clipPaperResult.$2 != null) {
      final result = clipPaperResult.$2!;
      CoordinateDesc coord = result.coord;
      UserPreferenceService.to.coordBase = coord;
      UserPreferenceService.to.worldOriginOffset = value;
      Local.message('世界原点标定成功');
    } else {
      Local.message('世界原点标定失败：未找到目标物');
    }
  }

  static void chessBoardClear() {
    CameraManager.to.corrector.reset();
    Local.setChessboardCount(0);
  }

  static Future<void> chessBoardCapture() async {
    if (CameraManager.to.cameraController == null) return;
    if (CameraManager.to.cameraController!.value.isTakingPicture) {
      return;
    }
    final file = await CameraManager.to.cameraController!.takePicture();
    final mat = await cv.imreadAsync(file.path);
    final gray = await cv.cvtColorAsync(mat, cv.COLOR_BGR2GRAY);
    final success = await CameraManager.to.corrector.feedImage(gray, mat);
    CameraManager.to.opencvPreviewImage = await mat.toUiImage();
    Local.setChessboardCount(CameraManager.to.corrector.imageCount);
    if (!success) {
      Local.message("无法找到棋盘格");
    }
  }

  static Future<void> chessBoardCalculate() async {
    if (CameraManager.to.corrector.imageCount == 0) {
      Local.message('请先拍照');
      return;
    }
    UserPreferenceService.to.calibData = await CameraManager.to.corrector
        .calculateInnerParams();
    if (UserPreferenceService.to.calibData != null) {
      Local.message('棋盘格标定成功');
    } else {
      Local.message('棋盘格标定失败');
    }
  }

  static Future<void> linearCalibClear() async {
    UserPreferenceService.to.linearErrorCalibrator.clear();
  }

  static Future<void> linearCalib(double actualDist) async {
    final clipPaperResult = await _clipPaper();
    if (clipPaperResult.$2 != null) {
      final result = clipPaperResult.$2!;
      final (measuredDist, coord) = _getCalibratedD(
        result.coord,
        useLinearCalibrator: false,
      );
      if ((actualDist - measuredDist).abs() < 300) {
        UserPreferenceService.to.linearErrorCalibrator.addCalibrate(
          measuredDist,
          actualDist,
        );
        Local.message(
          "已记录：测量值${measuredDist.toStringAsFixed(1)} mm => 实际值${actualDist.toStringAsFixed(1)} mm",
        );
        Local.setLinearErrorInfo(
          "已记录：测量值${measuredDist.toStringAsFixed(1)} mm => 实际值${actualDist.toStringAsFixed(1)} mm",
        );
      }
    } else {
      Local.message("无法找到目标物");
    }
  }

  static Future<void> linearCalibCalculate() async {
    if (UserPreferenceService.to.linearErrorCalibrator.doCalibrate()) {
      Local.setLinearErrorInfo(
        "y = ${UserPreferenceService.to.linearErrorCalibrator.a?.toStringAsFixed(4)} * x + ${UserPreferenceService.to.linearErrorCalibrator.b?.toStringAsFixed(4)}",
      );
      Local.message('线性误差标定成功');
    } else {
      Local.message('线性误差标定失败');
    }
  }

  static Future<void> circularCalibClear() async {
    UserPreferenceService.to.linearErrorCalibrator.clear();
  }

  static Future<void> circularCalib(double actualDist) async {
    final clipPaperResult = await _clipPaper();
    if (clipPaperResult.$2 != null) {
      final result = clipPaperResult.$2!;

      double measuredDist = 0.0;
      CoordinateDesc coord = result.coord;
      if (UserPreferenceService.to.coordBase != null) {
        coord = coord.of(UserPreferenceService.to.coordBase!);
        measuredDist = UserPreferenceService.to.worldOriginOffset;
      }
      measuredDist += coord.getDistanceZ();
      measuredDist = UserPreferenceService.to.linearErrorCalibrator.correct(
        measuredDist,
      );

      double diff = actualDist - measuredDist;
      double angleY = coord.getYAngleDegree();
      if (diff.abs() < 100) {
        UserPreferenceService.to.circularErrorCalibrator.addCalibrate(
          angleY,
          diff,
        );
        Local.message(
          "已记录：测量角度${angleY.toStringAsFixed(1)} 度 => 误差${diff.toStringAsFixed(1)} mm",
        );
        Local.setCircularErrorInfo(
          "已记录：测量角度${angleY.toStringAsFixed(1)} 度 => 误差${diff.toStringAsFixed(1)} mm",
        );
      }
    } else {
      Local.message("无法找到目标物");
    }
  }

  static Future<void> circularCalibCalculate() async {
    if (UserPreferenceService.to.circularErrorCalibrator.doCalibrate()) {
      Local.setLinearErrorInfo(
        "y = ${UserPreferenceService.to.circularErrorCalibrator.a?.toStringAsFixed(4)} * x + ${UserPreferenceService.to.circularErrorCalibrator.b?.toStringAsFixed(4)}",
      );
      Local.message('旋转误差标定成功');
    } else {
      Local.message('旋转误差标定失败');
    }
  }

  // 不支持
  static Future<void> enterExitLowpower(bool enter) async {}

  // Canny调参模式
  static void _streamCBCanny(CameraImage image) async {
    final frame = await image.toCVGray(
      controller: CameraManager.to.cameraController,
    );
    await cv.cannyAsync(
      frame,
      UserPreferenceService.to.cannyLow.toDouble(),
      UserPreferenceService.to.cannyHigh.toDouble(),
      apertureSize: 3,
      edges: frame,
    );
    CameraManager.to.opencvPreviewImage = await frame.toUiImage();
  }

  // 黑白调参模式
  static void _streamCBBW(CameraImage image) async {
    final frame = await image.toCVGray(
      controller: CameraManager.to.cameraController,
    );
    await cv.thresholdAsync(
      frame,
      UserPreferenceService.to.bwThresholdPaper.toDouble(),
      255,
      cv.THRESH_BINARY,
      dst: frame,
    );
    CameraManager.to.opencvPreviewImage = await frame.toUiImage();
  }

  static void _streamCBRealtime(CameraImage image) async {
    final frame = await image.toCVGray(
      controller: CameraManager.to.cameraController,
    );
    CameraCalibrateResult calibDataDummy = CameraCalibrateResult(
      mtx: cv.Mat.from2DList([
        [800.0, 0.0, frame.width / 2],
        [0.0, 800.0, frame.height / 2],
        [0.0, 0.0, 1.0],
      ], cv.MatType.CV_64FC1),
      dist: cv.Mat.zeros(1, 5, cv.MatType.CV_64FC1),
      width: frame.width,
      height: frame.height,
    );
    final clipResult = await paperFinder.clipPaper(
      frame,
      calibDataDummy,
      cannyLow: UserPreferenceService.to.cannyLow,
      cannyHigh: UserPreferenceService.to.cannyHigh,
      bwThresh: UserPreferenceService.to.bwThresholdPaper,
      weak: true,
    );
    if (clipResult != null) {
      CameraManager.to.opencvPreviewImage = await clipResult.clipped
          .toUiImage();
    } else {
      CameraManager.to.opencvPreviewImage = await frame.toUiImage();
    }
  }

  static void _streamCB3D(CameraImage image) async {
    final frame = await image.toCVGray(
      controller: CameraManager.to.cameraController,
    );
    double f = 800.0;
    if (UserPreferenceService.to.calibData != null) {
      f =
          UserPreferenceService.to.calibData!.mtx.at<double>(0, 0) *
          (frame.height / UserPreferenceService.to.calibData!.height);
    }
    final cx = frame.width / 2;
    final cy = frame.height / 2;
    CameraCalibrateResult calibDataDummy = CameraCalibrateResult(
      mtx: cv.Mat.from2DList([
        [f, 0.0, cx],
        [0.0, f, cy],
        [0.0, 0.0, 1.0],
      ], cv.MatType.CV_64FC1),
      dist: cv.Mat.zeros(1, 5, cv.MatType.CV_64FC1),
      width: frame.width,
      height: frame.height,
    );
    final clipResult = await paperFinder.clipPaper(
      frame,
      calibDataDummy,
      cannyLow: UserPreferenceService.to.cannyLow,
      cannyHigh: UserPreferenceService.to.cannyHigh,
      bwThresh: UserPreferenceService.to.bwThresholdPaper,
      weak: true,
    );
    if (clipResult != null) {
      CoordinateDesc coord = clipResult.coord;
      if (UserPreferenceService.to.coordBase != null) {
        coord = coord.of(UserPreferenceService.to.coordBase!);
      }
      Local.update3D(
        coord.R.toList(),
        coord.rvec.toList(),
        coord.tvec.toList(),
      );
    }
  }

  static Future<void> enter3D() async {
    await CameraManager.to.reinitialize(lowQuality: true);
    await CameraManager.to.setImageStreamCB(_streamCB3D);
  }

  static Future<void> leave3D() async {
    await CameraManager.to.reinitialize(lowQuality: false);
    await CameraManager.to.setImageStreamCB(null);
  }

  static Future<void> realtimeMeasuremode(bool enable) async {
    if (enable) {
      await CameraManager.to.reinitialize(lowQuality: true);
      await CameraManager.to.setImageStreamCB(_streamCBRealtime);
    } else {
      await CameraManager.to.reinitialize(lowQuality: false);
      await CameraManager.to.setImageStreamCB(null);
    }
  }

  static Future<void> bwMode(bool enable) async {
    if (enable) {
      await CameraManager.to.reinitialize(lowQuality: true);
      await CameraManager.to.setImageStreamCB(_streamCBBW);
    } else {
      await CameraManager.to.reinitialize(lowQuality: false);
      await CameraManager.to.setImageStreamCB(null);
    }
  }

  static Future<void> cannyMode(bool enable) async {
    if (enable) {
      await CameraManager.to.reinitialize(lowQuality: true);
      await CameraManager.to.setImageStreamCB(_streamCBCanny);
    } else {
      await CameraManager.to.reinitialize(lowQuality: false);
      await CameraManager.to.setImageStreamCB(null);
    }
  }

  // 设置边框阈值
  static Future<void> bwParam1(int param) async {
    if (param < 0) param = 0;
    if (param > 255) param = 255;
    UserPreferenceService.to.bwThresholdPaper = param;
  }

  // 设置测量阈值
  static Future<void> bwParam2(int param) async {
    if (param < 0) param = 0;
    if (param > 255) param = 255;
    UserPreferenceService.to.bwThresholdRect = param;
  }

  static Future<void> cannyParamHigh(int param) async {
    UserPreferenceService.to.cannyHigh = param;
  }

  static Future<void> cannyParamLow(int param) async {
    UserPreferenceService.to.cannyLow = param;
  }

  static Future<void> setCurrentRectID(int id) async {
    targetNumber = id;
  }

  static Future<void> oneshotMeasurement() async {
    final (frame, result) = await _clipPaper();
    if (result != null) {
      // 计算距离和旋转信息
      CoordinateDesc coord = result.coord;
      double D = 0.0; // 到平面的Z距离
      double angle = 0.0; // 轴线角（y角）
      double xangle = 0.0; // 前倾角（x角）
      (D, coord) = _getCalibratedD(coord);
      angle = coord.getYAngleDegree();
      xangle = coord.getXAngleDegree();
      // 尝试测量
      bool found = false;
      final clippedBGR = cv.cvtColor(result.clipped, cv.COLOR_GRAY2BGR);
      final (_, clippedBW) = await cv.thresholdAsync(
        result.clipped,
        UserPreferenceService.to.bwThresholdRect.toDouble(),
        255,
        cv.THRESH_BINARY,
      );
      final (clippedContour, _) = await cv.findContoursAsync(
        clippedBW,
        cv.RETR_LIST,
        cv.CHAIN_APPROX_SIMPLE,
      );

      // 查找圆形
      final circleRes = TaskCircles.getCircleRadius(clippedContour, clippedBW);
      if (circleRes != null) {
        // 在clippedBGR中画出圆形
        await cv.circleAsync(
          clippedBGR,
          cv.Point(circleRes.center.x.toInt(), circleRes.center.y.toInt()),
          (circleRes.radius * paperScaleFactor).toInt(),
          cv.Scalar(255, 0, 0),
          thickness: 2,
        );
        Local.updateMeasurement(
          OneshotMode.circle.value,
          D,
          circleRes.radius,
          angle,
          xangle,
        );
        found = true;
      }
      // 查找三角形
      final triangleRes = TaskTriangles.getTriangleSize(
        clippedContour,
        result.clipped,
      );
      if (triangleRes != null) {
        // 在clippedBGR中画出三角形
        await cv.polylinesAsync(
          clippedBGR,
          cv.VecVecPoint.fromList([
            triangleRes.approx
                .map((e) => cv.Point(e.x.toInt(), e.y.toInt()))
                .toList(),
          ]),
          true,
          cv.Scalar(0, 0, 255),
          thickness: 2,
        );
        final text = '${triangleRes.width.toStringAsFixed(2)} mm';
        await cv.putTextAsync(
          clippedBGR,
          text,
          cv.Point(triangleRes.center.x.toInt(), triangleRes.center.y.toInt()),
          cv.FONT_HERSHEY_SIMPLEX,
          1.0,
          cv.Scalar(255, 255, 255),
          thickness: 2,
        );
        Local.updateMeasurement(
          OneshotMode.triangle.value,
          D,
          triangleRes.width,
          angle,
          xangle,
        );
        found = true;
      }
      final rectangles = await taskMultiRectangles.getRectangles(
        result.clipped,
        clippedContour,
        clippedBGR: clippedBGR,
      );
      if (rectangles.isNotEmpty) {
        await cv.polylinesAsync(
          clippedBGR,
          cv.VecVecPoint.fromList(
            rectangles
                .map(
                  (e) =>
                      e.map((e) => cv.Point(e.x.toInt(), e.y.toInt())).toList(),
                )
                .toList(),
          ),
          true,
          cv.Scalar(0, 255, 0),
          thickness: 2,
        );
        final rectangleWithNumber = await taskMultiRectangles
            .getRectangleSizeAndClipInnerWhiteNumbers(
              rectangles,
              result.clipped,
              clippedBW,
            );
        double minx = double.maxFinite;
        for (var rectWithNum in rectangleWithNumber) {
          final center = rectWithNum.center;
          final number = rectWithNum.number;
          final size = (rectWithNum.size * paperScaleBackFactor);
          final sizeStr = size.toStringAsFixed(2);
          final text = '[$number] $sizeStr mm';
          await cv.putTextAsync(
            clippedBGR,
            text,
            cv.Point(center.x.toInt(), center.y.toInt()),
            cv.FONT_HERSHEY_SIMPLEX,
            1.0,
            cv.Scalar(0, 0, 255),
            thickness: 2,
          );
          if (targetNumber >= 0) {
            // 数字识别模式
            if (rectWithNum.number == targetNumber) {
              Local.updateMeasurement(
                OneshotMode.rectangleIndexed.value,
                D,
                size,
                angle,
                xangle,
              );
              found = true;
            }
          }
          if (minx > size) {
            minx = size;
          }
        }
        if (minx < double.maxFinite && found == false) {
          Local.updateMeasurement(
            OneshotMode.rectangle.value,
            D,
            minx,
            angle,
            xangle,
          );
          found = true;
        }
      }
      if (found == false) {
        Local.message("无法找到目标物");
        Local.oneshotFailed();
      }
      CameraManager.to.opencvPreviewImage = await clippedBGR.toUiImage();
    } else {
      CameraManager.to.opencvPreviewImage = await frame?.toUiImage();
      Local.message("无法找到目标物");
      Local.oneshotFailed();
    }
  }

  // 不支持
  static Future<void> focusMode(bool enable) async {}

  // 这个实际没用上
  static Future<void> setNumberRecMode(bool mode) async {}

  static Future<void> saveResult() async {
    UserPreferenceService.to.saveSettings();
  }

  static Future<void> loadResult() async {
    UserPreferenceService.to.loadSettings();
  }

  static Future<void> loadFactoryResult() async {
    UserPreferenceService.to.factoryDefault();
  }

  // 不支持
  static Future<void> reboot() async {}
}
