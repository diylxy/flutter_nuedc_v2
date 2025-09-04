import 'package:flutter_nuedc_v2/view/widget/minecraft_sword.dart';
import 'package:get/get.dart';

class ThreedController extends GetxController{
  static ThreedController get to => Get.find<ThreedController>();
  late final ThreeDModelController controller;
  @override
  void onInit() {
    controller = ThreeDModelController();
    super.onInit();
  }
  
  @override
  void onClose() {
    super.onClose();
  }
}