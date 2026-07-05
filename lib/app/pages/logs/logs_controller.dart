import 'package:get/get.dart';

import '../../database/database.dart';
import '../../repositories/operation_logs_repository.dart';

enum LogsStatusFilter {
  all(label: '全部', value: ''),
  success(label: '成功', value: 'success'),
  failed(label: '失败', value: 'failed');

  const LogsStatusFilter({required this.label, required this.value});

  final String label;
  final String value;
}

enum LogsDateFilter {
  all(label: '全部', days: 0),
  today(label: '今天', days: 1),
  sevenDays(label: '近 7 天', days: 7),
  thirtyDays(label: '近 30 天', days: 30);

  const LogsDateFilter({required this.label, required this.days});

  final String label;
  final int days;
}

/// 日志管理控制器，负责读取、筛选和清理本地操作日志。
///
/// 异常策略：筛选条件变化后立即重新查询；读取失败不清空旧数据，避免短暂
/// 数据库异常导致页面失去上下文。清理操作由页面确认后执行。
class LogsController extends GetxController {
  LogsController({required OperationLogsRepository repository})
    : _repository = repository;

  final OperationLogsRepository _repository;

  final items = <OperationLog>[].obs;
  final isLoading = false.obs;
  final keyword = ''.obs;
  final statusFilter = LogsStatusFilter.all.obs;
  final dateFilter = LogsDateFilter.all.obs;

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
      Get.snackbar('读取失败', '日志读取失败，请稍后重试');
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
      Get.snackbar('清理完成', '操作日志已清理');
    } catch (_) {
      Get.snackbar('清理失败', '日志清理失败，请稍后重试');
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
      return '未知耗时';
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
}
