import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nuedc_v2/cv_alg/chessboard.dart';
import 'package:flutter_nuedc_v2/cv_alg/digit_recognizer_cnn.dart';
import 'package:flutter_nuedc_v2/main.dart';
import 'package:get/get.dart';

class CameraManager extends GetxController {
  ChessboardCorrector corrector = ChessboardCorrector();
  DigitRecognizerCnn recognizer = DigitRecognizerCnn();
  static CameraManager get to => Get.find<CameraManager>();

  @override
  void onInit() {
    super.onInit();
    fetchCameras();
    recognizer.init();
  }

  @override
  void onClose() {
    super.onClose();
    recognizer.dispose();
  }

  final Rx<ui.Image?> _opencvPreviewImage = Rx<ui.Image?>(null);
  ui.Image? get opencvPreviewImage => _opencvPreviewImage.value;
  set opencvPreviewImage(ui.Image? image) => _opencvPreviewImage.value = image;

  final Rx<CameraController?> _controller = Rx<CameraController?>(null);

  Future<void> initializeCameraController(
    CameraDescription cameraDescription,
  ) async {
    final CameraController cameraController = CameraController(
      cameraDescription,
      _lowQuality ? ResolutionPreset.medium : ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (cameraController.value.hasError) {
        showInSnackBar(
          'Camera error ${cameraController.value.errorDescription}',
        );
      }
    });

    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          showInSnackBar('You have denied camera access.');
        case 'AudioAccessDenied':
          showInSnackBar('You have denied audio access.');
        default:
          _showCameraException(e);
          break;
      }
    }
    _controller.value = cameraController;
    await _startImageStream();
  }

  void _showCameraException(CameraException e) {
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }

  CameraController? get cameraController => _controller.value;
  CameraDescription? get description => cameraController?.description;

  Future<void> stop() async {
    if (cameraController == null || !cameraController!.value.isInitialized) {
      return;
    }
    _stopImageStream();
    await cameraController!.pausePreview();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await cameraController!.dispose();
      _controller.value = null;
    });
    _selectedCamera.value = -1;
  }

  bool _canStream = false;

  Future<void> _stopImageStream() async {
    if (cameraController!.value.isStreamingImages) {
      await cameraController!.stopImageStream();
      _canStream = false;
    }
  }

  Future<void> _startImageStream() async {
    _canStream = true;
    if (_imageStreamCB != null) {
      await cameraController!.startImageStream(_imageStreamCB!);
    }
  }

  Function(CameraImage image)? _imageStreamCB;

  Future<void> setImageStreamCB(void Function(CameraImage image)? cb) async {
    _imageStreamCB = cb;
    if (_canStream) {
      if (cameraController != null) {
        if (cameraController!.value.isStreamingImages) {
          await cameraController!.stopImageStream();
        }
        if (cb != null) {
          await cameraController!.startImageStream(cb);
        }
      }
    }
  }

  Future<void> onNewCameraSelected(CameraDescription cameraDescription) async {
    if (cameraController != null) {
      await _stopImageStream();
      await cameraController!.pausePreview();
      await cameraController!.setDescription(cameraDescription);
      await cameraController!.resumePreview();
      await _startImageStream();
    } else {
      return initializeCameraController(cameraDescription);
    }
  }

  void onSetFocusPoint(Offset offset) {
    cameraController?.setExposurePoint(offset);
    cameraController?.setFocusPoint(offset);
  }

  final _cameras = Rx<List<CameraDescription>>([]);
  List<CameraDescription> get cameras => _cameras.value;
  final _selectedCamera = (-1).obs;
  int get selectedCamera => _selectedCamera.value;
  set selectedCamera(int val) {
    if (val >= _cameras.value.length || val < 0) return;
    _selectedCamera.value = val;
    onNewCameraSelected(_cameras.value[val]);
  }

  bool _lowQuality = false;
  Future<void> reinitialize({bool lowQuality = false}) async {
    int currentCameraId = _selectedCamera.value;
    _lowQuality = lowQuality;
    await stop();
    await Future.delayed(Duration(milliseconds: 200));
    selectedCamera = currentCameraId;
  }

  Future<void> fetchCameras() async {
    // Fetch the available cameras before initializing the app.
    try {
      _cameras.value = await availableCameras();
    } on CameraException catch (e) {
      debugPrint(
        'Error: ${e.code}${e.description == null ? '' : '\nError Message: ${e.description}'}',
      );
    }
  }
}
