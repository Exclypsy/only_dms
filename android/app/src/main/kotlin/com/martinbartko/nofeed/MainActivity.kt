package com.martinbartko.nofeed

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.ext.SdkExtensions
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Small platform channel used by lib/native_bridge.dart:
 *  - setSecure: FLAG_SECURE on/off (hide content in recent apps)
 *  - pickMedia: system Photo Picker / document picker, no storage permission
 *  - requestPermissions: runtime camera/microphone permission dialog
 */
class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null
    private var pendingPermissions: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> setSecure(call, result)
                    "pickMedia" -> pickMedia(call, result)
                    "requestPermissions" -> requestMediaPermissions(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun setSecure(call: MethodCall, result: MethodChannel.Result) {
        if (call.argument<Boolean>("secure") == true) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        result.success(null)
    }

    private fun pickMedia(call: MethodCall, result: MethodChannel.Result) {
        // Only one picker at a time; cancel an older request.
        pendingPick?.success(emptyList<String>())
        pendingPick = result

        val kind = call.argument<String>("kind") ?: "document"
        val mimeTypes = call.argument<List<String>>("mimeTypes") ?: emptyList()
        val multiple = call.argument<Boolean>("multiple") ?: false

        val intent = if (kind != "document" && isPhotoPickerAvailable()) {
            Intent(ACTION_PICK_IMAGES).apply {
                when (kind) {
                    "image" -> type = "image/*"
                    "video" -> type = "video/*"
                }
                if (multiple) putExtra(EXTRA_PICK_IMAGES_MAX, MAX_PICKED_ITEMS)
            }
        } else {
            // System document picker: needs no storage permission either.
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                if (mimeTypes.isNotEmpty()) putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            }
        }

        try {
            startActivityForResult(intent, REQUEST_PICK)
        } catch (e: ActivityNotFoundException) {
            pendingPick = null
            result.success(emptyList<String>())
        }
    }

    /** The Photo Picker exists on Android 13+ and on Android 11–12 via a system update. */
    private fun isPhotoPickerAvailable(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                SdkExtensions.getExtensionVersion(Build.VERSION_CODES.R) >= 2)

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK) return
        val result = pendingPick ?: return
        pendingPick = null

        val uris = mutableListOf<String>()
        if (resultCode == RESULT_OK && data != null) {
            val clip = data.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri.toString())
            } else {
                data.data?.let { uris.add(it.toString()) }
            }
        }
        result.success(uris)
    }

    private fun requestMediaPermissions(call: MethodCall, result: MethodChannel.Result) {
        val wanted = buildList {
            if (call.argument<Boolean>("camera") == true) add(Manifest.permission.CAMERA)
            if (call.argument<Boolean>("microphone") == true) add(Manifest.permission.RECORD_AUDIO)
        }
        val missing = wanted.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (wanted.isEmpty()) {
            result.success(false)
            return
        }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        pendingPermissions?.success(false)
        pendingPermissions = result
        requestPermissions(missing.toTypedArray(), REQUEST_PERMISSIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_PERMISSIONS) return
        val result = pendingPermissions ?: return
        pendingPermissions = null
        result.success(
            grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED },
        )
    }

    private companion object {
        const val CHANNEL = "com.martinbartko.nofeed/native"
        const val REQUEST_PICK = 4201
        const val REQUEST_PERMISSIONS = 4202
        const val MAX_PICKED_ITEMS = 10

        // MediaStore.ACTION_PICK_IMAGES / EXTRA_PICK_IMAGES_MAX, written out
        // because the constants are marked API 33 although the picker is also
        // available on Android 11–12 through the SDK extension check above.
        const val ACTION_PICK_IMAGES = "android.provider.action.PICK_IMAGES"
        const val EXTRA_PICK_IMAGES_MAX = "android.provider.extra.PICK_IMAGES_MAX"
    }
}
