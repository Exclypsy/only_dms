package com.martinbartko.nofeed

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Handler
import android.os.Looper
import android.webkit.WebView
import java.io.File
import java.util.concurrent.Executors

/**
 * Pictures of opened chats for instant opening (see lib/chat_snapshot.dart).
 * Stored only in the app's private cache folder (never backed up, the system
 * may purge it), at most [MAX_COUNT] chats; deleted on logout.
 */
object ChatSnapshots {
    private const val MAX_COUNT = 30
    private const val FOLDER = "chat_snapshots"
    private val KEY = Regex("^[A-Za-z0-9_-]{1,80}$")
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    /** Keys come from lib/chat_snapshot.dart; checked again so a key can never leave the folder. */
    private fun file(context: Context, key: String): File? =
        if (KEY.matches(key)) File(File(context.cacheDir, FOLDER), "$key.jpg") else null

    /** Must be called on the main thread (draws the WebView). */
    fun save(context: Context, webView: WebView, key: String, done: (Boolean) -> Unit) {
        val file = file(context, key)
        if (file == null || !webView.isShown || webView.width <= 0 || webView.height <= 100) {
            done(false)
            return
        }
        val bitmap = try {
            Bitmap.createBitmap(webView.width, webView.height, Bitmap.Config.ARGB_8888)
                .also { webView.draw(Canvas(it)) }
        } catch (e: OutOfMemoryError) {
            done(false)
            return
        }
        executor.execute {
            val saved = try {
                file.parentFile?.mkdirs()
                val temp = File(file.path + ".tmp")
                temp.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 82, it) }
                temp.renameTo(file).also { prune(file.parentFile) }
            } catch (e: Exception) {
                false
            } finally {
                bitmap.recycle()
            }
            main.post { done(saved) }
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

    fun clear(context: Context) {
        val folder = File(context.cacheDir, FOLDER)
        executor.execute { folder.deleteRecursively() }
    }

    /** Keeps the most recently saved [MAX_COUNT] pictures. */
    private fun prune(folder: File?) {
        val files = folder?.listFiles() ?: return
        files.sortedByDescending { it.lastModified() }.drop(MAX_COUNT).forEach { it.delete() }
    }
}
