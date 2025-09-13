import 'dart:convert';

import 'package:flutter_nuedc_v2/cv_alg/chessboard.dart';
import 'package:flutter_nuedc_v2/cv_alg/coord_utils.dart';
import 'package:flutter_nuedc_v2/cv_alg/linear_corrector.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_nuedc_v2/controller/main_page_controller.dart';

class UserPreferenceService {
  static UserPreferenceService get to => Get.find<UserPreferenceService>();

  static const int version = 1;

  CameraCalibrateResult? calibData; // 相机标定数据
  CoordinateDesc? coordBase; // 世界原点坐标信息
  double worldOriginOffset = 1250.0; // 世界原点Z坐标，单位毫米
  int cannyLow = 200; // 纸边框检测-Canny模式低阈值
  int cannyHigh = 500; // 纸边框检测-Canny模式高阈值
  int bwThresholdPaper = 60; // 纸边框检测黑白模式阈值
  int bwThresholdRect = 127; // 矩形检测阈值
  LinearCorrector linearErrorCalibrator = LinearCorrector(); // 线性标定结果
  LinearCorrector circularErrorCalibrator = LinearCorrector(); // 旋转标定结果
  double chessboardWidth = 21.2;

  // 从字符串导入用户设置
  bool loadsSettings(String buffer) {
    try {
      final settingsMap = jsonDecode(buffer);
      if (settingsMap['calibData'] != null) {
        calibData = CameraCalibrateResult.fromMap(settingsMap['calibData']);
      }
      if (settingsMap['coordBase'] != null) {
        coordBase = CoordinateDesc.fromMap(settingsMap['coordBase']);
      }
      if (settingsMap['worldOriginOffset'] != null) {
        worldOriginOffset = settingsMap['worldOriginOffset'];
      }
      if (settingsMap['cannyLow'] != null) {
        cannyLow = settingsMap['cannyLow'];
      }
      if (settingsMap['cannyHigh'] != null) {
        cannyHigh = settingsMap['cannyHigh'];
      }
      if (settingsMap['bwThresholdPaper'] != null) {
        bwThresholdPaper = settingsMap['bwThresholdPaper'];
      }
      if (settingsMap['bwThresholdRect'] != null) {
        bwThresholdRect = settingsMap['bwThresholdRect'];
      }
      if (settingsMap['linearErrorCalibrator'] != null) {
        linearErrorCalibrator.loadResult(
          settingsMap['linearErrorCalibrator'] as Map<String, dynamic>,
        );
      }
      if (settingsMap['circularErrorCalibrator'] != null) {
        circularErrorCalibrator.loadResult(
          settingsMap['circularErrorCalibrator'] as Map<String, dynamic>,
        );
      }
      if (settingsMap['chessboardWidth'] != null) {
        chessboardWidth = settingsMap['chessboardWidth'];
      }
      return true;
    } on FormatException {
      return false;
    }
  }

  /// 导出用户设置到字符串
  String dumpSettings() {
    final settingsMap = <String, dynamic>{};
    settingsMap['version'] = version;
    settingsMap['calibData'] = calibData?.toMap();
    settingsMap['coordBase'] = coordBase?.toMap();
    settingsMap['worldOriginOffset'] = worldOriginOffset;
    settingsMap['cannyLow'] = cannyLow;
    settingsMap['cannyHigh'] = cannyHigh;
    settingsMap['bwThresholdPaper'] = bwThresholdPaper;
    settingsMap['bwThresholdRect'] = bwThresholdRect;
    settingsMap['linearErrorCalibrator'] = linearErrorCalibrator.dumpResult();
    settingsMap['circularErrorCalibrator'] = circularErrorCalibrator
        .dumpResult();
    settingsMap['chessboardWidth'] = chessboardWidth;
    return jsonEncode(settingsMap);
  }

  Future<void> loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final calibData = prefs.getString('calib');
    if (calibData != null) {
      loadsSettings(calibData);
      MainPageController.to.cannyHigh = cannyHigh.toDouble();
      MainPageController.to.cannyLow = cannyLow.toDouble();
      MainPageController.to.bwThresholdPaper = bwThresholdPaper.toDouble();
      MainPageController.to.bwThresholdRect = bwThresholdRect.toDouble();
      MainPageController.to.chessboardWidth = chessboardWidth;
    }
  }

  Future<void> saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('calib', dumpSettings());
  }

  void factoryDefault() async {}
}
