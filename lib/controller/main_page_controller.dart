import 'package:flutter_nuedc_v2/python_wrapper.dart';
import 'package:get/get.dart';
import 'dart:math';

enum OneshotMode {
  any,
  triangle,
  circle,
  rectangle,
  rectangleIndexed,
  measuring;

  // 将枚举转换为int
  int get value => index;

  // 通过int获取枚举
  static OneshotMode fromInt(int i) {
    return OneshotMode.values[i];
  }

  @override
  String toString() {
    switch (this) {
      case OneshotMode.any:
        return '无';
      case OneshotMode.triangle:
        return '三角形';
      case OneshotMode.circle:
        return '圆形';
      case OneshotMode.rectangle:
        return '最小矩形';
      case OneshotMode.rectangleIndexed:
        return '指定序号矩形';
      case OneshotMode.measuring:
        return '正在测量...';
    }
  }
}

class MainPageController extends GetxController {
  static MainPageController get to => Get.find<MainPageController>();

  static List<double> matrixToQuaternion(List<List<double>> R) {
    double m00 = R[0][0], m01 = R[0][1], m02 = R[0][2];
    double m10 = R[1][0], m11 = R[1][1], m12 = R[1][2];
    double m20 = R[2][0], m21 = R[2][1], m22 = R[2][2];

    double tr = m00 + m11 + m22;
    double qw, qx, qy, qz;

    if (tr > 0) {
      double S = sqrt(tr + 1.0) * 2; // S=4*qw
      qw = 0.25 * S;
      qx = (m21 - m12) / S;
      qy = (m02 - m20) / S;
      qz = (m10 - m01) / S;
    } else if ((m00 > m11) & (m00 > m22)) {
      double S = sqrt(1.0 + m00 - m11 - m22) * 2; // S=4*qx
      qw = (m21 - m12) / S;
      qx = 0.25 * S;
      qy = (m01 + m10) / S;
      qz = (m02 + m20) / S;
    } else if (m11 > m22) {
      double S = sqrt(1.0 + m11 - m00 - m22) * 2; // S=4*qy
      qw = (m02 - m20) / S;
      qx = (m01 + m10) / S;
      qy = 0.25 * S;
      qz = (m12 + m21) / S;
    } else {
      double S = sqrt(1.0 + m22 - m00 - m11) * 2; // S=4*qz
      qw = (m10 - m01) / S;
      qx = (m02 + m20) / S;
      qy = (m12 + m21) / S;
      qz = 0.25 * S;
    }
    return [qw, qx, qy, qz];
  }

  final pythonHello = false.obs;

  final chessBoardCount = 0.obs;
  final _lowPowerMode = false.obs;
  bool get lowPowerMode => _lowPowerMode.value;
  set lowPowerMode(bool enable) {
    _lowPowerMode.value = enable;
    Python.enterExitLowpower(enable);
  }

  final _realtimeMeasurement = false.obs;
  bool get realtimeMeasurement => _realtimeMeasurement.value;
  set realtimeMeasurement(bool enable) {
    _realtimeMeasurement.value = enable;
    Python.realtimeMeasuremode(enable);
  }

  final _cannyMode = false.obs;
  bool get cannyMode => _cannyMode.value;
  set cannyMode(bool enable) {
    _cannyMode.value = enable;
    Python.cannyMode(enable);
  }

  final _cannyLow = 60.0.obs;
  double get cannyLow => _cannyLow.value;
  set cannyLow(double value) {
    _cannyLow.value = value;
    Python.cannyParam1(value.toInt());
  }

  final _cannyHigh = 127.0.obs;
  double get cannyHigh => _cannyHigh.value;
  set cannyHigh(double value) {
    _cannyHigh.value = value;
    Python.cannyParam2(value.toInt());
  }

  final _focusMode = false.obs;
  bool get focusMode => _focusMode.value;
  set focusMode(bool enable) {
    _focusMode.value = enable;
    Python.focusMode(enable);
  }

  final _currentRectID = (-1).obs;
  int get currentRectID => _currentRectID.value;
  set currentRectID(int id) {
    _currentRectID.value = id;
    Python.setCurrentRectID(id);
  }

  final _numberRecMode = false.obs;
  bool get numberRecMode => _numberRecMode.value;
  set numberRecMode(bool mode) {
    _numberRecMode.value = mode;
    Python.setNumberRecMode(mode);
  }

  final distance = 0.0.obs;
  final minSize = 0.0.obs;
  final xAngle = 0.0.obs;
  final yAngle = 0.0.obs;
  final loading = false.obs;
  final _currentMode = OneshotMode.any.obs;
  OneshotMode get currentMode => _currentMode.value;
  DateTime lastmeasureingTime = DateTime(0);
  set currentMode(OneshotMode mode) {
    _currentMode.value = mode;
    lastmeasureingTime = DateTime.now();
    if (mode == OneshotMode.measuring) {
      loading.value = true;
      Future.delayed(const Duration(seconds: 5), () {
        if (_currentMode.value == OneshotMode.measuring) {
          if (DateTime.now().difference(lastmeasureingTime) >
              const Duration(seconds: 4)) {
            loading.value = false;
          }
        }
      });
    } else {
      loading.value = false;
      currentRectID = -1;
    }
  }

  final linearErrorInfo = '未应用'.obs;
  final circularErrorInfo = '未应用'.obs;
}
