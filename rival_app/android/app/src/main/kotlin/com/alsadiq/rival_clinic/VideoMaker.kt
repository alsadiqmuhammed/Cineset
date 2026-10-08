package com.alsadiq.rival_clinic

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.opengl.GLUtils
import android.view.Surface
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Encodes a before -> after transition to H.264 MP4: hold "before", cross-dissolve
 * to "after" while slowly zooming in, then hold "after". Frames come as two PNGs
 * of the same size (already aligned by the Flutter side); the optional overlay PNG
 * (template / brand frame) is drawn on top of every frame without the zoom.
 *
 * Primary path renders with OpenGL into the encoder's input Surface (fast, and the
 * driver handles stride/alignment). If that fails, a CPU path feeds YUV buffers at
 * 720x1280. Both paths have a watchdog, so a stalled encoder ends with an error
 * instead of hanging forever.
 */
object VideoMaker {
    private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
    private const val TIMEOUT_US = 10_000L
    private const val STALL_NS = 20_000_000_000L

    class Timing(val holdBefore: Double, val morph: Double, val holdAfter: Double, val fps: Int) {
        val total = ((holdBefore + morph + holdAfter) * fps).toInt()
        fun mix(i: Int): Double {
            val t = i.toDouble() / fps
            val x = ((t - holdBefore) / morph).coerceIn(0.0, 1.0)
            return x * x * (3 - 2 * x)
        }
        fun zoom(i: Int) = 1.0 + 0.06 * (i.toDouble() / total)
        fun ptsUs(i: Int) = i * 1_000_000L / fps
    }

    fun make(
        beforePath: String,
        afterPath: String,
        overlayPath: String?,
        outPath: String,
        timing: Timing,
        progress: (Double) -> Unit,
        log: (String) -> Unit,
    ): String {
        val before = BitmapFactory.decodeFile(beforePath) ?: error("Cannot read $beforePath")
        val after = BitmapFactory.decodeFile(afterPath) ?: error("Cannot read $afterPath")
        val overlay = overlayPath?.let { BitmapFactory.decodeFile(it) }
        log("frames ${before.width}x${before.height}, overlay=${overlay != null}, frames=${timing.total}")
        try {
            val w = before.width and 1.inv()
            val h = before.height and 1.inv()
            val sizes = listOf(w to h, 720 to 1280).distinct().filter { supported(it.first, it.second, log) }
            for ((sw, sh) in sizes.ifEmpty { listOf(720 to 1280) }) {
                try {
                    log("GL encode ${sw}x$sh")
                    return GlEncoder(sw, sh, timing, log).encode(before, after, overlay, outPath, progress)
                } catch (t: Throwable) {
                    log("GL failed at ${sw}x$sh: $t")
                    File(outPath).delete()
                }
            }
            log("CPU encode 720x1280")
            return BufferEncoder(720, 1280, timing, log).encode(before, after, overlay, outPath, progress)
        } finally {
            before.recycle()
            after.recycle()
            overlay?.recycle()
        }
    }

    private fun supported(w: Int, h: Int, log: (String) -> Unit): Boolean = try {
        val ok = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.any { info ->
            info.isEncoder && info.supportedTypes.any { it.equals(MIME, true) } &&
                info.getCapabilitiesForType(MIME).videoCapabilities.isSizeSupported(w, h)
        }
        if (!ok) log("size ${w}x$h not supported by any AVC encoder")
        ok
    } catch (t: Throwable) {
        true
    }

    /** Collects encoder output into the muxer, with a watchdog. */
    private class Drainer(
        private val codec: MediaCodec,
        private val muxer: MediaMuxer,
        private val log: (String) -> Unit,
    ) {
        private val info = MediaCodec.BufferInfo()
        private var track = -1
        var muxing = false
        var lastProgress = System.nanoTime()
        var samples = 0

        fun watchdog() {
            if (System.nanoTime() - lastProgress > STALL_NS) {
                throw IllegalStateException("encoder stalled (no output for 20s, $samples samples)")
            }
        }

        /** Returns true once end of stream was seen. */
        fun drain(endOfStream: Boolean): Boolean {
            while (true) {
                val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                when {
                    index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        if (!endOfStream) return false
                        watchdog()
                    }
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxing = true
                        lastProgress = System.nanoTime()
                    }
                    index >= 0 -> {
                        val buffer = codec.getOutputBuffer(index)!!
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (info.size > 0 && muxing) {
                            buffer.position(info.offset)
                            buffer.limit(info.offset + info.size)
                            muxer.writeSampleData(track, buffer, info)
                            samples++
                        }
                        codec.releaseOutputBuffer(index, false)
                        lastProgress = System.nanoTime()
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            log("end of stream after $samples samples")
                            return true
                        }
                    }
                    else -> watchdog() // e.g. INFO_OUTPUT_BUFFERS_CHANGED on old devices
                }
            }
        }
    }

    private fun format(w: Int, h: Int, fps: Int, color: Int) =
        MediaFormat.createVideoFormat(MIME, w, h).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, color)
            setInteger(MediaFormat.KEY_BIT_RATE, (w * h * 5).coerceAtMost(12_000_000))
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

    // ---------------------------------------------------------------- GPU path

    private class GlEncoder(
        private val w: Int,
        private val h: Int,
        private val timing: Timing,
        private val log: (String) -> Unit,
    ) {
        fun encode(
            before: Bitmap,
            after: Bitmap,
            overlay: Bitmap?,
            outPath: String,
            progress: (Double) -> Unit,
        ): String {
            val codec = MediaCodec.createEncoderByType(MIME)
            log("encoder ${codec.name}")
            var muxer: MediaMuxer? = null
            var egl: Egl? = null
            var surface: Surface? = null
            var started = false
            try {
                codec.configure(
                    format(w, h, timing.fps, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface),
                    null, null, MediaCodec.CONFIGURE_FLAG_ENCODE,
                )
                surface = codec.createInputSurface()
                codec.start()
                started = true
                muxer = MediaMuxer(outPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                val drainer = Drainer(codec, muxer, log)
                egl = Egl(surface)
                val renderer = Renderer(before, after, overlay)
                for (i in 0 until timing.total) {
                    GLES20.glViewport(0, 0, w, h)
                    renderer.draw(timing.mix(i).toFloat(), timing.zoom(i).toFloat())
                    egl.present(timing.ptsUs(i) * 1000)
                    drainer.drain(false)
                    drainer.watchdog()
                    if (i % 5 == 0) progress(i.toDouble() / timing.total)
                }
                codec.signalEndOfInputStream()
                drainer.drain(true)
                renderer.release()
                if (drainer.samples == 0) error("encoder produced no frames")
                progress(1.0)
                return outPath
            } finally {
                egl?.release()
                surface?.release()
                if (started) runCatching { codec.stop() }
                codec.release()
                muxer?.let { m -> runCatching { m.stop() }; m.release() }
            }
        }
    }

    /** EGL context bound to the encoder's input surface. */
    private class Egl(surface: Surface) {
        private val display: EGLDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        private val context: EGLContext
        private val eglSurface: EGLSurface

        init {
            val version = IntArray(2)
            check(EGL14.eglInitialize(display, version, 0, version, 1)) { "eglInitialize" }
            val attribs = intArrayOf(
                EGL14.EGL_RED_SIZE, 8, EGL14.EGL_GREEN_SIZE, 8, EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                0x3142 /* EGL_RECORDABLE_ANDROID */, 1,
                EGL14.EGL_NONE,
            )
            val configs = arrayOfNulls<EGLConfig>(1)
            val count = IntArray(1)
            check(EGL14.eglChooseConfig(display, attribs, 0, configs, 0, 1, count, 0) && count[0] > 0) {
                "eglChooseConfig"
            }
            context = EGL14.eglCreateContext(
                display, configs[0], EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0,
            )
            check(context != EGL14.EGL_NO_CONTEXT) { "eglCreateContext" }
            eglSurface = EGL14.eglCreateWindowSurface(display, configs[0], surface, intArrayOf(EGL14.EGL_NONE), 0)
            check(eglSurface != EGL14.EGL_NO_SURFACE) { "eglCreateWindowSurface" }
            check(EGL14.eglMakeCurrent(display, eglSurface, eglSurface, context)) { "eglMakeCurrent" }
        }

        fun present(ns: Long) {
            EGLExt.eglPresentationTimeANDROID(display, eglSurface, ns)
            check(EGL14.eglSwapBuffers(display, eglSurface)) { "eglSwapBuffers" }
        }

        fun release() {
            EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
            EGL14.eglDestroySurface(display, eglSurface)
            EGL14.eglDestroyContext(display, context)
            EGL14.eglReleaseThread()
            EGL14.eglTerminate(display)
        }
    }

    /** Draws the cross-dissolve with zoom, then the overlay (premultiplied) on top. */
    private class Renderer(before: Bitmap, after: Bitmap, overlay: Bitmap?) {
        private val program: Int
        private val textures = IntArray(3)
        private val hasOverlay = overlay != null
        private val quad: FloatBuffer = ByteBuffer.allocateDirect(8 * 4)
            .order(ByteOrder.nativeOrder()).asFloatBuffer()
            .apply { put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f)); position(0) }

        init {
            program = link(
                """
                attribute vec2 aPos;
                varying vec2 vUv;
                void main() {
                    vUv = vec2((aPos.x + 1.0) * 0.5, 1.0 - (aPos.y + 1.0) * 0.5);
                    gl_Position = vec4(aPos, 0.0, 1.0);
                }
                """,
                """
                precision mediump float;
                varying vec2 vUv;
                uniform sampler2D uBefore;
                uniform sampler2D uAfter;
                uniform sampler2D uOverlay;
                uniform float uMix;
                uniform float uZoom;
                uniform float uHasOverlay;
                void main() {
                    vec2 z = (vUv - 0.5) / uZoom + 0.5;
                    vec4 c = mix(texture2D(uBefore, z), texture2D(uAfter, z), uMix);
                    if (uHasOverlay > 0.5) {
                        vec4 o = texture2D(uOverlay, vUv);
                        c = o + c * (1.0 - o.a);
                    }
                    gl_FragColor = vec4(c.rgb, 1.0);
                }
                """,
            )
            GLES20.glGenTextures(3, textures, 0)
            upload(0, before)
            upload(1, after)
            if (overlay != null) upload(2, overlay)
        }

        private fun upload(i: Int, bitmap: Bitmap) {
            GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + i)
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[i])
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
            val err = GLES20.glGetError()
            check(err == GLES20.GL_NO_ERROR) { "texture upload failed: $err" }
        }

        fun draw(mix: Float, zoom: Float) {
            GLES20.glUseProgram(program)
            val pos = GLES20.glGetAttribLocation(program, "aPos")
            GLES20.glEnableVertexAttribArray(pos)
            GLES20.glVertexAttribPointer(pos, 2, GLES20.GL_FLOAT, false, 0, quad)
            for ((i, name) in listOf("uBefore", "uAfter", "uOverlay").withIndex()) {
                GLES20.glActiveTexture(GLES20.GL_TEXTURE0 + i)
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textures[i])
                GLES20.glUniform1i(GLES20.glGetUniformLocation(program, name), i)
            }
            GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uMix"), mix)
            GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uZoom"), zoom)
            GLES20.glUniform1f(GLES20.glGetUniformLocation(program, "uHasOverlay"), if (hasOverlay) 1f else 0f)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            val err = GLES20.glGetError()
            check(err == GLES20.GL_NO_ERROR) { "draw failed: $err" }
        }

        fun release() {
            GLES20.glDeleteTextures(3, textures, 0)
            GLES20.glDeleteProgram(program)
        }

        private fun link(vs: String, fs: String): Int {
            fun compile(type: Int, src: String): Int {
                val s = GLES20.glCreateShader(type)
                GLES20.glShaderSource(s, src)
                GLES20.glCompileShader(s)
                val ok = IntArray(1)
                GLES20.glGetShaderiv(s, GLES20.GL_COMPILE_STATUS, ok, 0)
                check(ok[0] != 0) { "shader: " + GLES20.glGetShaderInfoLog(s) }
                return s
            }
            val p = GLES20.glCreateProgram()
            GLES20.glAttachShader(p, compile(GLES20.GL_VERTEX_SHADER, vs))
            GLES20.glAttachShader(p, compile(GLES20.GL_FRAGMENT_SHADER, fs))
            GLES20.glLinkProgram(p)
            val ok = IntArray(1)
            GLES20.glGetProgramiv(p, GLES20.GL_LINK_STATUS, ok, 0)
            check(ok[0] != 0) { "link: " + GLES20.glGetProgramInfoLog(p) }
            return p
        }
    }

    // ---------------------------------------------------------------- CPU path

    private class BufferEncoder(
        private val w: Int,
        private val h: Int,
        private val timing: Timing,
        private val log: (String) -> Unit,
    ) {
        fun encode(
            before: Bitmap,
            after: Bitmap,
            overlay: Bitmap?,
            outPath: String,
            progress: (Double) -> Unit,
        ): String {
            val codec = MediaCodec.createEncoderByType(MIME)
            log("encoder ${codec.name} (buffers)")
            var muxer: MediaMuxer? = null
            var started = false
            val frame = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(frame)
            val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
            val argb = IntArray(w * h)
            try {
                codec.configure(
                    format(w, h, timing.fps, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible),
                    null, null, MediaCodec.CONFIGURE_FLAG_ENCODE,
                )
                codec.start()
                started = true
                muxer = MediaMuxer(outPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                val drainer = Drainer(codec, muxer, log)
                var i = 0
                while (i <= timing.total) {
                    val index = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (index < 0) {
                        drainer.drain(false)
                        drainer.watchdog()
                        continue
                    }
                    val pts = timing.ptsUs(i)
                    if (i == timing.total) {
                        codec.queueInputBuffer(index, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                    } else {
                        drawFrame(canvas, paint, before, after, overlay, timing.mix(i), timing.zoom(i))
                        frame.getPixels(argb, 0, w, 0, 0, w, h)
                        val image = codec.getInputImage(index) ?: error("no input image")
                        writeYuv(argb, w, h, image)
                        codec.queueInputBuffer(index, 0, w * h * 3 / 2, pts, 0)
                    }
                    drainer.lastProgress = System.nanoTime()
                    i++
                    drainer.drain(false)
                    if (i % 5 == 0) progress(i.toDouble() / timing.total)
                }
                drainer.drain(true)
                if (drainer.samples == 0) error("encoder produced no frames")
                progress(1.0)
                return outPath
            } finally {
                frame.recycle()
                if (started) runCatching { codec.stop() }
                codec.release()
                muxer?.let { m -> runCatching { m.stop() }; m.release() }
            }
        }

        private fun drawFrame(
            canvas: Canvas, paint: Paint, before: Bitmap, after: Bitmap, overlay: Bitmap?,
            mix: Double, zoom: Double,
        ) {
            canvas.save()
            canvas.scale(zoom.toFloat(), zoom.toFloat(), w / 2f, h / 2f)
            canvas.scale(w.toFloat() / before.width, h.toFloat() / before.height)
            paint.alpha = 255
            canvas.drawBitmap(before, 0f, 0f, paint)
            if (mix > 0) {
                paint.alpha = (mix * 255).toInt().coerceIn(0, 255)
                canvas.drawBitmap(after, 0f, 0f, paint)
            }
            canvas.restore()
            if (overlay != null) {
                paint.alpha = 255
                canvas.save()
                canvas.scale(w.toFloat() / overlay.width, h.toFloat() / overlay.height)
                canvas.drawBitmap(overlay, 0f, 0f, paint)
                canvas.restore()
            }
        }

        /** ARGB -> YUV 4:2:0 (BT.601 limited range), honouring the codec's plane layout. */
        private fun writeYuv(argb: IntArray, width: Int, height: Int, image: android.media.Image) {
            val planes = image.planes
            val y = planes[0]
            val yBuf = y.buffer
            val yRow = ByteArray(width)
            for (row in 0 until height) {
                val base = row * width
                for (col in 0 until width) {
                    val c = argb[base + col]
                    val r = (c shr 16) and 0xff
                    val g = (c shr 8) and 0xff
                    val b = c and 0xff
                    yRow[col] = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).toByte()
                }
                if (y.pixelStride == 1) {
                    yBuf.position(row * y.rowStride)
                    yBuf.put(yRow)
                } else {
                    for (col in 0 until width) yBuf.put(row * y.rowStride + col * y.pixelStride, yRow[col])
                }
            }
            val u = planes[1]
            val v = planes[2]
            for (row in 0 until height / 2) {
                for (col in 0 until width / 2) {
                    val c = argb[(row * 2) * width + col * 2]
                    val r = (c shr 16) and 0xff
                    val g = (c shr 8) and 0xff
                    val b = c and 0xff
                    u.buffer.put(row * u.rowStride + col * u.pixelStride, (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte())
                    v.buffer.put(row * v.rowStride + col * v.pixelStride, (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte())
                }
            }
        }
    }
}
