package cn.vexai.fuck

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app/back",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "moveTaskToBack" -> {
                    moveTaskToBack(true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app/installed_apps",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "list" -> {
                    Thread {
                        val intent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_LAUNCHER)
                        }
                        val apps = packageManager
                            .queryIntentActivities(intent, 0)
                            .map { it.activityInfo.applicationInfo }
                            .distinctBy { it.packageName }
                            .filter { (it.flags and ApplicationInfo.FLAG_SYSTEM) == 0 }
                            .map {
                                mapOf(
                                    "packageName" to it.packageName,
                                    "label" to packageManager.getApplicationLabel(it).toString(),
                                    "isSystemApp" to false,
                                )
                            }
                        runOnUiThread { result.success(apps) }
                    }.start()
                }
                "icon" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    Thread {
                        val appInfo = packageManager.getApplicationInfo(packageName, 0)
                        val icon = drawableToBase64(
                            packageManager.getApplicationIcon(appInfo),
                        )
                        runOnUiThread { result.success(icon) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val bitmap = when (drawable) {
            is BitmapDrawable -> drawable.bitmap
            else -> {
                val width = drawable.intrinsicWidth.coerceAtLeast(1)
                val height = drawable.intrinsicHeight.coerceAtLeast(1)
                val created = Bitmap.createBitmap(
                    width,
                    height,
                    Bitmap.Config.ARGB_8888,
                )
                val canvas = Canvas(created)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                created
            }
        }
        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
        return Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
    }
}
