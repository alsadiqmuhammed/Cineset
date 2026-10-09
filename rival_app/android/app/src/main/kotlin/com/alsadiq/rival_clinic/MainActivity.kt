package com.alsadiq.rival_clinic

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val main = Handler(Looper.getMainLooper())
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rival/video")
        channel.setMethodCallHandler { call, result ->
            if (call.method != "make") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val logFile = call.argument<String>("log")?.let { File(it) }
            runCatching { logFile?.writeText("") }
            fun log(line: String) {
                runCatching { logFile?.appendText("${System.currentTimeMillis()} $line\n") }
            }
            Thread {
                // Throwable (not just Exception): any failure must reply, or the
                // Flutter side would wait forever.
                try {
                    val path = VideoMaker.make(
                        call.argument<String>("before")!!,
                        call.argument<String>("after")!!,
                        call.argument<String>("overlay"),
                        call.argument<String>("output")!!,
                        VideoMaker.Timing(
                            call.argument<Double>("holdBefore")!!,
                            call.argument<Double>("morph")!!,
                            call.argument<Double>("holdAfter")!!,
                            call.argument<Int>("fps")!!,
                        ),
                        progress = { p -> main.post { channel.invokeMethod("progress", p) } },
                        log = ::log,
                    )
                    log("done $path")
                    main.post { result.success(path) }
                } catch (t: Throwable) {
                    log("failed: $t")
                    main.post { result.error("video", t.toString(), null) }
                }
            }.start()
        }
    }
}
