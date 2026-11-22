package com.littlelater.app

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Festival app icons: one launcher alias is enabled at a time.
    private val icons = mapOf(
        "default" to ".IconDefault",
        "christmas" to ".IconChristmas",
        "newyear" to ".IconNewYear",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "littlelater/icon").setMethodCallHandler { call, result ->
            if (call.method != "setIcon") return@setMethodCallHandler result.notImplemented()
            val want = icons[call.argument<String>("name")] ?: icons.getValue("default")
            try {
                val pm = packageManager
                // Turn the wanted one on first, so there is never no icon.
                pm.setComponentEnabledSetting(ComponentName(packageName, packageName + want), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                for (alias in icons.values) {
                    if (alias == want) continue
                    pm.setComponentEnabledSetting(ComponentName(packageName, packageName + alias), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                }
                result.success(true)
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }
}
