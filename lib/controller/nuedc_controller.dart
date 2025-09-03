import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nuedc_v2/controller/camera_manager.dart';
import 'package:flutter_nuedc_v2/utils.dart';
// import 'package:get/get.dart';

import 'package:opencv_core/opencv.dart' as cv;
import 'package:path_provider/path_provider.dart';

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

  static Future<void> doOneShot() async {
    if (CameraManager.to.cameraController == null) return;
    if (CameraManager.to.cameraController!.value.isTakingPicture) {
      return;
    }
    final file = await CameraManager.to.cameraController!.takePicture();
    final mat = await cv.imreadAsync(file.path);
    final gray = await cv.cvtColorAsync(mat, cv.COLOR_BGR2GRAY);
    final found = await CameraManager.to.corrector.feedImage(gray, mat);
    if (found) {
      final _ = await CameraManager.to.corrector.calculateInnerParams();
    }
    CameraManager.to.opencvPreviewImage = await mat.toUiImage();
  }
}
