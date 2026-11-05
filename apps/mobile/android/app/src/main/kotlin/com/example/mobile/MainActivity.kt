package com.example.mobile

import android.content.Context
import android.os.BatteryManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "rideguardian/device_battery",
        ).setMethodCallHandler { call, result ->
            if (call.method != "getBatteryLevel") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            result.success(level.takeIf { it in 0..100 })
        }
    }
}
