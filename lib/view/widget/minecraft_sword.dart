import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';
import 'package:flutter_nuedc_v2/python_wrapper.dart';

class MinecraftSword3D extends StatelessWidget {
  final ThreeDModelController controller;
  final double width;
  final double height;

  const MinecraftSword3D({
    super.key,
    required this.controller,
    this.width = 400,
    this.height = 300,
  });
  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          controller.onSceneDisposed();
        }
      },
      child: SizedBox(
        width: width,
        height: height,
        child: Cube(onSceneCreated: controller._onSceneCreated),
      ),
    );
  }
}

class FlutterTextureImage {
  static Future<Uint8List> getTextureAsPng(
    int textureId,
    int width,
    int height,
  ) async {
    final scene = SceneBuilder();
    scene.addTexture(
      textureId,
      width: width.toDouble(),
      height: height.toDouble(),
      freeze: true,
    );
    final build = scene.build();
    final imagemCapturada = await build.toImage(width, height);
    final imageData = await imagemCapturada.toByteData(
      format: ImageByteFormat.png,
    );
    final imageBytes = imageData!.buffer.asUint8List(
      imageData.offsetInBytes,
      imageData.buffer.lengthInBytes,
    );
    return imageBytes;
  }
}

class ThreeDModelController {
  late Scene _scene;
  Object? _cube;

  void _onSceneCreated(Scene scene) {
    _scene = scene;
    // scene.camera.position.x = 10;
    // scene.camera.position.y = 15;
    scene.camera.position.z = -1;
    // scene.camera.target.x = -10;
    // scene.camera.target.z = 20;
    _cube = Object(
      scale: Vector3(0.5, 0.5, 0.5),
      backfaceCulling: true,
      // fileName: 'assets/sword/sword.obj',
      fileName: 'assets/3D/frame1.obj',
    );
    scene.world.add(_cube!);
    Python.enter3D();
  }

  void onSceneDisposed() {
    // Dispose of resources if needed
    _cube = null;
    Python.leave3D();
  }

  double _wAngle = 0.0;
  double _xAngle = 0.0;
  double _yAngle = 0.0;
  double _zAngle = 0.0;

  void setAnglesObject({
    required double w,
    required double x,
    required double y,
    required double z,
  }) {
    _wAngle = w;
    _xAngle = x;
    _yAngle = y;
    _zAngle = z;
    _updateAngle();
  }

  void _updateAngle() {
    if (_cube != null) {
      _cube!.rotation.w = _wAngle;
      _cube!.rotation.x = _xAngle;
      _cube!.rotation.y = _zAngle;
      _cube!.rotation.z = -_yAngle;
      _cube!.updateTransform();
      _scene.update();
    }
  }
}
