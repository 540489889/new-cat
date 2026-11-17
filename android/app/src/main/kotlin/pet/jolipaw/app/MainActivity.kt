package pet.jolipaw.app

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        /// WXEntryActivity 收到授权 code 后暂存，MainActivity 恢复时抛给 Flutter
        var pendingWechatCode: String? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.flttercat/wechat")
            .setMethodCallHandler { call, result ->
                result.notImplemented()
            }
    }

    override fun onResume() {
        super.onResume()
        val code = pendingWechatCode
        if (!code.isNullOrEmpty()) {
            pendingWechatCode = null
            Log.d("MainActivity", "onResume sending wechat code=$code")
            flutterEngine?.dartExecutor?.binaryMessenger?.let {
                MethodChannel(it, "com.flttercat/wechat")
                    .invokeMethod("onWechatAuthCode", code)
            }
        }
    }
}
