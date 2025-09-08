import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nuedc_v2/controller/camera_manager.dart';
import 'package:flutter_nuedc_v2/controller/main_page_controller.dart';
import 'package:flutter_nuedc_v2/view/page/main_page.dart';
import 'package:flutter_nuedc_v2/python_wrapper.dart';
import 'package:get/get.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size(80, 40),
      textStyle: const TextStyle(fontSize: 18, fontFamily: "MiSans"),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SliderTheme(
        data: SliderThemeData(showValueIndicator: ShowValueIndicator.always),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final aspectRatio = 3840 / 2160;
                final height = width / aspectRatio;
                return SizedBox(
                  width: width,
                  height: height,
                  child: FractionalLiTexture(aspectRatio, 0),
                );
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  // 相机选择
                  ListTile(
                    leading: Icon(Icons.camera),
                    title: const Text('相机选择', style: TextStyle(fontSize: 20)),
                    subtitle: Obx(
                      () => _cameraTogglesRowWidget(CameraManager.to.cameras),
                    ),
                  ),
                  // 棋盘格宽度
                  ListTile(
                    leading: Icon(Icons.grid_view),
                    title: const Text('棋盘格间距', style: TextStyle(fontSize: 20)),
                    subtitle: Obx(
                      () => Text(
                        '设置的间距: ${MainPageController.to.chessboardWidth} mm',
                      ),
                    ),
                    onTap: () {
                      showDialog<double>(
                        context: context,
                        builder: (context) {
                          double value = MainPageController.to.chessboardWidth
                              .toDouble();
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return AlertDialog(
                                title: const Text('设置棋盘格间距'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${value.toStringAsFixed(1)} mm'),
                                    Slider(
                                      value: value,
                                      min: 15.0,
                                      max: 30.0,
                                      label: value.toStringAsFixed(1),
                                      onChanged: (v) =>
                                          setState(() => value = v),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      MainPageController.to.chessboardWidth =
                                          value;
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('确定'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                  // 棋盘格标定
                  ListTile(
                    titleAlignment: ListTileTitleAlignment.titleHeight,
                    leading: Icon(Icons.grid_4x4),
                    title: const Text('棋盘格标定', style: TextStyle(fontSize: 20)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(
                          () => Text(
                            '有效: ${MainPageController.to.chessBoardCount.value}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: () {
                                Python.chessBoardClear();
                              },
                              style: buttonStyle,
                              child: const Text('清空'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {
                                Python.chessBoardCapture();
                              },
                              style: buttonStyle,
                              child: const Text('拍摄'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {
                                Python.chessBoardCalculate();
                              },
                              style: buttonStyle,
                              child: const Text('计算'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 世界原点标定
                  ListTile(
                    titleAlignment: ListTileTitleAlignment.titleHeight,
                    leading: Icon(Icons.pin_drop),
                    title: const Text('世界原点标定', style: TextStyle(fontSize: 20)),
                    trailing: FilledButton(
                      onPressed: () {
                        showDialog<double>(
                          context: context,
                          builder: (context) {
                            double value = 1250;
                            return StatefulBuilder(
                              builder: (context, setState) {
                                return AlertDialog(
                                  title: const Text('实际距离'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${value.toStringAsFixed(1)} mm'),
                                      Slider(
                                        value: value,
                                        min: 1200,
                                        max: 1300,
                                        label: value.toStringAsFixed(1),
                                        onChanged: (v) =>
                                            setState(() => value = v),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Python.worldOriginCalib(value);
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('拍摄目标物'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                      style: buttonStyle,
                      child: const Text('拍摄目标物'),
                    ),
                  ),
                  // 线性误差标定
                  ListTile(
                    titleAlignment: ListTileTitleAlignment.titleHeight,
                    leading: Icon(Icons.stacked_line_chart),
                    title: const Text('线性误差标定', style: TextStyle(fontSize: 20)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(
                          () =>
                              Text(MainPageController.to.linearErrorInfo.value),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: [
                            FilledButton(
                              onPressed: () {
                                Python.linearCalibClear();
                                MainPageController.to.linearErrorInfo.value =
                                    '未应用';
                              },
                              style: buttonStyle,
                              child: const Text('清空'),
                            ),
                            _linearErrorButton(context, buttonStyle, 800),
                            _linearErrorButton(context, buttonStyle, 1200),
                            _linearErrorButton(context, buttonStyle, 1400),
                            _linearErrorButton(context, buttonStyle, 1600),
                            _linearErrorButton(context, buttonStyle, 2000),
                            FilledButton(
                              onPressed: () {
                                Python.linearCalibCalculate();
                              },
                              style: buttonStyle,
                              child: const Text('计算'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 旋转误差标定（原算法有逻辑错误，不建议使用）
                  // ListTile(
                  //   titleAlignment: ListTileTitleAlignment.titleHeight,
                  //   leading: Icon(Icons.rotate_90_degrees_cw),
                  //   title: const Text('旋转误差标定', style: TextStyle(fontSize: 20)),
                  //   subtitle: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       Obx(
                  //         () => Text(
                  //           MainPageController.to.circularErrorInfo.value,
                  //         ),
                  //       ),
                  //       const SizedBox(height: 8),
                  //       Wrap(
                  //         spacing: 8.0,
                  //         runSpacing: 8.0,
                  //         children: [
                  //           FilledButton(
                  //             onPressed: () {
                  //               Python.circularCalibClear();
                  //               MainPageController.to.circularErrorInfo.value =
                  //                   '未应用';
                  //             },
                  //             style: buttonStyle,
                  //             child: const Text('清空'),
                  //           ),
                  //           _circularCalibButton(context, buttonStyle),
                  //           FilledButton(
                  //             onPressed: () {
                  //               Python.circularCalibCalculate();
                  //             },
                  //             style: buttonStyle,
                  //             child: const Text('计算'),
                  //           ),
                  //         ],
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  // 低功耗
                  ListTile(
                    leading: Icon(Icons.battery_saver),
                    title: const Text('省电模式', style: TextStyle(fontSize: 20)),
                    trailing: Obx(
                      () => Switch(
                        value: MainPageController.to.lowPowerMode,
                        onChanged: (value) =>
                            MainPageController.to.lowPowerMode = value,
                      ),
                    ),
                    onTap: () {
                      MainPageController.to.lowPowerMode =
                          !MainPageController.to.lowPowerMode;
                    },
                  ),
                  // 连续测量
                  ListTile(
                    leading: Icon(Icons.all_inclusive),
                    title: const Text('连续测量', style: TextStyle(fontSize: 20)),
                    trailing: Obx(
                      () => Switch(
                        value: MainPageController.to.realtimeMeasurement,
                        onChanged: (value) =>
                            MainPageController.to.realtimeMeasurement = value,
                      ),
                    ),
                    onTap: () {
                      MainPageController.to.realtimeMeasurement =
                          !MainPageController.to.realtimeMeasurement;
                    },
                  ),
                  // 对焦模式
                  ListTile(
                    leading: Icon(Icons.center_focus_strong),
                    title: const Text('对焦模式', style: TextStyle(fontSize: 20)),
                    trailing: Obx(
                      () => Switch(
                        value: MainPageController.to.focusMode,
                        onChanged: (value) =>
                            MainPageController.to.focusMode = value,
                      ),
                    ),
                    onTap: () {
                      MainPageController.to.focusMode =
                          !MainPageController.to.focusMode;
                    },
                  ),
                  // 黑白调参模式
                  ListTile(
                    leading: Icon(Icons.pest_control_sharp),
                    title: const Text('黑白调参模式', style: TextStyle(fontSize: 20)),
                    trailing: Obx(
                      () => Switch(
                        value: MainPageController.to.bwMode,
                        onChanged: (value) =>
                            MainPageController.to.bwMode = value,
                      ),
                    ),
                    onTap: () {
                      MainPageController.to.bwMode =
                          !MainPageController.to.bwMode;
                    },
                  ),
                  // 黑白阈值
                  ListTile(
                    titleAlignment: ListTileTitleAlignment.titleHeight,
                    leading: Icon(Icons.contrast),
                    title: const Text('黑白阈值', style: TextStyle(fontSize: 20)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(
                          () => Text(
                            '边框阈值: ${MainPageController.to.bwThresholdPaper.toInt()}',
                          ),
                        ),
                        Obx(
                          () => Text(
                            '测量阈值: ${MainPageController.to.bwThresholdRect.toInt()}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Obx(
                          () => Slider(
                            min: 0,
                            max: 255,
                            value: MainPageController.to.bwThresholdPaper,
                            onChanged: (v) =>
                                MainPageController.to.bwThresholdPaper = v,
                            label: MainPageController.to.bwThresholdPaper
                                .toInt()
                                .toString(),
                          ),
                        ),
                        Obx(
                          () => Slider(
                            min: 0,
                            max: 255,
                            value: MainPageController.to.bwThresholdRect,
                            onChanged: (v) =>
                                MainPageController.to.bwThresholdRect = v,
                            label: MainPageController.to.bwThresholdRect
                                .toInt()
                                .toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Canny调参模式
                  ListTile(
                    leading: Icon(Icons.border_outer),
                    title: const Text(
                      'Canny调参模式',
                      style: TextStyle(fontSize: 20),
                    ),
                    trailing: Obx(
                      () => Switch(
                        value: MainPageController.to.cannyMode,
                        onChanged: (value) =>
                            MainPageController.to.cannyMode = value,
                      ),
                    ),
                    onTap: () {
                      MainPageController.to.cannyMode =
                          !MainPageController.to.cannyMode;
                    },
                  ),
                  // Canny阈值
                  ListTile(
                    titleAlignment: ListTileTitleAlignment.titleHeight,
                    leading: Icon(Icons.grid_on_sharp),
                    title: const Text(
                      'Canny阈值',
                      style: TextStyle(fontSize: 20),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(
                          () => Text(
                            '低阈值: ${MainPageController.to.cannyLow.toInt()}',
                          ),
                        ),
                        Obx(
                          () => Text(
                            '高阈值: ${MainPageController.to.cannyHigh.toInt()}',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Obx(
                          () => Slider(
                            min: 50,
                            max: 500,
                            value: MainPageController.to.cannyLow,
                            onChanged: (v) =>
                                MainPageController.to.cannyLow = v,
                            label: MainPageController.to.cannyLow
                                .toInt()
                                .toString(),
                          ),
                        ),
                        Obx(
                          () => Slider(
                            min: 50,
                            max: 600,
                            value: MainPageController.to.cannyHigh,
                            onChanged: (v) =>
                                MainPageController.to.cannyHigh = v,
                            label: MainPageController.to.cannyHigh
                                .toInt()
                                .toString(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '[ 以下危险区，请谨慎操作 ]',
                        style: TextStyle(fontSize: 20, color: Colors.red),
                      ),
                    ],
                  ),
                  // 保存标定结果
                  ListTile(
                    tileColor: Color.lerp(Colors.red, Colors.black, 0.6),
                    leading: Icon(Icons.save),
                    title: const Text(
                      '保存标定结果',
                      style: TextStyle(fontSize: 20, color: Colors.red),
                    ),
                    subtitle: Text('保存本次标定结果到dataMaps.pkl\n将覆盖上次标定文件，请再次确认'),
                    onTap: () {
                      Python.saveResult();
                    },
                  ),
                  // 读取标定结果
                  ListTile(
                    tileColor: Color.lerp(Colors.red, Colors.black, 0.6),
                    leading: Icon(Icons.restore),
                    title: const Text(
                      '读取标定结果',
                      style: TextStyle(fontSize: 20, color: Colors.red),
                    ),
                    subtitle: Text('从dataMaps.pkl读取标定结果\n将覆盖当前全部状态，请再次确认'),
                    onTap: () {
                      Python.loadResult();
                    },
                  ),
                  // END
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  FilledButton _linearErrorButton(
    BuildContext context,
    ButtonStyle buttonStyle,
    double actual,
  ) {
    return FilledButton(
      onPressed: () {
        showDialog<double>(
          context: context,
          builder: (context) {
            double value = actual;
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text('实际距离'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${value.toStringAsFixed(1)} mm'),
                      Slider(
                        value: value,
                        min: actual - 50,
                        max: actual + 50,
                        label: value.toStringAsFixed(3),
                        onChanged: (v) => setState(() => value = v),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Python.linearCalib(value);
                        Navigator.of(context).pop();
                      },
                      child: Text('标定'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      style: buttonStyle,
      child: Text(
        '${(actual / 1000).toStringAsFixed(1)}m',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  FilledButton _circularCalibButton(
    BuildContext context,
    ButtonStyle buttonStyle,
  ) {
    return FilledButton(
      onPressed: () {
        showDialog<double>(
          context: context,
          builder: (context) {
            double value = 1500.0;
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text('实际距离'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${value.toStringAsFixed(1)} mm'),
                      Slider(
                        value: value,
                        min: 1500.0 - 50,
                        max: 1500.0 + 50,
                        label: value.toStringAsFixed(3),
                        onChanged: (v) => setState(() => value = v),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('取消'),
                    ),
                    TextButton(
                      onPressed: () {
                        Python.circularCalib(value);
                        Navigator.of(context).pop();
                      },
                      child: Text('标定'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      style: buttonStyle,
      child: Text(
        '${(1.5).toStringAsFixed(1)}m',
        style: TextStyle(fontSize: 18),
      ),
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

  /// Returns a suitable camera icon for [direction].
  String _getCameraLensName(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.back:
        return "后置";
      case CameraLensDirection.front:
        return "前置";
      case CameraLensDirection.external:
        return "外部";
      // ignore: unreachable_switch_default
      default:
        return "相机";
    }
  }

  Widget _cameraTogglesRowWidget(List<CameraDescription> cameras) {
    if (cameras.isEmpty) {
      return const Text('None');
    } else {
      return Row(
        children: [
          TextButton.icon(
            onPressed: () {
              CameraManager.to.stop();
            },
            icon: Icon(Icons.no_photography),
            label: Text("关闭"),
          ),
          ...List.generate(
            cameras.length,
            (index) => TextButton.icon(
              onPressed: () {
                CameraManager.to.selectedCamera = index;
              },
              icon: Icon(_getCameraLensIcon(cameras[index].lensDirection)),
              label: Text(_getCameraLensName(cameras[index].lensDirection)),
            ),
          ),
        ],
      );
    }
  }
}
