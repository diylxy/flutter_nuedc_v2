import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:flutter_nuedc_v2/controller/camera_manager.dart';
import 'package:flutter_nuedc_v2/cv_alg/chessboard.dart';
import 'package:flutter_nuedc_v2/cv_alg/paper_finder.dart';
import 'package:flutter_nuedc_v2/cv_alg/task_circles.dart';
import 'package:flutter_nuedc_v2/cv_alg/task_multi_rectangles.dart';
import 'package:flutter_nuedc_v2/main.dart';
import 'package:flutter_nuedc_v2/utils.dart';

import 'package:opencv_core/opencv.dart' as cv;
import 'package:path_provider/path_provider.dart';

CameraCalibrateResult? calibData;
TaskMultiRectangles taskMultiRectangles = TaskMultiRectangles();

class NUEDCController {
  // static CVOperationController get to => Get.find<CVOperationController>();
  static Future<void> doCNN() async {
    ByteData data = await rootBundle.load("assets/test.png");
    cv.Mat mat = await cv.imdecodeAsync(data.buffer.asUint8List(), 0);
    await cv.resizeAsync(mat, (24, 24), dst: mat);
    print(await CameraManager.to.recognizer.inference(mat));
    data = await rootBundle.load("assets/simhei_7_0_1.png");
    mat = await cv.imdecodeAsync(data.buffer.asUint8List(), 0);
    await cv.resizeAsync(mat, (24, 24), dst: mat);
    print(await CameraManager.to.recognizer.inference(mat));
  }

  static Future<void> doClearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      dir.deleteSync(recursive: true);
      dir.createSync();
    } on MissingPlatformDirectoryException {
      debugPrint("Unsupported");
    }
  }

  static Future<void> doOneShotCalib() async {
    if (CameraManager.to.cameraController == null) return;
    if (CameraManager.to.cameraController!.value.isTakingPicture) {
      return;
    }
    final file = await CameraManager.to.cameraController!.takePicture();
    final mat = await cv.imreadAsync(file.path);
    final gray = await cv.cvtColorAsync(mat, cv.COLOR_BGR2GRAY);
    await CameraManager.to.corrector.feedImage(gray, mat);
    CameraManager.to.opencvPreviewImage = await mat.toUiImage();
  }

  static Future<void> doCalibCalculate() async {
    if (CameraManager.to.corrector.imageCount == 0) {
      showInSnackBar('请先标定');
      return;
    }
    calibData = await CameraManager.to.corrector.calculateInnerParams();
  }

  static Future<void> doOneShot() async {
    if (calibData == null) {
      showInSnackBar('请先标定');
      return;
    }
    if (CameraManager.to.cameraController == null) return;
    if (CameraManager.to.cameraController!.value.isTakingPicture) {
      return;
    }
    final file = await CameraManager.to.cameraController!.takePicture();
    final rawFrame = await cv.imreadAsync(file.path);
    final frame = cv.undistort(rawFrame, calibData!.mtx, calibData!.dist);
    final gray = await cv.cvtColorAsync(frame, cv.COLOR_BGR2GRAY);
    final result = await PaperFinder().clipPaper(
      gray,
      calibData!.mtx,
      calibData!.dist,
      frame: frame,
    );
    if (result != null) {
      print('找到A4纸位置!');
      final clippedBGR = cv.cvtColor(result.clipped, cv.COLOR_GRAY2BGR);
      final clippedBW = await cv.thresholdAsync(
        result.clipped,
        127,
        255,
        cv.THRESH_BINARY,
      );
      final clippedContour = await cv.findContoursAsync(
        clippedBW.$2,
        cv.RETR_LIST,
        cv.CHAIN_APPROX_SIMPLE,
      );
      // final circleRes = TaskCircles.getCircleRadius(
      //   contourResult.$1,
      //   bwResult.$2,
      // );
      // print(circleRes);
      final rectangles = await taskMultiRectangles.getRectangles(
        result.clipped,
        clippedContour.$1,
        clippedBGR: clippedBGR,
      );
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
            clippedBW.$2,
          );
      for (var rectWithNum in rectangleWithNumber) {
        final center = rectWithNum.center;
        final number = rectWithNum.number.toString();
        await cv.putTextAsync(
          clippedBGR,
          number,
          cv.Point(center.x.toInt(), center.y.toInt()),
          cv.FONT_HERSHEY_SIMPLEX,
          1.0,
          cv.Scalar(0, 0, 255),
          thickness: 2,
        );
      }
      CameraManager.to.opencvPreviewImage = await clippedBGR.toUiImage();
    } else {
      CameraManager.to.opencvPreviewImage = await frame.toUiImage();
    }
  }
}
