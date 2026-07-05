package com.example.flutter_image_tools

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import android.media.ExifInterface
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
            "cropImage" -> cropImage(call, result)
            "applyFilter" -> applyFilter(call, result)
            "flipImage" -> flipImage(call, result)
            "mergeImages" -> mergeImages(call, result)
            "splitGridImage" -> splitGridImage(call, result)
            "resizeImage" -> resizeImage(call, result)
            "rotateImage" -> rotateImage(call, result)
            "addTextWatermark" -> addTextWatermark(call, result)
            "addImageWatermark" -> addImageWatermark(call, result)
            "readExif" -> readExif(call, result)
            "removeExif" -> removeExif(call, result)
            "imagesToPdf" -> imagesToPdf(call, result)
            "annotateImage" -> annotateImage(call, result)
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

    private fun cropImage(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val aspectRatio = call.argument<Double>("aspectRatio") ?: 1.0
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }
        if (aspectRatio < 0.1 || aspectRatio > 10.0) {
            result.error("invalid_args", "裁剪比例必须在 0.1 到 10 之间", null)
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

        val sourceRatio = bitmap.width.toDouble() / bitmap.height.toDouble()
        val cropWidth: Int
        val cropHeight: Int
        if (sourceRatio > aspectRatio) {
            cropHeight = bitmap.height
            cropWidth = (cropHeight * aspectRatio).toInt().coerceIn(1, bitmap.width)
        } else {
            cropWidth = bitmap.width
            cropHeight = (cropWidth / aspectRatio).toInt().coerceIn(1, bitmap.height)
        }
        val cropX = ((bitmap.width - cropWidth) / 2).coerceAtLeast(0)
        val cropY = ((bitmap.height - cropHeight) / 2).coerceAtLeast(0)
        val croppedBitmap = try {
            Bitmap.createBitmap(bitmap, cropX, cropY, cropWidth, cropHeight)
        } catch (error: Exception) {
            bitmap.recycle()
            result.error("export_failed", error.message, null)
            return
        }

        try {
            val outputDir = File(cacheDir, "cropped_images").apply { mkdirs() }
            val output = File(outputDir, "cropped_${System.currentTimeMillis()}.jpg")
            FileOutputStream(output).use { stream ->
                val success = croppedBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                if (!success) {
                    result.error("export_failed", "图片裁剪导出失败", null)
                    return
                }
            }
            result.success(
                mapOf(
                    "outputPath" to output.absolutePath,
                    "outputSizeBytes" to output.length(),
                    "width" to cropWidth,
                    "height" to cropHeight,
                    "aspectRatio" to aspectRatio,
                ),
            )
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        } finally {
            croppedBitmap.recycle()
            bitmap.recycle()
        }
    }

    private fun mergeImages(call: MethodCall, result: MethodChannel.Result) {
        val paths = call.argument<List<String>>("paths") ?: emptyList()
        val mode = (call.argument<String>("mode") ?: "horizontal").lowercase()
        val columns = call.argument<Int>("columns") ?: 2
        val spacing = call.argument<Int>("spacing") ?: 8
        if (paths.size < 2 || paths.size > 20) {
            result.error("invalid_args", "拼接图片数量必须在 2 到 20 张之间", null)
            return
        }
        if (mode !in setOf("horizontal", "vertical", "grid")) {
            result.error("invalid_args", "拼接模式无效", null)
            return
        }
        if (columns !in 1..10 || spacing !in 0..100) {
            result.error("invalid_args", "拼接参数超出范围", null)
            return
        }

        val bitmaps = mutableListOf<Bitmap>()
        try {
            for (path in paths) {
                if (path.isBlank()) {
                    result.error("file_not_found", "图片路径为空", null)
                    bitmaps.forEach { it.recycle() }
                    return
                }
                val source = File(path)
                if (!source.exists()) {
                    result.error("file_not_found", "图片文件不存在", null)
                    bitmaps.forEach { it.recycle() }
                    return
                }
                val bitmap = BitmapFactory.decodeFile(source.absolutePath)
                if (bitmap == null) {
                    result.error("invalid_image", "图片格式不支持或文件已损坏", null)
                    bitmaps.forEach { it.recycle() }
                    return
                }
                bitmaps.add(bitmap)
            }

            val layout = calculateMergeLayout(bitmaps, mode, columns, spacing)
            if (layout.width <= 0 || layout.height <= 0) {
                result.error("invalid_args", "拼接输出尺寸无效", null)
                bitmaps.forEach { it.recycle() }
                return
            }
            val pixelCount = layout.width.toLong() * layout.height.toLong()
            if (layout.width > 20000 || layout.height > 20000 || pixelCount > 36000000L) {
                result.error("invalid_args", "拼接输出过大，请减少图片数量或尺寸", null)
                bitmaps.forEach { it.recycle() }
                return
            }

            val mergedBitmap = Bitmap.createBitmap(
                layout.width,
                layout.height,
                Bitmap.Config.ARGB_8888,
            )
            val canvas = Canvas(mergedBitmap)
            canvas.drawColor(Color.WHITE)
            for (index in bitmaps.indices) {
                val bitmap = bitmaps[index]
                val position = layout.positions[index]
                canvas.drawBitmap(bitmap, position.x.toFloat(), position.y.toFloat(), null)
            }

            try {
                val outputDir = File(cacheDir, "merged_images").apply { mkdirs() }
                val output = File(outputDir, "merged_${System.currentTimeMillis()}.jpg")
                FileOutputStream(output).use { stream ->
                    val success = mergedBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                    if (!success) {
                        result.error("export_failed", "图片拼接导出失败", null)
                        return
                    }
                }
                result.success(
                    mapOf(
                        "outputPath" to output.absolutePath,
                        "outputSizeBytes" to output.length(),
                        "width" to layout.width,
                        "height" to layout.height,
                        "mode" to mode,
                    ),
                )
            } catch (error: Exception) {
                result.error("export_failed", error.message, null)
            } finally {
                mergedBitmap.recycle()
                bitmaps.forEach { it.recycle() }
            }
        } catch (error: Exception) {
            bitmaps.forEach { it.recycle() }
            result.error("export_failed", error.message, null)
        }
    }

    private fun imagesToPdf(call: MethodCall, result: MethodChannel.Result) {
        val paths = call.argument<List<String>>("paths") ?: emptyList()
        val pageSize = (call.argument<String>("pageSize") ?: "a4").lowercase()
        val orientation = (call.argument<String>("orientation") ?: "portrait").lowercase()
        if (paths.isEmpty() || paths.size > 50) {
            result.error("invalid_args", "PDF 图片数量必须在 1 到 50 张之间", null)
            return
        }
        if (pageSize !in setOf("a4", "a3") || orientation !in setOf("portrait", "landscape")) {
            result.error("invalid_args", "PDF 页面参数无效", null)
            return
        }

        val pagePointSize = pdfPagePointSize(pageSize, orientation)
        val pdfDocument = PdfDocument()
        try {
            for (index in paths.indices) {
                val path = paths[index]
                if (path.isBlank()) {
                    result.error("file_not_found", "图片路径为空", null)
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
                try {
                    val pageInfo = PdfDocument.PageInfo.Builder(
                        pagePointSize.first,
                        pagePointSize.second,
                        index + 1,
                    ).create()
                    val page = pdfDocument.startPage(pageInfo)
                    page.canvas.drawColor(Color.WHITE)
                    drawBitmapCenteredInPdfPage(
                        bitmap,
                        page.canvas,
                        pagePointSize.first,
                        pagePointSize.second,
                    )
                    pdfDocument.finishPage(page)
                } finally {
                    bitmap.recycle()
                }
            }

            val outputDir = File(cacheDir, "pdf_documents").apply { mkdirs() }
            val output = File(outputDir, "images_${System.currentTimeMillis()}.pdf")
            FileOutputStream(output).use { stream -> pdfDocument.writeTo(stream) }
            result.success(
                mapOf(
                    "outputPath" to output.absolutePath,
                    "outputSizeBytes" to output.length(),
                    "pageSize" to pageSize,
                    "orientation" to orientation,
                    "pageCount" to paths.size,
                ),
            )
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        } finally {
            pdfDocument.close()
        }
    }

    private fun annotateImage(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val mode = (call.argument<String>("mode") ?: "brush").lowercase()
        val text = call.argument<String>("text")?.trim() ?: ""
        val annotationColor = call.argument<String>("color") ?: "#E53935"
        val strokeWidth = call.argument<Int>("strokeWidth") ?: 12
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }
        if (mode !in setOf("brush", "arrow", "rectangle", "circle", "text", "highlight", "mosaic")) {
            result.error("invalid_args", "标注模式无效", null)
            return
        }
        if (mode == "text" && text.isBlank()) {
            result.error("invalid_args", "文本标注内容不能为空", null)
            return
        }
        if (text.length > 40 || strokeWidth !in 2..48) {
            result.error("invalid_args", "标注参数超出范围", null)
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
        val outputBitmap = try {
            bitmap.copy(Bitmap.Config.ARGB_8888, true)
        } catch (error: Exception) {
            bitmap.recycle()
            result.error("export_failed", error.message, null)
            return
        }

        try {
            drawAnnotation(outputBitmap, mode, text, annotationColor, strokeWidth)
            val outputDir = File(cacheDir, "annotated_images").apply { mkdirs() }
            val output = File(outputDir, "annotated_${System.currentTimeMillis()}.jpg")
            FileOutputStream(output).use { stream ->
                val success = outputBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                if (!success) {
                    result.error("export_failed", "图片标注导出失败", null)
                    return
                }
            }
            result.success(
                mapOf(
                    "outputPath" to output.absolutePath,
                    "outputSizeBytes" to output.length(),
                    "mode" to mode,
                ),
            )
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        } finally {
            outputBitmap.recycle()
            bitmap.recycle()
        }
    }

    private fun addTextWatermark(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val text = call.argument<String>("text")?.trim() ?: ""
        val position = (call.argument<String>("position") ?: "bottomRight").lowercase()
        val fontSize = call.argument<Int>("fontSize") ?: 36
        val opacity = call.argument<Int>("opacity") ?: 70
        val watermarkColor = call.argument<String>("color") ?: "#FFFFFF"
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }
        if (text.isBlank() || text.length > 80) {
            result.error("invalid_args", "水印文字不能为空且不能超过 80 个字符", null)
            return
        }
        if (position !in setOf("topleft", "topright", "bottomleft", "bottomright", "center", "tile")) {
            result.error("invalid_args", "水印位置无效", null)
            return
        }
        if (fontSize !in 12..160 || opacity !in 10..100) {
            result.error("invalid_args", "水印字号或透明度超出范围", null)
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

        val outputBitmap = try {
            bitmap.copy(Bitmap.Config.ARGB_8888, true)
        } catch (error: Exception) {
            bitmap.recycle()
            result.error("export_failed", error.message, null)
            return
        }

        try {
            val canvas = Canvas(outputBitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                textSize = fontSize.toFloat()
                this.color = parseWatermarkColor(watermarkColor, opacity)
                setShadowLayer(3f, 1.5f, 1.5f, Color.argb((opacity * 2.0).toInt().coerceIn(0, 160), 0, 0, 0))
            }
            if (position == "tile") {
                drawTiledWatermark(canvas, text, paint, outputBitmap.width, outputBitmap.height, fontSize)
            } else {
                drawSingleWatermark(canvas, text, paint, outputBitmap.width, outputBitmap.height, position, fontSize)
            }

            val outputDir = File(cacheDir, "watermarked_images").apply { mkdirs() }
            val output = File(outputDir, "watermarked_${System.currentTimeMillis()}.jpg")
            FileOutputStream(output).use { stream ->
                val success = outputBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                if (!success) {
                    result.error("export_failed", "文字水印导出失败", null)
                    return
                }
            }
            result.success(
                mapOf(
                    "outputPath" to output.absolutePath,
                    "outputSizeBytes" to output.length(),
                    "position" to position,
                ),
            )
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        } finally {
            outputBitmap.recycle()
            bitmap.recycle()
        }
    }

    private fun addImageWatermark(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val watermarkPath = call.argument<String>("watermarkPath")
        val position = (call.argument<String>("position") ?: "bottomright").lowercase()
        val opacity = call.argument<Int>("opacity") ?: 70
        val scalePercent = call.argument<Int>("scalePercent") ?: 25
        val rotationDegrees = call.argument<Int>("rotationDegrees") ?: 0
        if (path.isNullOrBlank() || watermarkPath.isNullOrBlank()) {
            result.error("file_not_found", "底图或水印图片路径为空", null)
            return
        }
        if (position !in setOf("topleft", "topright", "bottomleft", "bottomright", "center", "tile")) {
            result.error("invalid_args", "水印位置无效", null)
            return
        }
        if (opacity !in 10..100 || scalePercent !in 5..100 || rotationDegrees !in -180..180) {
            result.error("invalid_args", "图片水印参数超出范围", null)
            return
        }

        val source = File(path)
        val watermarkFile = File(watermarkPath)
        if (!source.exists() || !watermarkFile.exists()) {
            result.error("file_not_found", "底图或水印图片不存在", null)
            return
        }

        val bitmap = BitmapFactory.decodeFile(source.absolutePath)
        val watermarkBitmap = BitmapFactory.decodeFile(watermarkFile.absolutePath)
        if (bitmap == null || watermarkBitmap == null) {
            bitmap?.recycle()
            watermarkBitmap?.recycle()
            result.error("invalid_image", "图片格式不支持或文件已损坏", null)
            return
        }

        val outputBitmap = try {
            bitmap.copy(Bitmap.Config.ARGB_8888, true)
        } catch (error: Exception) {
            bitmap.recycle()
            watermarkBitmap.recycle()
            result.error("export_failed", error.message, null)
            return
        }

        val scaledWatermark = try {
            scaleWatermarkBitmap(watermarkBitmap, outputBitmap.width, outputBitmap.height, scalePercent)
        } catch (error: Exception) {
            outputBitmap.recycle()
            bitmap.recycle()
            watermarkBitmap.recycle()
            result.error("export_failed", error.message, null)
            return
        }
        val transformedWatermark = try {
            rotateWatermarkBitmap(scaledWatermark, rotationDegrees)
        } catch (error: Exception) {
            scaledWatermark.recycle()
            outputBitmap.recycle()
            bitmap.recycle()
            watermarkBitmap.recycle()
            result.error("export_failed", error.message, null)
            return
        }
        if (transformedWatermark !== scaledWatermark) {
            scaledWatermark.recycle()
        }

        try {
            val canvas = Canvas(outputBitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                alpha = (opacity * 255 / 100).coerceIn(0, 255)
            }
            if (position == "tile") {
                drawTiledImageWatermark(canvas, transformedWatermark, paint, outputBitmap.width, outputBitmap.height)
            } else {
                drawSingleImageWatermark(canvas, transformedWatermark, paint, outputBitmap.width, outputBitmap.height, position)
            }

            val outputDir = File(cacheDir, "image_watermarked_images").apply { mkdirs() }
            val output = File(outputDir, "image_watermarked_${System.currentTimeMillis()}.jpg")
            FileOutputStream(output).use { stream ->
                val success = outputBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                if (!success) {
                    result.error("export_failed", "图片水印导出失败", null)
                    return
                }
            }
            result.success(
                mapOf(
                    "outputPath" to output.absolutePath,
                    "outputSizeBytes" to output.length(),
                    "position" to position,
                    "opacity" to opacity,
                    "scalePercent" to scalePercent,
                    "rotationDegrees" to rotationDegrees,
                ),
            )
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        } finally {
            transformedWatermark.recycle()
            outputBitmap.recycle()
            bitmap.recycle()
            watermarkBitmap.recycle()
        }
    }

    private fun splitGridImage(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val gridSize = call.argument<Int>("gridSize") ?: 3
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }
        if (gridSize !in 2..5) {
            result.error("invalid_args", "网格大小必须在 2 到 5 之间", null)
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
        if (bitmap.width < gridSize || bitmap.height < gridSize) {
            bitmap.recycle()
            result.error("invalid_args", "图片宽高不能小于网格数量", null)
            return
        }

        val outputPaths = mutableListOf<String>()
        try {
            val outputDir = File(
                File(cacheDir, "grid_images").apply { mkdirs() },
                "grid_${System.currentTimeMillis()}",
            ).apply { mkdirs() }
            var totalSizeBytes = 0L
            var pieceIndex = 1
            for (row in 0 until gridSize) {
                val top = bitmap.height * row / gridSize
                val bottom = bitmap.height * (row + 1) / gridSize
                for (column in 0 until gridSize) {
                    val left = bitmap.width * column / gridSize
                    val right = bitmap.width * (column + 1) / gridSize
                    val pieceWidth = right - left
                    val pieceHeight = bottom - top
                    val pieceBitmap = Bitmap.createBitmap(
                        bitmap,
                        left,
                        top,
                        pieceWidth,
                        pieceHeight,
                    )
                    try {
                        val output = File(
                            outputDir,
                            "piece_${pieceIndex.toString().padStart(2, '0')}.jpg",
                        )
                        FileOutputStream(output).use { stream ->
                            val success = pieceBitmap.compress(
                                Bitmap.CompressFormat.JPEG,
                                95,
                                stream,
                            )
                            if (!success) {
                                result.error("export_failed", "图片切片导出失败", null)
                                return
                            }
                        }
                        outputPaths.add(output.absolutePath)
                        totalSizeBytes += output.length()
                        pieceIndex += 1
                    } finally {
                        pieceBitmap.recycle()
                    }
                }
            }
            result.success(
                mapOf(
                    "outputDirectory" to outputDir.absolutePath,
                    "outputPaths" to outputPaths,
                    "outputSizeBytes" to totalSizeBytes,
                    "gridSize" to gridSize,
                    "pieceCount" to outputPaths.size,
                ),
            )
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        } finally {
            bitmap.recycle()
        }
    }

    private fun applyFilter(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val filter = (call.argument<String>("filter") ?: "grayscale").lowercase()
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }
        if (filter !in setOf("grayscale", "monochrome", "sepia", "invert", "warm", "cool")) {
            result.error("invalid_args", "滤镜类型不支持", null)
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
        val pixelCount = bitmap.width.toLong() * bitmap.height.toLong()
        if (pixelCount > 36000000L) {
            bitmap.recycle()
            result.error("invalid_args", "图片过大，请先调整尺寸后再应用滤镜", null)
            return
        }

        val outputBitmap = try {
            applyBitmapFilter(bitmap, filter)
        } catch (error: Exception) {
            bitmap.recycle()
            result.error("export_failed", error.message, null)
            return
        }

        try {
            val outputDir = File(cacheDir, "filtered_images").apply { mkdirs() }
            val output = File(outputDir, "filtered_${System.currentTimeMillis()}.jpg")
            FileOutputStream(output).use { stream ->
                val success = outputBitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                if (!success) {
                    result.error("export_failed", "图片滤镜导出失败", null)
                    return
                }
            }
            result.success(
                mapOf(
                    "outputPath" to output.absolutePath,
                    "outputSizeBytes" to output.length(),
                    "filter" to filter,
                ),
            )
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        } finally {
            outputBitmap.recycle()
            bitmap.recycle()
        }
    }

    private fun readExif(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
            return
        }

        val source = File(path)
        if (!source.exists()) {
            result.error("file_not_found", "图片文件不存在", null)
            return
        }

        try {
            val exif = ExifInterface(source.absolutePath)
            val attributes = linkedMapOf<String, String>()
            addExifAttribute(attributes, "拍摄时间", exif, ExifInterface.TAG_DATETIME_ORIGINAL)
            addExifAttribute(attributes, "修改时间", exif, ExifInterface.TAG_DATETIME)
            addExifAttribute(attributes, "相机品牌", exif, ExifInterface.TAG_MAKE)
            addExifAttribute(attributes, "相机型号", exif, ExifInterface.TAG_MODEL)
            addExifAttribute(attributes, "方向", exif, ExifInterface.TAG_ORIENTATION)
            addExifAttribute(attributes, "闪光灯", exif, ExifInterface.TAG_FLASH)
            addExifAttribute(attributes, "ISO", exif, ExifInterface.TAG_ISO_SPEED_RATINGS)
            addExifAttribute(attributes, "光圈", exif, ExifInterface.TAG_F_NUMBER)
            addExifAttribute(attributes, "曝光时间", exif, ExifInterface.TAG_EXPOSURE_TIME)
            addExifAttribute(attributes, "焦距", exif, ExifInterface.TAG_FOCAL_LENGTH)
            addExifAttribute(attributes, "图片宽度", exif, ExifInterface.TAG_IMAGE_WIDTH)
            addExifAttribute(attributes, "图片高度", exif, ExifInterface.TAG_IMAGE_LENGTH)
            val location = formatExifLocation(exif)
            if (location.isNotBlank()) {
                attributes["GPS"] = location
            }
            result.success(mapOf("attributes" to attributes))
        } catch (error: Exception) {
            result.error("invalid_image", error.message, null)
        }
    }

    private fun removeExif(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("file_not_found", "图片路径为空", null)
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

        try {
            val outputDir = File(cacheDir, "exif_cleaned_images").apply { mkdirs() }
            val output = File(outputDir, "exif_cleaned_${System.currentTimeMillis()}.jpg")
            FileOutputStream(output).use { stream ->
                val success = bitmap.compress(Bitmap.CompressFormat.JPEG, 95, stream)
                if (!success) {
                    result.error("export_failed", "EXIF 清理导出失败", null)
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

    private fun pdfPagePointSize(pageSize: String, orientation: String): Pair<Int, Int> {
        val portrait = when (pageSize) {
            "a3" -> Pair(842, 1191)
            else -> Pair(595, 842)
        }
        return if (orientation == "landscape") {
            Pair(portrait.second, portrait.first)
        } else {
            portrait
        }
    }

    private fun drawBitmapCenteredInPdfPage(
        bitmap: Bitmap,
        canvas: Canvas,
        pageWidth: Int,
        pageHeight: Int,
    ) {
        val margin = 24f
        val availableWidth = (pageWidth - margin * 2).coerceAtLeast(1f)
        val availableHeight = (pageHeight - margin * 2).coerceAtLeast(1f)
        val scale = minOf(
            availableWidth / bitmap.width.toFloat(),
            availableHeight / bitmap.height.toFloat(),
        )
        val targetWidth = bitmap.width * scale
        val targetHeight = bitmap.height * scale
        val left = (pageWidth - targetWidth) / 2f
        val top = (pageHeight - targetHeight) / 2f
        canvas.drawBitmap(
            bitmap,
            null,
            RectF(left, top, left + targetWidth, top + targetHeight),
            Paint(Paint.ANTI_ALIAS_FLAG),
        )
    }

    private fun addExifAttribute(
        attributes: MutableMap<String, String>,
        label: String,
        exif: ExifInterface,
        tag: String,
    ) {
        val value = exif.getAttribute(tag)?.trim().orEmpty()
        if (value.isNotBlank()) {
            attributes[label] = value
        }
    }

    private fun formatExifLocation(exif: ExifInterface): String {
        val latitude = exif.getAttribute(ExifInterface.TAG_GPS_LATITUDE)?.trim().orEmpty()
        val latitudeRef = exif.getAttribute(ExifInterface.TAG_GPS_LATITUDE_REF)?.trim().orEmpty()
        val longitude = exif.getAttribute(ExifInterface.TAG_GPS_LONGITUDE)?.trim().orEmpty()
        val longitudeRef = exif.getAttribute(ExifInterface.TAG_GPS_LONGITUDE_REF)?.trim().orEmpty()
        if (latitude.isBlank() || longitude.isBlank()) {
            return ""
        }
        return listOf(latitudeRef, latitude, longitudeRef, longitude)
            .filter { it.isNotBlank() }
            .joinToString(" ")
    }

    private fun calculateMergeLayout(
        bitmaps: List<Bitmap>,
        mode: String,
        columns: Int,
        spacing: Int,
    ): MergeLayout {
        return when (mode) {
            "vertical" -> calculateVerticalLayout(bitmaps, spacing)
            "grid" -> calculateGridLayout(bitmaps, columns, spacing)
            else -> calculateHorizontalLayout(bitmaps, spacing)
        }
    }

    private fun calculateHorizontalLayout(bitmaps: List<Bitmap>, spacing: Int): MergeLayout {
        val width = bitmaps.sumOf { it.width } + spacing * (bitmaps.size - 1)
        val height = bitmaps.maxOf { it.height }
        val positions = mutableListOf<BitmapPosition>()
        var x = 0
        for (bitmap in bitmaps) {
            positions.add(BitmapPosition(x, (height - bitmap.height) / 2))
            x += bitmap.width + spacing
        }
        return MergeLayout(width = width, height = height, positions = positions)
    }

    private fun calculateVerticalLayout(bitmaps: List<Bitmap>, spacing: Int): MergeLayout {
        val width = bitmaps.maxOf { it.width }
        val height = bitmaps.sumOf { it.height } + spacing * (bitmaps.size - 1)
        val positions = mutableListOf<BitmapPosition>()
        var y = 0
        for (bitmap in bitmaps) {
            positions.add(BitmapPosition((width - bitmap.width) / 2, y))
            y += bitmap.height + spacing
        }
        return MergeLayout(width = width, height = height, positions = positions)
    }

    private fun calculateGridLayout(
        bitmaps: List<Bitmap>,
        columns: Int,
        spacing: Int,
    ): MergeLayout {
        val columnCount = columns.coerceIn(1, bitmaps.size)
        val rowCount = (bitmaps.size + columnCount - 1) / columnCount
        val cellWidth = bitmaps.maxOf { it.width }
        val cellHeight = bitmaps.maxOf { it.height }
        val width = cellWidth * columnCount + spacing * (columnCount - 1)
        val height = cellHeight * rowCount + spacing * (rowCount - 1)
        val positions = mutableListOf<BitmapPosition>()
        for (index in bitmaps.indices) {
            val bitmap = bitmaps[index]
            val row = index / columnCount
            val column = index % columnCount
            val x = column * (cellWidth + spacing) + (cellWidth - bitmap.width) / 2
            val y = row * (cellHeight + spacing) + (cellHeight - bitmap.height) / 2
            positions.add(BitmapPosition(x, y))
        }
        return MergeLayout(width = width, height = height, positions = positions)
    }

    private fun parseWatermarkColor(color: String, opacity: Int): Int {
        val alpha = (opacity * 255 / 100).coerceIn(0, 255)
        val parsedColor = try {
            Color.parseColor(color)
        } catch (_: IllegalArgumentException) {
            Color.WHITE
        }
        return Color.argb(
            alpha,
            Color.red(parsedColor),
            Color.green(parsedColor),
            Color.blue(parsedColor),
        )
    }

    private fun drawAnnotation(
        bitmap: Bitmap,
        mode: String,
        text: String,
        color: String,
        strokeWidth: Int,
    ) {
        val canvas = Canvas(bitmap)
        val baseColor = try {
            Color.parseColor(color)
        } catch (_: IllegalArgumentException) {
            Color.RED
        }
        val minSide = minOf(bitmap.width, bitmap.height).toFloat()
        val margin = (minSide * 0.12f).coerceAtLeast(24f)
        val left = margin
        val top = margin
        val right = bitmap.width - margin
        val bottom = bitmap.height - margin
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = baseColor
            style = Paint.Style.STROKE
            this.strokeWidth = strokeWidth.toFloat()
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        when (mode) {
            "arrow" -> drawAnnotationArrow(canvas, paint, left, top, right, bottom)
            "rectangle" -> canvas.drawRect(RectF(left, top, right, bottom), paint)
            "circle" -> canvas.drawOval(RectF(left, top, right, bottom), paint)
            "text" -> drawAnnotationText(canvas, text, baseColor, left, top, minSide)
            "highlight" -> drawAnnotationHighlight(canvas, baseColor, left, top, right, bottom)
            "mosaic" -> drawAnnotationMosaic(bitmap, left.toInt(), top.toInt(), right.toInt(), bottom.toInt())
            else -> drawAnnotationBrush(canvas, paint, left, top, right, bottom)
        }
    }

    private fun drawAnnotationBrush(
        canvas: Canvas,
        paint: Paint,
        left: Float,
        top: Float,
        right: Float,
        bottom: Float,
    ) {
        val width = right - left
        val height = bottom - top
        val path = android.graphics.Path().apply {
            moveTo(left, top + height * 0.58f)
            cubicTo(left + width * 0.22f, top, left + width * 0.36f, bottom, left + width * 0.55f, top + height * 0.45f)
            cubicTo(left + width * 0.72f, top + height * 0.08f, left + width * 0.86f, bottom, right, top + height * 0.36f)
        }
        canvas.drawPath(path, paint)
    }

    private fun drawAnnotationArrow(
        canvas: Canvas,
        paint: Paint,
        left: Float,
        top: Float,
        right: Float,
        bottom: Float,
    ) {
        canvas.drawLine(left, bottom, right, top, paint)
        val headLength = minOf(right - left, bottom - top) * 0.18f
        canvas.drawLine(right, top, right - headLength, top + headLength * 0.25f, paint)
        canvas.drawLine(right, top, right - headLength * 0.25f, top + headLength, paint)
    }

    private fun drawAnnotationText(
        canvas: Canvas,
        text: String,
        color: Int,
        left: Float,
        top: Float,
        minSide: Float,
    ) {
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.FILL
            textSize = (minSide * 0.09f).coerceIn(28f, 88f)
            setShadowLayer(4f, 2f, 2f, Color.argb(120, 0, 0, 0))
        }
        canvas.drawText(text, left, top + textPaint.textSize, textPaint)
    }

    private fun drawAnnotationHighlight(
        canvas: Canvas,
        color: Int,
        left: Float,
        top: Float,
        right: Float,
        bottom: Float,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = Color.argb(
                96,
                Color.red(color),
                Color.green(color),
                Color.blue(color),
            )
            style = Paint.Style.FILL
        }
        val height = bottom - top
        canvas.drawRoundRect(
            RectF(left, top + height * 0.35f, right, top + height * 0.62f),
            12f,
            12f,
            paint,
        )
    }

    private fun drawAnnotationMosaic(bitmap: Bitmap, left: Int, top: Int, right: Int, bottom: Int) {
        val blockSize = (minOf(bitmap.width, bitmap.height) / 32).coerceIn(8, 32)
        val safeLeft = left.coerceIn(0, bitmap.width - 1)
        val safeTop = top.coerceIn(0, bitmap.height - 1)
        val safeRight = right.coerceIn(safeLeft + 1, bitmap.width)
        val safeBottom = bottom.coerceIn(safeTop + 1, bitmap.height)
        var y = safeTop
        while (y < safeBottom) {
            var x = safeLeft
            while (x < safeRight) {
                val sampleX = x.coerceAtMost(bitmap.width - 1)
                val sampleY = y.coerceAtMost(bitmap.height - 1)
                val color = bitmap.getPixel(sampleX, sampleY)
                val blockRight = (x + blockSize).coerceAtMost(safeRight)
                val blockBottom = (y + blockSize).coerceAtMost(safeBottom)
                for (drawY in y until blockBottom) {
                    for (drawX in x until blockRight) {
                        bitmap.setPixel(drawX, drawY, color)
                    }
                }
                x += blockSize
            }
            y += blockSize
        }
    }

    private fun drawSingleWatermark(
        canvas: Canvas,
        text: String,
        paint: Paint,
        width: Int,
        height: Int,
        position: String,
        fontSize: Int,
    ) {
        val lines = text.split('\n').filter { it.isNotBlank() }
        val fontMetrics = paint.fontMetrics
        val lineHeight = (fontMetrics.bottom - fontMetrics.top).coerceAtLeast(fontSize.toFloat())
        val blockWidth = lines.maxOf { paint.measureText(it) }
        val blockHeight = lineHeight * lines.size
        val margin = (fontSize * 0.8f).coerceAtLeast(24f)
        val x = when (position) {
            "topright", "bottomright" -> width - blockWidth - margin
            "center" -> (width - blockWidth) / 2f
            else -> margin
        }.coerceIn(0f, width.toFloat())
        val top = when (position) {
            "bottomleft", "bottomright" -> height - blockHeight - margin
            "center" -> (height - blockHeight) / 2f
            else -> margin
        }.coerceIn(0f, height.toFloat())
        var baseline = top - fontMetrics.top
        for (line in lines) {
            canvas.drawText(line, x, baseline, paint)
            baseline += lineHeight
        }
    }

    private fun drawTiledWatermark(
        canvas: Canvas,
        text: String,
        paint: Paint,
        width: Int,
        height: Int,
        fontSize: Int,
    ) {
        val line = text.replace('\n', ' ')
        val textWidth = paint.measureText(line).coerceAtLeast(fontSize.toFloat())
        val stepX = (textWidth * 1.6f).coerceAtLeast(180f)
        val stepY = (fontSize * 3.2f).coerceAtLeast(120f)
        var y = fontSize.toFloat()
        var row = 0
        while (y < height + stepY) {
            var x = if (row % 2 == 0) fontSize.toFloat() else stepX / 2f
            while (x < width + stepX) {
                canvas.drawText(line, x, y, paint)
                x += stepX
            }
            row += 1
            y += stepY
        }
    }

    private fun scaleWatermarkBitmap(
        watermark: Bitmap,
        sourceWidth: Int,
        sourceHeight: Int,
        scalePercent: Int,
    ): Bitmap {
        val maxWidth = (sourceWidth * scalePercent / 100.0).toInt().coerceAtLeast(1)
        val maxHeight = (sourceHeight * scalePercent / 100.0).toInt().coerceAtLeast(1)
        val ratio = minOf(
            maxWidth.toDouble() / watermark.width.toDouble(),
            maxHeight.toDouble() / watermark.height.toDouble(),
        ).coerceAtMost(1.0)
        val targetWidth = (watermark.width * ratio).toInt().coerceAtLeast(1)
        val targetHeight = (watermark.height * ratio).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(watermark, targetWidth, targetHeight, true)
    }

    private fun rotateWatermarkBitmap(watermark: Bitmap, rotationDegrees: Int): Bitmap {
        if (rotationDegrees == 0) {
            return watermark
        }
        val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
        return Bitmap.createBitmap(watermark, 0, 0, watermark.width, watermark.height, matrix, true)
    }

    private fun drawSingleImageWatermark(
        canvas: Canvas,
        watermark: Bitmap,
        paint: Paint,
        width: Int,
        height: Int,
        position: String,
    ) {
        val margin = (minOf(width, height) * 0.04f).coerceAtLeast(16f)
        val x = when (position) {
            "topright", "bottomright" -> width - watermark.width - margin
            "center" -> (width - watermark.width) / 2f
            else -> margin
        }.coerceIn(0f, (width - watermark.width).coerceAtLeast(0).toFloat())
        val y = when (position) {
            "bottomleft", "bottomright" -> height - watermark.height - margin
            "center" -> (height - watermark.height) / 2f
            else -> margin
        }.coerceIn(0f, (height - watermark.height).coerceAtLeast(0).toFloat())
        canvas.drawBitmap(watermark, x, y, paint)
    }

    private fun drawTiledImageWatermark(
        canvas: Canvas,
        watermark: Bitmap,
        paint: Paint,
        width: Int,
        height: Int,
    ) {
        val stepX = (watermark.width * 1.6f).coerceAtLeast(80f)
        val stepY = (watermark.height * 1.6f).coerceAtLeast(80f)
        var y = 0f
        var row = 0
        while (y < height + stepY) {
            var x = if (row % 2 == 0) 0f else stepX / 2f
            while (x < width + stepX) {
                canvas.drawBitmap(watermark, x, y, paint)
                x += stepX
            }
            row += 1
            y += stepY
        }
    }

    private fun applyBitmapFilter(bitmap: Bitmap, filter: String): Bitmap {
        val output = bitmap.copy(Bitmap.Config.ARGB_8888, true)
        val pixels = IntArray(output.width * output.height)
        output.getPixels(pixels, 0, output.width, 0, 0, output.width, output.height)
        for (index in pixels.indices) {
            pixels[index] = transformPixel(pixels[index], filter)
        }
        output.setPixels(pixels, 0, output.width, 0, 0, output.width, output.height)
        return output
    }

    private fun transformPixel(pixel: Int, filter: String): Int {
        val alpha = Color.alpha(pixel)
        val red = Color.red(pixel)
        val green = Color.green(pixel)
        val blue = Color.blue(pixel)
        return when (filter) {
            "monochrome" -> {
                val gray = luminance(red, green, blue)
                val value = if (gray >= 128) 255 else 0
                Color.argb(alpha, value, value, value)
            }
            "sepia" -> {
                val nextRed = (red * 0.393 + green * 0.769 + blue * 0.189).toInt()
                val nextGreen = (red * 0.349 + green * 0.686 + blue * 0.168).toInt()
                val nextBlue = (red * 0.272 + green * 0.534 + blue * 0.131).toInt()
                Color.argb(alpha, clampColor(nextRed), clampColor(nextGreen), clampColor(nextBlue))
            }
            "invert" -> Color.argb(alpha, 255 - red, 255 - green, 255 - blue)
            "warm" -> Color.argb(
                alpha,
                clampColor((red * 1.12).toInt() + 12),
                clampColor((green * 1.04).toInt()),
                clampColor((blue * 0.88).toInt()),
            )
            "cool" -> Color.argb(
                alpha,
                clampColor((red * 0.88).toInt()),
                clampColor((green * 1.03).toInt()),
                clampColor((blue * 1.15).toInt() + 10),
            )
            else -> {
                val gray = luminance(red, green, blue)
                Color.argb(alpha, gray, gray, gray)
            }
        }
    }

    private fun luminance(red: Int, green: Int, blue: Int): Int {
        return (red * 0.299 + green * 0.587 + blue * 0.114).toInt().coerceIn(0, 255)
    }

    private fun clampColor(value: Int): Int {
        return value.coerceIn(0, 255)
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
    private data class BitmapPosition(val x: Int, val y: Int)
    private data class MergeLayout(
        val width: Int,
        val height: Int,
        val positions: List<BitmapPosition>,
    )
}
