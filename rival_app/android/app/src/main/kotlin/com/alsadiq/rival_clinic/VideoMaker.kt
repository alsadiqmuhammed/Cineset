package com.alsadiq.rival_clinic

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File

/**
 * Encodes a before -> after transition to H.264 MP4: hold "before", cross-dissolve
 * to "after" while slowly zooming in, then hold "after". Frames are given as two
 * PNGs of the same size (already aligned by the Flutter side); the optional overlay
 * PNG (clinic frame) is drawn on top of every frame without the zoom.
 */
object VideoMaker {
    private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
    private const val TIMEOUT_US = 10_000L

    fun make(
        beforePath: String,
        afterPath: String,
        overlayPath: String?,
        outPath: String,
        holdBefore: Double,
        morph: Double,
        holdAfter: Double,
        fps: Int,
    ): String {
        val before = BitmapFactory.decodeFile(beforePath) ?: error("Cannot read $beforePath")
        val after = BitmapFactory.decodeFile(afterPath) ?: error("Cannot read $afterPath")
        val overlay = overlayPath?.let { BitmapFactory.decodeFile(it) }
        // Encoders want even sizes; most also prefer multiples of 16 but accept 1080.
        val width = before.width and 1.inv()
        val height = before.height and 1.inv()
        try {
            return encode(before, after, overlay, width, height, outPath, holdBefore, morph, holdAfter, fps)
        } catch (e: Exception) {
            // Some encoders reject 1080x1920 in portrait; retry at 720p.
            val w = 720
            val h = ((height.toDouble() * w / width).toInt()) and 1.inv()
            File(outPath).delete()
            return encode(before, after, overlay, w, h, outPath, holdBefore, morph, holdAfter, fps)
        } finally {
            before.recycle()
            after.recycle()
            overlay?.recycle()
        }
    }

    private fun encode(
        before: Bitmap,
        after: Bitmap,
        overlay: Bitmap?,
        width: Int,
        height: Int,
        outPath: String,
        holdBefore: Double,
        morph: Double,
        holdAfter: Double,
        fps: Int,
    ): String {
        val format = MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, width * height * 6)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        val codec = MediaCodec.createEncoderByType(MIME)
        val muxer = MediaMuxer(outPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var track = -1
        var muxing = false
        val info = MediaCodec.BufferInfo()

        val total = ((holdBefore + morph + holdAfter) * fps).toInt()
        val frame = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(frame)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        val argb = IntArray(width * height)

        fun drain(endOfStream: Boolean) {
            while (true) {
                val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                when {
                    index == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!endOfStream) return
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxing = true
                    }
                    index >= 0 -> {
                        val buffer = codec.getOutputBuffer(index)!!
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (info.size > 0 && muxing) {
                            buffer.position(info.offset)
                            buffer.limit(info.offset + info.size)
                            muxer.writeSampleData(track, buffer, info)
                        }
                        codec.releaseOutputBuffer(index, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }

        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            var i = 0
            while (i <= total) {
                val index = codec.dequeueInputBuffer(TIMEOUT_US)
                if (index < 0) {
                    drain(false)
                    continue
                }
                val pts = i * 1_000_000L / fps
                if (i == total) {
                    codec.queueInputBuffer(index, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                } else {
                    val t = i.toDouble() / fps
                    val mix = smoothstep(((t - holdBefore) / morph).coerceIn(0.0, 1.0))
                    val zoom = 1.0 + 0.06 * (i.toDouble() / total)
                    drawFrame(canvas, paint, before, after, overlay, width, height, mix, zoom)
                    frame.getPixels(argb, 0, width, 0, 0, width, height)
                    val image = codec.getInputImage(index)!!
                    writeYuv(argb, width, height, image)
                    codec.queueInputBuffer(index, 0, width * height * 3 / 2, pts, 0)
                }
                i++
                drain(false)
            }
            drain(true)
        } finally {
            frame.recycle()
            runCatching { codec.stop() }
            codec.release()
            if (muxing) runCatching { muxer.stop() }
            muxer.release()
        }
        return outPath
    }

    private fun smoothstep(x: Double) = x * x * (3 - 2 * x)

    private fun drawFrame(
        canvas: Canvas,
        paint: Paint,
        before: Bitmap,
        after: Bitmap,
        overlay: Bitmap?,
        width: Int,
        height: Int,
        mix: Double,
        zoom: Double,
    ) {
        canvas.save()
        canvas.scale(zoom.toFloat(), zoom.toFloat(), width / 2f, height / 2f)
        canvas.scale(width.toFloat() / before.width, height.toFloat() / before.height)
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
            canvas.scale(width.toFloat() / overlay.width, height.toFloat() / overlay.height)
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
        val uBuf = u.buffer
        val vBuf = v.buffer
        for (row in 0 until height / 2) {
            for (col in 0 until width / 2) {
                val c = argb[(row * 2) * width + col * 2]
                val r = (c shr 16) and 0xff
                val g = (c shr 8) and 0xff
                val b = c and 0xff
                uBuf.put(
                    row * u.rowStride + col * u.pixelStride,
                    (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).toByte(),
                )
                vBuf.put(
                    row * v.rowStride + col * v.pixelStride,
                    (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).toByte(),
                )
            }
        }
    }
}
