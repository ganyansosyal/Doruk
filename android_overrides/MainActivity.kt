package com.editpro.editpro

import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.Contrast
import androidx.media3.effect.HslAdjustment
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.google.common.collect.ImmutableList
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

@UnstableApi
class SharpenEffect(private val amount: Float) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram {
        return SharpenProgram(useHdr, amount)
    }
}

@UnstableApi
class SharpenProgram(useHdr: Boolean, private val amount: Float) :
    BaseGlShaderProgram(useHdr, 1) {
    private val prog: GlProgram
    private var texel = floatArrayOf(0f, 0f)

    init {
        try {
            prog = GlProgram(
                """
                attribute vec4 aFramePosition;
                varying vec2 vTexSamplingCoord;
                void main() {
                    gl_Position = aFramePosition;
                    vTexSamplingCoord = aFramePosition.xy * 0.5 + 0.5;
                }
                """.trimIndent(),
                """
                precision mediump float;
                uniform sampler2D uTexSampler;
                uniform vec2 uTexel;
                uniform float uAmount;
                varying vec2 vTexSamplingCoord;
                void main() {
                    vec4 c = texture2D(uTexSampler, vTexSamplingCoord);
                    vec3 n = texture2D(uTexSampler, vTexSamplingCoord + vec2(uTexel.x, 0.0)).rgb
                           + texture2D(uTexSampler, vTexSamplingCoord - vec2(uTexel.x, 0.0)).rgb
                           + texture2D(uTexSampler, vTexSamplingCoord + vec2(0.0, uTexel.y)).rgb
                           + texture2D(uTexSampler, vTexSamplingCoord - vec2(0.0, uTexel.y)).rgb;
                    vec3 o = c.rgb + uAmount * (4.0 * c.rgb - n);
                    gl_FragColor = vec4(clamp(o, 0.0, 1.0), c.a);
                }
                """.trimIndent()
            )
            prog.setBufferAttribute(
                "aFramePosition",
                GlUtil.getNormalizedCoordinateBounds(),
                GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE
            )
        } catch (e: Exception) {
            throw VideoFrameProcessingException(e)
        }
    }

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        texel = floatArrayOf(1f / inputWidth, 1f / inputHeight)
        return Size(inputWidth, inputHeight)
    }

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            prog.use()
            prog.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
            prog.setFloatsUniform("uTexel", texel)
            prog.setFloatUniform("uAmount", amount)
            prog.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        } catch (e: Exception) {
            throw VideoFrameProcessingException(e)
        }
    }

    override fun release() {
        super.release()
        try {
            prog.delete()
        } catch (e: Exception) {
            throw VideoFrameProcessingException(e)
        }
    }
}

class Cap(val text: String, val start: Long, val end: Long)

@UnstableApi
class SubtitleOverlay(
    private val caps: List<Cap>,
    private val w: Int,
    private val h: Int
) : BitmapOverlay() {
    private val empty: Bitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
    private var cachedIdx = -2
    private var cached: Bitmap = empty

    override fun getBitmap(presentationTimeUs: Long): Bitmap {
        val ms = presentationTimeUs / 1000
        var idx = -1
        for (i in caps.indices) {
            val c = caps[i]
            if (ms >= c.start && ms < c.end) {
                idx = i
                break
            }
        }
        if (idx != cachedIdx) {
            cachedIdx = idx
            cached = if (idx < 0) empty else make(caps[idx].text)
        }
        return cached
    }

    private fun make(text: String): Bitmap {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val tp = TextPaint(Paint.ANTI_ALIAS_FLAG)
        tp.color = Color.WHITE
        tp.textSize = w * 0.05f
        tp.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        val maxW = (w * 0.9f).toInt()
        val layout = StaticLayout.Builder
            .obtain(text, 0, text.length, tp, maxW)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .build()
        var tw = 0f
        for (i in 0 until layout.lineCount) {
            tw = maxOf(tw, layout.getLineWidth(i))
        }
        val padX = tp.textSize * 0.4f
        val padY = tp.textSize * 0.15f
        val boxW = tw + 2 * padX
        val boxH = layout.height + 2 * padY
        val left = (w - boxW) / 2f
        val top = h - h * 0.06f - boxH
        val bg = Paint(Paint.ANTI_ALIAS_FLAG)
        bg.color = 0x99000000.toInt()
        canvas.drawRoundRect(left, top, left + boxW, top + boxH, 6f, 6f, bg)
        canvas.save()
        canvas.translate((w - maxW) / 2f, top + padY)
        layout.draw(canvas)
        canvas.restore()
        return bmp
    }
}

@UnstableApi
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var transformer: Transformer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var poll: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "editpro/video")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            if (call.method == "export") export(call, result) else result.notImplemented()
        }
    }

    private fun export(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")!!
            val reqH = call.argument<Int>("height") ?: 720
            val enhance = call.argument<Boolean>("enhance") ?: false
            val raw = call.argument<List<Map<String, Any>>>("caps") ?: emptyList()
            val caps = raw.map {
                Cap(
                    it["text"] as String,
                    (it["start"] as Number).toLong(),
                    (it["end"] as Number).toLong()
                )
            }

            val r = MediaMetadataRetriever()
            r.setDataSource(path)
            var sw = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)!!.toInt()
            var sh = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)!!.toInt()
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
            r.release()
            if (rot == 90 || rot == 270) {
                val t = sw; sw = sh; sh = t
            }

            val outH = (reqH / 2) * 2
            val outW = ((outH.toLong() * sw / sh).toInt() / 2) * 2
            val bitrate = when {
                outH >= 1400 -> 16_000_000
                outH >= 1000 -> 10_000_000
                else -> 5_000_000
            }

            val list = mutableListOf<Effect>(Presentation.createForHeight(outH))
            if (enhance) {
                list.add(SharpenEffect(0.6f))
                list.add(Contrast(0.12f))
                list.add(HslAdjustment.Builder().adjustSaturation(18f).build())
            }
            list.add(OverlayEffect(ImmutableList.of<TextureOverlay>(SubtitleOverlay(caps, outW, outH))))
            val effects = Effects(emptyList<AudioProcessor>(), list)
            val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(path))))
                .setEffects(effects)
                .build()

            val out = File(cacheDir, "editpro_${System.currentTimeMillis()}.mp4")
            val encoder = DefaultEncoderFactory.Builder(this)
                .setRequestedVideoEncoderSettings(
                    VideoEncoderSettings.Builder().setBitrate(bitrate).build()
                )
                .build()

            val t = Transformer.Builder(this)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoder)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        stopPoll()
                        result.success(out.absolutePath)
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        stopPoll()
                        result.error("EXPORT", exportException.message ?: "Dışa aktarma hatası", null)
                    }
                })
                .build()
            transformer = t
            t.start(item, out.absolutePath)

            val holder = ProgressHolder()
            val p = object : Runnable {
                override fun run() {
                    val tr = transformer ?: return
                    if (tr.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                        channel?.invokeMethod("progress", holder.progress)
                    }
                    handler.postDelayed(this, 500)
                }
            }
            poll = p
            handler.postDelayed(p, 500)
        } catch (e: Exception) {
            result.error("EXPORT", e.message ?: "Hata", null)
        }
    }

    private fun stopPoll() {
        poll?.let { handler.removeCallbacks(it) }
        poll = null
        transformer = null
    }
}
