package com.example.flutter_image_tools

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val channelName = "image_toolkit/local_image"
    private val pickImageRequestCode = 1042
    private val pickMultipleImagesRequestCode = 1043
    private var pendingPickResult: MethodChannel.Result? = null
    private var isMultipleSelection = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handleMethodCall(call, result) }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickSingleImage" -> pickSingleImage(result)
            "pickMultipleImages" -> pickMultipleImages(result)
            "compressImage" -> compressImage(call, result)
            "convertImage" -> convertImage(call, result)
            "flipImage" -> flipImage(call, result)
            "resizeImage" -> resizeImage(call, result)
            "rotateImage" -> rotateImage(call, result)
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
        isMultipleSelection = false
        startActivityForResult(chooser, pickImageRequestCode)
    }

    private fun pickMultipleImages(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "已有图片选择任务正在进行", null)
            return
        }

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(intent, "选择多张图片")
        if (chooser.resolveActivity(packageManager) == null) {
            result.error("activity_missing", "当前设备没有可用的图片选择器", null)
            return
        }

        pendingPickResult = result
        isMultipleSelection = true
        startActivityForResult(chooser, pickMultipleImagesRequestCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickImageRequestCode && requestCode != pickMultipleImagesRequestCode) {
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
            val clipData = data?.clipData
            if (isMultipleSelection && clipData != null && clipData.itemCount > 0) {
                try {
                    val files = mutableListOf<Map<String, Any>>()
                    for (index in 0 until clipData.itemCount) {
                        files.add(copySelectedImage(clipData.getItemAt(index).uri))
                    }
                    result.success(files)
                } catch (error: Exception) {
                    result.error("file_not_found", error.message, null)
                }
            } else {
                result.error("file_not_found", "未获取到图片地址", null)
            }
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
            if (isMultipleSelection) {
                val files = mutableListOf<Map<String, Any>>()
                data?.clipData?.let { clipData ->
                    for (index in 0 until clipData.itemCount) {
                        files.add(copySelectedImage(clipData.getItemAt(index).uri))
                    }
                }
                if (files.isEmpty()) {
                    files.add(copySelectedImage(uri))
                }
                result.success(files)
            } else {
                result.success(copySelectedImage(uri))
            }
        } catch (error: Exception) {
            result.error("file_not_found", error.message, null)
        } finally {
            isMultipleSelection = false
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
            "width" to readImageWidth(output),
            "height" to readImageHeight(output),
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

    private fun rotateImage(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val degrees = call.argument<Int>("degrees") ?: 90
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }
        if (degrees !in -360..360) {
            result.error("invalid_args", "旋转角度必须在 -360 到 360 之间", null)
            return
        }

        val source = File(path)
        if (!source.exists()) {
            result.error("file_not_found", "图片文件不存在", null)
            return
        }

        val bitmap = BitmapFactory.decodeFile(source.absolutePath)
        if (bitmap == null) {
            result.error("invalid_image", "图片格式不支持或文件已损坏", null)
            return
        }

        val matrix = Matrix().apply { postRotate(degrees.toFloat()) }
        val rotatedBitmap = try {
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        } catch (error: Exception) {
            bitmap.recycle()
            result.error("export_failed", error.message, null)
            return
        }

        try {
            val outputDir = File(cacheDir, "rotated_images").apply { mkdirs() }
            val output = File(outputDir, "rotated_${System.currentTimeMillis()}.jpg")
            FileOutputStream(output).use { stream ->
                val success = rotatedBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                if (!success) {
                    result.error("export_failed", "图片旋转导出失败", null)
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
            rotatedBitmap.recycle()
            bitmap.recycle()
        }
    }

    private fun flipImage(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val direction = call.argument<String>("direction") ?: "horizontal"
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }
        if (direction != "horizontal" && direction != "vertical") {
            result.error("invalid_args", "翻转方向必须为水平或垂直", null)
            return
        }

        val source = File(path)
        if (!source.exists()) {
            result.error("file_not_found", "图片文件不存在", null)
            return
        }

        val bitmap = BitmapFactory.decodeFile(source.absolutePath)
        if (bitmap == null) {
            result.error("invalid_image", "图片格式不支持或文件已损坏", null)
            return
        }

        val scaleX = if (direction == "horizontal") -1f else 1f
        val scaleY = if (direction == "vertical") -1f else 1f
        val matrix = Matrix().apply { preScale(scaleX, scaleY) }
        val flippedBitmap = try {
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        } catch (error: Exception) {
            bitmap.recycle()
            result.error("export_failed", error.message, null)
            return
        }

        try {
            val outputDir = File(cacheDir, "flipped_images").apply { mkdirs() }
            val output = File(outputDir, "flipped_${System.currentTimeMillis()}.jpg")
            FileOutputStream(output).use { stream ->
                val success = flippedBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                if (!success) {
                    result.error("export_failed", "图片翻转导出失败", null)
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
            flippedBitmap.recycle()
            bitmap.recycle()
        }
    }

    private fun resizeImage(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val width = call.argument<Int>("width") ?: 0
        val height = call.argument<Int>("height") ?: 0
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }
        if (width !in 1..10000 || height !in 1..10000) {
            result.error("invalid_args", "目标宽高必须在 1 到 10000 像素之间", null)
            return
        }

        val source = File(path)
        if (!source.exists()) {
            result.error("file_not_found", "图片文件不存在", null)
            return
        }

        val bitmap = BitmapFactory.decodeFile(source.absolutePath)
        if (bitmap == null) {
            result.error("invalid_image", "图片格式不支持或文件已损坏", null)
            return
        }

        val resizedBitmap = try {
            Bitmap.createScaledBitmap(bitmap, width, height, true)
        } catch (error: Exception) {
            bitmap.recycle()
            result.error("export_failed", error.message, null)
            return
        }

        try {
            val outputDir = File(cacheDir, "resized_images").apply { mkdirs() }
            val output = File(outputDir, "resized_${System.currentTimeMillis()}.jpg")
            FileOutputStream(output).use { stream ->
                val success = resizedBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                if (!success) {
                    result.error("export_failed", "图片尺寸调整导出失败", null)
                    return
                }
            }
            result.success(
                mapOf(
                    "outputPath" to output.absolutePath,
                    "outputSizeBytes" to output.length(),
                    "width" to width,
                    "height" to height,
                ),
            )
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        } finally {
            resizedBitmap.recycle()
            bitmap.recycle()
        }
    }

    private fun convertImage(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val format = (call.argument<String>("format") ?: "jpg").lowercase()
        val quality = call.argument<Int>("quality") ?: 95
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }
        if (format !in setOf("jpg", "jpeg", "png", "webp", "bmp")) {
            result.error("invalid_args", "目标格式不支持", null)
            return
        }
        if (quality !in 1..100) {
            result.error("invalid_args", "导出质量必须在 1 到 100 之间", null)
            return
        }

        val source = File(path)
        if (!source.exists()) {
            result.error("file_not_found", "图片文件不存在", null)
            return
        }

        val bitmap = BitmapFactory.decodeFile(source.absolutePath)
        if (bitmap == null) {
            result.error("invalid_image", "图片格式不支持或文件已损坏", null)
            return
        }

        val normalizedFormat = if (format == "jpeg") "jpg" else format
        try {
            val outputDir = File(cacheDir, "converted_images").apply { mkdirs() }
            val output = File(
                outputDir,
                "converted_${System.currentTimeMillis()}.$normalizedFormat",
            )
            FileOutputStream(output).use { stream ->
                val success = if (normalizedFormat == "bmp") {
                    writeBitmapAsBmp(bitmap, stream)
                    true
                } else {
                    val compressFormat = compressFormatFor(normalizedFormat)
                    if (compressFormat == null) {
                        false
                    } else {
                        bitmap.compress(compressFormat, quality, stream)
                    }
                }
                if (!success) {
                    result.error("export_failed", "图片格式转换导出失败", null)
                    return
                }
            }
            result.success(
                mapOf(
                    "outputPath" to output.absolutePath,
                    "outputSizeBytes" to output.length(),
                    "format" to normalizedFormat,
                    "mimeType" to mimeTypeForFormat(normalizedFormat),
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

    private fun compressFormatFor(format: String): Bitmap.CompressFormat? {
        return when (format) {
            "jpg" -> Bitmap.CompressFormat.JPEG
            "png" -> Bitmap.CompressFormat.PNG
            "webp" -> if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                Bitmap.CompressFormat.WEBP_LOSSY
            } else {
                @Suppress("DEPRECATION")
                Bitmap.CompressFormat.WEBP
            }
            else -> null
        }
    }

    private fun mimeTypeForFormat(format: String): String {
        return when (format) {
            "jpg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "bmp" -> "image/bmp"
            else -> "image/*"
        }
    }

    private fun writeBitmapAsBmp(bitmap: Bitmap, stream: OutputStream) {
        val width = bitmap.width
        val height = bitmap.height
        val rowSize = ((width * 3 + 3) / 4) * 4
        val imageSize = rowSize * height
        val fileSize = 54 + imageSize
        stream.write(byteArrayOf('B'.code.toByte(), 'M'.code.toByte()))
        writeIntLe(stream, fileSize)
        writeShortLe(stream, 0)
        writeShortLe(stream, 0)
        writeIntLe(stream, 54)
        writeIntLe(stream, 40)
        writeIntLe(stream, width)
        writeIntLe(stream, height)
        writeShortLe(stream, 1)
        writeShortLe(stream, 24)
        writeIntLe(stream, 0)
        writeIntLe(stream, imageSize)
        writeIntLe(stream, 2835)
        writeIntLe(stream, 2835)
        writeIntLe(stream, 0)
        writeIntLe(stream, 0)

        val padding = ByteArray(rowSize - width * 3)
        val row = ByteArray(width * 3)
        for (y in height - 1 downTo 0) {
            var offset = 0
            for (x in 0 until width) {
                val pixel = bitmap.getPixel(x, y)
                row[offset++] = Color.blue(pixel).toByte()
                row[offset++] = Color.green(pixel).toByte()
                row[offset++] = Color.red(pixel).toByte()
            }
            stream.write(row)
            if (padding.isNotEmpty()) {
                stream.write(padding)
            }
        }
    }

    private fun writeIntLe(stream: OutputStream, value: Int) {
        stream.write(value and 0xFF)
        stream.write(value ushr 8 and 0xFF)
        stream.write(value ushr 16 and 0xFF)
        stream.write(value ushr 24 and 0xFF)
    }

    private fun writeShortLe(stream: OutputStream, value: Int) {
        stream.write(value and 0xFF)
        stream.write(value ushr 8 and 0xFF)
    }

    private fun readImageWidth(file: File): Int {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, options)
        return options.outWidth.coerceAtLeast(0)
    }

    private fun readImageHeight(file: File): Int {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, options)
        return options.outHeight.coerceAtLeast(0)
    }

    private data class ImageInfo(val name: String, val mimeType: String)
}
