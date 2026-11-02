import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/latest_snackbar.dart';
import '../../models/cache_summary.dart';
import '../../repositories/cache_repository.dart';

/// 缓存管理控制器，负责统计应用缓存目录并清理本地缓存文件。
///
/// 异常策略：统计时跳过无法访问的文件，清理时逐项删除并继续处理其他文件；
/// 数据库缓存记录单独清理，避免文件系统异常导致元数据长期残留。
class CacheController extends GetxController {
  CacheController({required CacheRepository cacheRepository})
    : _cacheRepository = cacheRepository;

  final CacheRepository _cacheRepository;

  final summary = Rxn<CacheSummary>();
  final isBusy = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSummary();
  }

  Future<void> loadSummary() async {
    if (isBusy.value) {
      return;
    }
    isBusy.value = true;
    try {
      summary.value = await _collectSummary();
    } catch (_) {
      showLatestSnackbar(
        'cache.stats.failed.title'.tr,
        'cache.stats.failed.message'.tr,
      );
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> clearCache() async {
    if (isBusy.value) {
      return;
    }
    isBusy.value = true;
    try {
      final directory = await getTemporaryDirectory();
      if (directory.existsSync()) {
        await _clearChildren(directory);
      }
      await _cacheRepository.clearRecords();
      summary.value = await _collectSummary();
      showLatestSnackbar(
        'cache.clear.success.title'.tr,
        'cache.clear.success.message'.tr,
      );
    } catch (_) {
      showLatestSnackbar(
        'cache.clear.failed.title'.tr,
        'cache.clear.failed.message'.tr,
      );
    } finally {
      isBusy.value = false;
    }
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const unit = 1024;
    if (bytes < unit) {
      return '$bytes B';
    }
    final kib = bytes / unit;
    if (kib < unit) {
      return '${kib.toStringAsFixed(1)} KB';
    }
    final mib = kib / unit;
    if (mib < unit) {
      return '${mib.toStringAsFixed(1)} MB';
    }
    final gib = mib / unit;
    return '${gib.toStringAsFixed(1)} GB';
  }

  Future<CacheSummary> _collectSummary() async {
    final directory = await getTemporaryDirectory();
    final records = await _cacheRepository.getRecords();
    if (!directory.existsSync()) {
      return CacheSummary(
        cacheDirectoryPath: directory.path,
        fileCount: 0,
        recordCount: records.length,
        totalSizeBytes: 0,
      );
    }

    var fileCount = 0;
    var totalSizeBytes = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      try {
        final length = await entity.length();
        fileCount += 1;
        totalSizeBytes += length;
      } catch (_) {
        // 单个文件无法读取时跳过，保证缓存页仍可展示其余统计结果。
      }
    }

    return CacheSummary(
      cacheDirectoryPath: directory.path,
      fileCount: fileCount,
      recordCount: records.length,
      totalSizeBytes: totalSizeBytes,
    );
  }

  Future<void> _clearChildren(Directory directory) async {
    await for (final entity in directory.list()) {
      try {
        if (entity is Directory) {
          await entity.delete(recursive: true);
        } else if (entity is File) {
          await entity.delete();
        }
      } catch (_) {
        // 清理缓存以尽力完成为策略，单项失败不阻断其他缓存删除。
      }
    }
  }
}
