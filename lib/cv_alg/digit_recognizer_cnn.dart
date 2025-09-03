import 'dart:typed_data';
import 'package:opencv_core/opencv.dart' as cv;
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class DigitRecognizerCnn {
  late OrtSession _session;
  Future<void> init() async {
    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    const assetFileName =
        'assets/models/digit_cnn_gray_24x24_0-9_mixed_best_1.onnx';
    final rawAssetFile = await rootBundle.load(assetFileName);
    final bytes = rawAssetFile.buffer.asUint8List();
    _session = OrtSession.fromBuffer(bytes, sessionOptions);
  }

  // mat为灰度或二值图，24*24像素
  Future<int> inference(cv.Mat mat) async {
    final flatList = mat
        .toList()
        .expand((row) => row.map((e) => e > 128 ? 1.0 : 0.0))
        .toList();
    final Float32List data = Float32List.fromList(flatList);
    final shape = [1, 1, 24, 24]; // [1, 1, H, W]
    final inputOrt = OrtValueTensor.createTensorWithDataList(data, shape);
    final inputs = {'input': inputOrt};
    final runOptions = OrtRunOptions();
    final outputs = await _session.runAsync(runOptions, inputs);
    inputOrt.release();
    runOptions.release();
    if (outputs != null) {
      List<double> value = (((outputs[0]!.value! as List)[0]) as List<double>);
      int maxIndex = 0;
      double maxValue = value[0];
      for (int i = 1; i < value.length; i++) {
        if (value[i] > maxValue) {
          maxValue = value[i];
          maxIndex = i;
        }
      }
      return maxIndex;
    }
    return -1;
  }

  void dispose() {
    OrtEnv.instance.release();
  }
}
