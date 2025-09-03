import 'package:flutter/services.dart';

class BatteryService {
  static const platform = MethodChannel('com.example.flutter_nuedc_v2/battery');

  static Future<Map<String, dynamic>> getBatteryDetails() async {
    final result = await platform.invokeMethod<Map>('getBatteryDetails');
    return Map<String, dynamic>.from(result ?? {});
  }
}
// void loadBatteryInfo() async {
//   final details = await BatteryService.getBatteryDetails();
//   print("电池电量: ${details['capacity']}%");
//   print("电压: ${details['voltage']} mV");
//   print("电流: ${details['current']} µA");
//   print("充电计数: ${details['chargeCounter']} µAh");
//   print("温度: ${details['temperature']} ℃");
// }