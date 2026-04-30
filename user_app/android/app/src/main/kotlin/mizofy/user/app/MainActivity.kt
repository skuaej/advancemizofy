package mizofy.user.app

import io.flutter.embedding.android.FlutterActivity
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.PictureInPictureParams
import android.util.Rational
import android.os.Build

class MainActivity: FlutterActivity() {
    private val CHANNEL = "mizofy.user/security"
    private var isPlayerActive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPackageInstalled" -> {
                    val packageName = call.argument<String>("packageName")
                    val isInstalled = isPackageInstalled(packageName!!)
                    result.success(isInstalled)
                }
                "enterPipMode" -> {
                    enterPip()
                    result.success(true)
                }
                "setPlayerActive" -> {
                    isPlayerActive = call.argument<Boolean>("active") ?: false
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun enterPip() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
        }
    }

    // Automatic PiP on Minimize (Home Button)
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (isPlayerActive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            enterPip()
        }
    }
}
