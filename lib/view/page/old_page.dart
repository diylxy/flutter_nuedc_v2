import 'package:flutter_nuedc_v2/controller/camera_manager.dart';
import 'package:get/get.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';


class OldPage extends StatelessWidget {
  const OldPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CameraManager>(
      init: CameraManager(),
      builder: (controller) {
        return Scaffold(
          body: Column(
            children: <Widget>[
              Row(
                children: [
                  Obx(
                    () => Expanded(
                      child: Center(
                        child: CameraManager.to.cameraController != null
                            ? InteractiveViewer(
                                maxScale: 10,
                                child: _cameraPreview(),
                              )
                            : SizedBox.shrink(),
                      ),
                    ),
                  ),
                  Obx(
                    () => Expanded(
                      child: _previewContainer(
                        child: controller.opencvPreviewImage == null
                            ? const Text("waiting...")
                            : RawImage(
                                image: controller.opencvPreviewImage,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 50, child: _opencvControlWidget()),
              Obx(() => _cameraTogglesRowWidget(controller.cameras)),
            ],
          ),
        );
      },
    );
  }

  CameraPreview _cameraPreview() {
    return CameraPreview(
      CameraManager.to.cameraController!,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails details) =>
                onViewFinderTap(details, constraints),
          );
        },
      ),
    );
  }

  Widget _previewContainer({required Widget child}) {
    return InteractiveViewer(
      maxScale: 10.0,
      child: AspectRatio(aspectRatio: (210 - 40) / (297 - 40), child: child),
    );
  }

  Widget _opencvControlWidget() {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        FilledButton(onPressed: null, child: Text("棋盘格标定")),
        FilledButton(onPressed: null, child: Text("计算标定")),
        FilledButton(onPressed: null, child: Text("单次测量")),
        FilledButton(
          onPressed: () {
            CameraManager.to.stop();
          },
          child: Text("停止"),
        ),
        FilledButton(onPressed: null, child: Text("CNN测试")),
        FilledButton(onPressed: null, child: Text("清空缓存")),
      ],
    );
  }

  /// Returns a suitable camera icon for [direction].
  IconData _getCameraLensIcon(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.back:
        return Icons.camera_rear;
      case CameraLensDirection.front:
        return Icons.camera_front;
      case CameraLensDirection.external:
        return Icons.camera;
      // ignore: unreachable_switch_default
      default:
        return Icons.camera;
    }
  }

  Widget _cameraTogglesRowWidget(List<CameraDescription> cameras) {
    if (cameras.isEmpty) {
      return const Text('None');
    } else {
      return Row(
        children: List.generate(
          cameras.length,
          (index) => SizedBox(
            width: 150.0,
            child: RadioListTile<int>(
              title: Icon(_getCameraLensIcon(cameras[index].lensDirection)),
              groupValue: CameraManager.to.selectedCamera,
              value: index,
              onChanged: (int? id) {
                if (id == null) return;
                CameraManager.to.selectedCamera = id;
              },
            ),
          ),
        ),
      );
    }
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    CameraManager.to.onSetFocusPoint(offset);
  }
}

void showInSnackBar(String message) {
  Get.snackbar("提示", message);
}
