package com.fsi.courier

import android.content.Intent
import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val storageChannel = "fsi_courier/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getFreeDiskSpaceGb" -> {
                        try {
                            val stat = StatFs(Environment.getDataDirectory().path)
                            val freeBytes = stat.blockSizeLong * stat.availableBlocksLong
                            result.success(freeBytes.toDouble() / (1024.0 * 1024.0 * 1024.0))
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", e.message, null)
                        }
                    }
                    "openDateTimeSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_DATE_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            // Fall back to general Settings if date/time page is restricted.
                            try {
                                val fallback = Intent(Settings.ACTION_SETTINGS).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallback)
                                result.success(null)
                            } catch (e2: Exception) {
                                result.error("UNAVAILABLE", e2.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
