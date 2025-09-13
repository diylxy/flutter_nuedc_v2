import 'package:flutter_nuedc_v2/controller/camera_manager.dart';
import 'package:flutter_nuedc_v2/controller/main_page_controller.dart';
import 'package:flutter_nuedc_v2/python_wrapper.dart';
import 'package:flutter_nuedc_v2/router/router.dart';
import 'package:get/get.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';


class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonStyle = FilledButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
    );
    return Scaffold(
      appBar: AppBar(title: Text('基于单目视觉的目标物测量装置')),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = 250.0;
                  return SizedBox(
                    width: width,
                    height: height,
                    child: FractionalLiTexture(1.0, 0),
                  );
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        spacing: 8.0,
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  spacing: 16.0,
                                  children: [
                                    Obx(
                                      () => Text(
                                        MainPageController.to.currentRectID < 0
                                            ? '要测量 [最小的] 图形'
                                            : '要测量 [${MainPageController.to.currentRectID}号] 矩形',
                                        style: TextStyle(fontSize: 24),
                                      ),
                                    ),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        spacing: 8.0,
                                        children: [
                                          _numberButton(buttonStyle, -1),
                                          ...List.generate(
                                            10,
                                            (index) => _numberButton(
                                              buttonStyle,
                                              index,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: Obx(
                            () => FilledButton(
                              onPressed: MainPageController.to.loading.value
                                  ? null
                                  : () {
                                      MainPageController.to.currentMode =
                                          OneshotMode.measuring;
                                      Python.oneshotMeasurement();
                                    },
                              style: FilledButton.styleFrom(
                                shape: ContinuousRectangleBorder(
                                  borderRadius: BorderRadius.circular(64),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 48,
                                  fontFamily: 'MiSans',
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Icon(Icons.straighten, size: 72),
                                  Text(
                                    MainPageController.to.loading.value
                                        ? '正在测量'
                                        : '一键测量',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Obx(
                                  () => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    spacing: 8.0,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '基准距离 D=',
                                            style: TextStyle(fontSize: 24.0),
                                          ),
                                          Text(
                                            '${MainPageController.to.distance.toStringAsFixed(1)} mm',
                                            style: TextStyle(fontSize: 24.0),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '边长或直径 x=',
                                            style: TextStyle(fontSize: 24.0),
                                          ),
                                          Text(
                                            '${MainPageController.to.minSize.toStringAsFixed(2)} mm',
                                            style: TextStyle(fontSize: 24.0),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '轴线角 θ=',
                                            style: TextStyle(fontSize: 24.0),
                                          ),
                                          Text(
                                            '${MainPageController.to.yAngle.toStringAsFixed(2)} °',
                                            style: TextStyle(fontSize: 24.0),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '前倾角 φ=',
                                            style: TextStyle(fontSize: 24.0),
                                          ),
                                          Text(
                                            '${MainPageController.to.xAngle.toStringAsFixed(2)} °',
                                            style: TextStyle(fontSize: 24.0),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '当前模式',
                                            style: TextStyle(fontSize: 24.0),
                                          ),
                                          Text(
                                            MainPageController.to.currentMode
                                                .toString(),
                                            style: TextStyle(fontSize: 24.0),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Column(
                            spacing: 8.0,
                            children: [
                              IconButton.filledTonal(
                                onPressed: () {
                                  goNamedRoute(Routes.twod);
                                },
                                style: buttonStyle,
                                icon: Icon(Icons.document_scanner, size: 36),
                                tooltip: '2D视图',
                              ),
                              IconButton.filledTonal(
                                onPressed: () {
                                  goNamedRoute(Routes.threed);
                                },
                                style: buttonStyle,
                                icon: Icon(Icons.view_in_ar, size: 36),
                                tooltip: '3D视图',
                              ),
                              IconButton.filledTonal(
                                onPressed: () {
                                  goNamedRoute(Routes.settings);
                                },
                                style: buttonStyle,
                                icon: Icon(Icons.settings, size: 36),
                                tooltip: '系统设置',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberButton(ButtonStyle buttonStyle, int n) {
    return FilledButton(
      onPressed: () {
        MainPageController.to.currentRectID = n;
      },
      style: buttonStyle,
      child: Text(n < 0 ? '清空' : '$n', style: TextStyle(fontSize: 24)),
    );
  }
}

class FractionalLiTexture extends StatelessWidget {
  final double aspectRatio;
  final int index;
  const FractionalLiTexture(this.aspectRatio, this.index, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        index == 0
            ? Expanded(
                child: Center(
                  child: InteractiveViewer(
                    maxScale: 10,
                    child: _cameraPreview(),
                  ),
                ),
              )
            : SizedBox.shrink(),
        Obx(
          () => Expanded(
            child: _previewContainer(
              child: CameraManager.to.opencvPreviewImage == null
                  ? const Center(child: Text("图像预览窗口"))
                  : RawImage(
                      image: CameraManager.to.opencvPreviewImage,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.low,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cameraPreview() {
    return Obx(
      () => CameraManager.to.cameraController != null
          ? CameraPreview(
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
            )
          : const Center(child: Text('未选择相机')),
    );
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    CameraManager.to.onSetFocusPoint(offset);
  }

  Widget _previewContainer({required Widget child}) {
    return InteractiveViewer(
      maxScale: 10.0,
      child: AspectRatio(aspectRatio: (210 - 40) / (297 - 40), child: child),
    );
  }
}
