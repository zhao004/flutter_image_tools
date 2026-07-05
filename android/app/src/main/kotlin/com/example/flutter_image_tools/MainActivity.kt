package com.example.flutter_image_tools

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "image_toolkit/local_image"
    private val pickImageRequestCode = 1042
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handleMethodCall(call, result) }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickSingleImage" -> pickSingleImage(result)
            "compressImage" -> compressImage(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickSingleImage(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "已有图片选择任务正在进行", null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(intent, "选择图片")
        if (chooser.resolveActivity(packageManager) == null) {
            result.error("activity_missing", "当前设备没有可用的图片选择器", null)
            return
        }

        pendingPickResult = result
        startActivityForResult(chooser, pickImageRequestCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickImageRequestCode) {
            return
        }

        val result = pendingPickResult ?: return
        pendingPickResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.error("file_not_found", "未获取到图片地址", null)
            return
        }

        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // 某些系统选择器不支持持久授权，当前会话仍可通过流复制文件。
        }

        try {
            result.success(copySelectedImage(uri))
        } catch (error: Exception) {
            result.error("file_not_found", error.message, null)
        }
    }

    private fun copySelectedImage(uri: Uri): Map<String, Any> {
        val info = queryImageInfo(uri)
        val extension = extensionForMime(info.mimeType)
        val inputDir = File(cacheDir, "selected_images").apply { mkdirs() }
        val output = File(inputDir, "${UUID.randomUUID()}.$extension")

        contentResolver.openInputStream(uri).use { input ->
            if (input == null) {
                throw IllegalStateException("无法读取图片内容")
            }
            FileOutputStream(output).use { outputStream -> input.copyTo(outputStream) }
        }

        return mapOf(
            "path" to output.absolutePath,
            "name" to info.name,
            "sizeBytes" to output.length(),
            "mimeType" to info.mimeType,
        )
    }

    private fun compressImage(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val quality = call.argument<Int>("quality") ?: 80
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }
        if (quality !in 1..100) {
            result.error("invalid_args", "压缩质量必须在 1 到 100 之间", null)
            return
        }

        val source = File(path)
        if (!source.exists()) {
            result.error("file_not_found", "图片文件不存在", null)
            return
        }

        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        val bitmap = BitmapFactory.decodeFile(source.absolutePath, options)
        if (bitmap == null) {
            result.error("invalid_image", "图片格式不支持或文件已损坏", null)
            return
        }

        try {
            val outputDir = File(cacheDir, "compressed_images").apply { mkdirs() }
            val output = File(outputDir, "compressed_${System.currentTimeMillis()}.jpg")
            FileOutputStream(output).use { stream ->
                val success = bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
                if (!success) {
                    result.error("export_failed", "图片压缩失败", null)
                    return
                }
            }
            result.success(
                mapOf(
                    "outputPath" to output.absolutePath,
                    "outputSizeBytes" to output.length(),
                ),
            )
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        } finally {
            bitmap.recycle()
        }
    }

    private fun queryImageInfo(uri: Uri): ImageInfo {
        var name = "selected_image"
        var mimeType = contentResolver.getType(uri) ?: "image/*"
        contentResolver.query(uri, null, null, null, null).use { cursor ->
            if (cursor != null && cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) {
                    name = cursor.getString(nameIndex) ?: name
                }
            }
        }

        if (mimeType == "image/*") {
            mimeType = when (name.substringAfterLast('.', "").lowercase()) {
                "jpg", "jpeg" -> "image/jpeg"
                "png" -> "image/png"
                "webp" -> "image/webp"
                "bmp" -> "image/bmp"
                else -> mimeType
            }
        }
        return ImageInfo(name = name, mimeType = mimeType)
    }

    private fun extensionForMime(mimeType: String): String {
        return when (mimeType.lowercase()) {
            "image/jpeg" -> "jpg"
            "image/png" -> "png"
            "image/webp" -> "webp"
            "image/bmp" -> "bmp"
            else -> "img"
        }
    }

    private data class ImageInfo(val name: String, val mimeType: String)
}
