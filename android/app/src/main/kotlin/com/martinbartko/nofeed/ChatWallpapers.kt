package com.martinbartko.nofeed

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Custom chat backgrounds (see lib/chat_wallpaper.dart): photos the user picks
 * in the system Photo Picker (no storage permission), scaled down and stored
 * as JPEG in the app's private files folder (never backed up, see
 * data_extraction_rules.xml). File name = "default" or the chat id.
 */
object ChatWallpapers {
    private const val FOLDER = "chat_wallpapers"

    /** Longest side of the stored photo in pixels (a phone screen is enough). */
    private const val MAX_PIXELS = 1600
    private val KEY = Regex("^[A-Za-z0-9_-]{1,64}$")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun isKey(key: String?): Boolean = key != null && KEY.matches(key)

    /** Keys come from lib/chat_wallpaper.dart; checked again so a key can never leave the folder. */
    private fun file(context: Context, key: String): File? =
        if (isKey(key)) File(File(context.filesDir, FOLDER), "$key.jpg") else null

    /** Copies the picked photo [uri] (scaled down) as background [key]. */
    fun save(context: Context, uri: Uri, key: String, done: (Boolean) -> Unit) {
        val file = file(context, key)
        if (file == null) {
            done(false)
            return
        }
        val app = context.applicationContext
        executor.execute {
            val saved = try {
                val bitmap = decode(app, uri)
                if (bitmap == null) {
                    false
                } else {
                    file.parentFile?.mkdirs()
                    val temp = File(file.path + ".tmp")
                    temp.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 80, it) }
                    bitmap.recycle()
                    temp.renameTo(file)
                }
            } catch (e: Exception) {
                false
            } catch (e: OutOfMemoryError) {
                false
            }
            main.post { done(saved) }
        }
    }

    private fun decode(context: Context, uri: Uri): Bitmap? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // Applies the photo's orientation by itself.
            val source = ImageDecoder.createSource(context.contentResolver, uri)
            return ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
                val longest = max(info.size.width, info.size.height)
                if (longest > MAX_PIXELS) {
                    val ratio = MAX_PIXELS.toFloat() / longest
                    decoder.setTargetSize(
                        (info.size.width * ratio).roundToInt().coerceAtLeast(1),
                        (info.size.height * ratio).roundToInt().coerceAtLeast(1),
                    )
                }
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
        }
        // Android 7–8: sampled decode (the orientation tag of the photo is not applied).
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, bounds)
        }
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= MAX_PIXELS) sample *= 2
        val options = BitmapFactory.Options().apply { inSampleSize = sample }
        return context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, options)
        }
    }

    fun load(context: Context, key: String, done: (ByteArray?) -> Unit) {
        val file = file(context, key)
        if (file == null) {
            done(null)
            return
        }
        executor.execute {
            val bytes = try {
                if (file.isFile) file.readBytes() else null
            } catch (e: Exception) {
                null
            }
            main.post { done(bytes) }
        }
    }

    fun remove(context: Context, key: String, done: () -> Unit) {
        val file = file(context, key)
        executor.execute {
            file?.delete()
            main.post { done() }
        }
    }

    /** Keys of all saved backgrounds. */
    fun list(context: Context, done: (List<String>) -> Unit) {
        val folder = File(context.filesDir, FOLDER)
        executor.execute {
            val keys = folder.listFiles()
                ?.filter { it.extension == "jpg" }
                ?.map { it.nameWithoutExtension }
                ?: emptyList()
            main.post { done(keys) }
        }
    }
}
