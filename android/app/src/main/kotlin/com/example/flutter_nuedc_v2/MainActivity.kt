package com.example.flutter_nuedc_v2

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.flutter_nuedc_v2/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBatteryDetails" -> {
                    val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager

                    // 获取基本信息
                    val capacity = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) // %
                    val current = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW) // µA
                    val chargeCounter = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER) // µAh
                    val energyCounter = batteryManager.getLongProperty(BatteryManager.BATTERY_PROPERTY_ENERGY_COUNTER) // nWh

                    // 获取电压、温度（通过广播）
                    val intent = Context.BATTERY_SERVICE.let {
                        registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                    }
                    val voltage = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1) // mV
                    val temperature = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, -1)?.toFloat()?.div(10) // ℃

                    val batteryDetails = mapOf(
                        "capacity" to capacity,
                        "current" to current,
                        "chargeCounter" to chargeCounter,
                        "energyCounter" to energyCounter,
                        "voltage" to voltage,
                        "temperature" to temperature
                    )

                    result.success(batteryDetails)
                }
                else -> result.notImplemented()
            }
        }
    }
}
