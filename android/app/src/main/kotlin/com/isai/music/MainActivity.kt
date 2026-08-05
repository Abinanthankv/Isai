package com.isai.music

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import android.os.Build

class MainActivity: AudioServiceActivity() {
    private var visualizerPlugin: AudioVisualizerPlugin? = null
    private var audioFxPlugin: AudioFxPlugin? = null
    private val CHANNEL = "com.isai.music/updater"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        visualizerPlugin = AudioVisualizerPlugin(flutterEngine)
        audioFxPlugin = AudioFxPlugin(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val path = call.argument<String>("path")
                if (path != null) {
                    try {
                        installApk(path)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Path is null", null)
                }
            } else if (call.method == "getDeviceAbi") {
                result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "")
            } else if (call.method == "getAppVersion") {
                try {
                    val packageInfo = packageManager.getPackageInfo(packageName, 0)
                    result.success(packageInfo.versionName ?: "1.0.0")
                } catch (e: Exception) {
                    result.success("1.0.0")
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw Exception("File does not exist: $path")
        }
        val intent = Intent(Intent.ACTION_VIEW)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val apkUri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } else {
            intent.setDataAndType(Uri.fromFile(file), "application/vnd.android.package-archive")
        }
        startActivity(intent)
    }

    override fun onDestroy() {
        visualizerPlugin?.dispose()
        audioFxPlugin?.dispose()
        super.onDestroy()
    }
}
