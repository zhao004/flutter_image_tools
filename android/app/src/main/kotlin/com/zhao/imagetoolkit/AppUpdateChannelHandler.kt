package com.zhao.imagetoolkit

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 自动更新原生通道，负责 ABI 查询、未知应用安装权限和 APK 安装。
 *
 * 安全边界：只允许安装应用缓存 `updates/` 目录内、包名与当前应用一致的
 * APK；最终签名和覆盖安装仍由 Android 系统安装器校验。
 */
class AppUpdateChannelHandler(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPreferredAbi" -> getPreferredAbi(result)
                "canInstallPackages" -> result.success(canInstallPackages())
                "openInstallPermissionSettings" -> openInstallPermissionSettings(result)
                "installApk" -> installApk(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun getPreferredAbi(result: MethodChannel.Result) {
        val supported = Build.SUPPORTED_ABIS.toSet()
        val abi = when {
            "arm64-v8a" in supported -> "arm64-v8a"
            "armeabi-v7a" in supported -> "armeabi-v7a"
            "x86_64" in supported -> "x86_64"
            else -> null
        }
        if (abi == null) {
            result.error("unsupported_abi", "当前设备架构没有可用的安装包", null)
            return
        }
        result.success(abi)
    }

    private fun canInstallPackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()
    }

    private fun openInstallPermissionSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || canInstallPackages()) {
            result.success(null)
            return
        }
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:${activity.packageName}"),
        )
        try {
            activity.startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("settings_unavailable", "无法打开安装权限设置", error.message)
        } catch (error: SecurityException) {
            result.error("permission_denied", "无法打开安装权限设置", error.message)
        }
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val rawPath = call.argument<String>("path")?.trim()
        if (rawPath.isNullOrEmpty()) {
            result.error("invalid_path", "安装包路径为空", null)
            return
        }
        val apkFile = try {
            File(rawPath).canonicalFile
        } catch (error: Exception) {
            result.error("invalid_path", "安装包路径无效", error.message)
            return
        }
        val updateDirectory = File(activity.cacheDir, UPDATE_DIRECTORY).canonicalFile
        if (apkFile.parentFile != updateDirectory ||
            !apkFile.isFile ||
            apkFile.length() <= 0 ||
            !apkFile.name.endsWith(".apk", ignoreCase = true)
        ) {
            result.error("invalid_path", "安装包不在允许的更新目录中", null)
            return
        }
        val archivePackageName = getArchivePackageName(apkFile)
        if (archivePackageName != activity.packageName) {
            result.error("invalid_apk", "安装包不属于当前应用", null)
            return
        }
        if (!canInstallPackages()) {
            result.error("permission_required", "需要允许安装未知应用", null)
            return
        }

        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.fileprovider",
            apkFile,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, APK_MIME_TYPE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            clipData = ClipData.newRawUri("update-apk", uri)
        }
        try {
            activity.startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error("installer_unavailable", "没有可用的系统安装器", error.message)
        } catch (error: SecurityException) {
            result.error("installer_unavailable", "无法打开系统安装器", error.message)
        }
    }

    private fun getArchivePackageName(apkFile: File): String? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.packageManager.getPackageArchiveInfo(
                apkFile.path,
                PackageManager.PackageInfoFlags.of(0),
            )?.packageName
        } else {
            @Suppress("DEPRECATION")
            activity.packageManager.getPackageArchiveInfo(apkFile.path, 0)?.packageName
        }
    }

    companion object {
        private const val CHANNEL_NAME = "image_toolkit/app_update"
        private const val UPDATE_DIRECTORY = "updates"
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }
}
