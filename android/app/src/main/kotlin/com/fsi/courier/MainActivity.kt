package com.fsi.courier

import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val storageChannel = "fsi_courier/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getFreeDiskSpaceGb") {
                    try {
                        val stat = StatFs(Environment.getDataDirectory().path)
                        val freeBytes = stat.blockSizeLong * stat.availableBlocksLong
                        result.success(freeBytes.toDouble() / (1024.0 * 1024.0 * 1024.0))
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
