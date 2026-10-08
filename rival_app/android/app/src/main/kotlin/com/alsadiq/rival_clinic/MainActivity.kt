package com.alsadiq.rival_clinic

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val main = Handler(Looper.getMainLooper())
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rival/video")
            .setMethodCallHandler { call, result ->
                if (call.method != "make") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        val path = VideoMaker.make(
                            call.argument<String>("before")!!,
                            call.argument<String>("after")!!,
                            call.argument<String>("overlay"),
                            call.argument<String>("output")!!,
                            call.argument<Double>("holdBefore")!!,
                            call.argument<Double>("morph")!!,
                            call.argument<Double>("holdAfter")!!,
                            call.argument<Int>("fps")!!,
                        )
                        main.post { result.success(path) }
                    } catch (e: Exception) {
                        main.post { result.error("video", e.message, null) }
                    }
                }.start()
            }
    }
}
