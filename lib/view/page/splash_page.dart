import 'package:flutter/material.dart';
import 'package:flutter_nuedc_v2/controller/main_page_controller.dart';
import 'package:flutter_nuedc_v2/router/router.dart';
import 'package:get/get.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text('2025 · 全国电赛', style: TextStyle(fontSize: 36.0)),
            Card(
              color: Colors.cyan[900],
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Text('C题', style: TextStyle(fontSize: 72.0)),
              ),
            ),
            Column(
              children: [
                Text('基于单目视觉的', style: TextStyle(fontSize: 24.0)),
                Text('目标物测量装置', style: TextStyle(fontSize: 32.0)),
              ],
            ),
            IconButton.filled(
              onPressed: () {
                navigatorKey.currentState!.pushReplacement(
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (context, animation, secondaryAnimation) {
                      return FadeTransition(
                        opacity: animation,
                        child: Scaffold(
                          backgroundColor: Colors.black,
                          body: Center(
                            child: AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                if (animation.value < 1.0) {
                                  return SizedBox.shrink();
                                }
                                return FadeTransition(
                                  opacity: Tween<double>(begin: 0, end: 1)
                                      .animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Interval(0.5, 1.0),
                                        ),
                                      ),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: Duration(milliseconds: 1000),
                                    builder: (context, value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: child,
                                      );
                                    },
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          '祝一切顺利',
                                          style: TextStyle(
                                            fontSize: 48,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    transitionDuration: Duration(milliseconds: 1000),
                  ),
                );

                Future.delayed(Duration(milliseconds: 2500), () {
                  goReplaceNamedRoute(Routes.main);
                });
              },
              icon: Icon(Icons.chevron_right, size: 96),
            ),
            Column(
              children: [
                Text('准备完记得到设置开省电模式~', style: TextStyle(fontSize: 24.0)),
                Obx(
                  () => Text(
                    MainPageController.to.pythonHello.value
                        ? 'Python 已连接'
                        : 'Python 未连接',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: MainPageController.to.pythonHello.value
                          ? Colors.greenAccent
                          : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
