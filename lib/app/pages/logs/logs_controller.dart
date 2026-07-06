import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/latest_snackbar.dart';
import '../../database/database.dart';
import '../../repositories/operation_logs_repository.dart';

enum LogsStatusFilter {
  all(labelKey: 'logs.filter.all', value: ''),
  success(labelKey: 'logs.status.success', value: 'success'),
  failed(labelKey: 'logs.status.failed', value: 'failed');

  const LogsStatusFilter({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

enum LogsDateFilter {
  all(labelKey: 'logs.filter.all', days: 0),
  today(labelKey: 'logs.date.today', days: 1),
  sevenDays(labelKey: 'logs.date.sevenDays', days: 7),
  thirtyDays(labelKey: 'logs.date.thirtyDays', days: 30);

  const LogsDateFilter({required this.labelKey, required this.days});

  final String labelKey;
  final int days;
}

/// 日志管理控制器，负责读取、筛选、导出和清理本地操作日志。
///
/// 异常策略：筛选条件变化后立即重新查询；读取失败不清空旧数据，避免短暂
/// 数据库异常导致页面失去上下文。导出失败只提示错误，不影响当前列表。
class LogsController extends GetxController {
  LogsController({required OperationLogsRepository repository})
    : _repository = repository;

  final OperationLogsRepository _repository;

  final items = <OperationLog>[].obs;
  final isLoading = false.obs;
  final keyword = ''.obs;
  final statusFilter = LogsStatusFilter.all.obs;
  final dateFilter = LogsDateFilter.all.obs;
  final exportedPath = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadLogs();
  }

  Future<void> loadLogs() async {
    isLoading.value = true;
    try {
      items.assignAll(
        await _repository.getRecentLogs(
          keyword: keyword.value,
          status: statusFilter.value.value,
          startDate: _startDateFor(dateFilter.value),
        ),
      );
    } catch (_) {
      showLatestSnackbar(
        'logs.read.failed.title'.tr,
        'logs.read.failed.message'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateKeyword(String value) async {
    keyword.value = value;
    await loadLogs();
  }

  Future<void> updateStatusFilter(LogsStatusFilter value) async {
    statusFilter.value = value;
    await loadLogs();
  }

  Future<void> updateDateFilter(LogsDateFilter value) async {
    dateFilter.value = value;
    await loadLogs();
  }

  Future<void> clearLogs() async {
    isLoading.value = true;
    try {
      await _repository.clearLogs();
      items.clear();
      showLatestSnackbar(
        'logs.clear.success.title'.tr,
        'logs.clear.success.message'.tr,
      );
    } catch (_) {
      showLatestSnackbar(
        'logs.clear.failed.title'.tr,
        'logs.clear.failed.message'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportLogs() async {
    if (isLoading.value) {
      return;
    }
    isLoading.value = true;
    try {
      final csv = await _repository.exportLogsCsv(
        keyword: keyword.value,
        status: statusFilter.value.value,
        startDate: _startDateFor(dateFilter.value),
      );
      final output = await _createCsvFile(csv);
      exportedPath.value = output.path;
      showLatestSnackbar(
        'logs.export.success.title'.tr,
        'logs.export.success.message'.tr,
      );
    } on StateError catch (error) {
      showLatestSnackbar('logs.export.failed.title'.tr, error.message);
    } catch (_) {
      showLatestSnackbar(
        'logs.export.failed.title'.tr,
        'logs.export.failed.message'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  String formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String formatDuration(int? durationMs) {
    if (durationMs == null || durationMs < 0) {
      return 'logs.duration.unknown'.tr;
    }
    if (durationMs < 1000) {
      return '$durationMs ms';
    }
    return '${(durationMs / 1000).toStringAsFixed(1)} s';
  }

  DateTime? _startDateFor(LogsDateFilter filter) {
    if (filter.days <= 0) {
      return null;
    }
    final now = DateTime.now();
    if (filter == LogsDateFilter.today) {
      return DateTime(now.year, now.month, now.day);
    }
    return now.subtract(Duration(days: filter.days));
  }

  Future<File> _createCsvFile(String csv) async {
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/operation_logs');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final output = File('${directory.path}/operation_logs_$timestamp.csv');
    // 写入 UTF-8 BOM，方便系统文件查看器和表格软件正确识别中文字段。
    return output.writeAsString('\uFEFF$csv', flush: true);
  }
}
