import 'package:get/get.dart';

import '../../utils/latest_snackbar.dart';
import '../../database/database.dart';
import '../../repositories/operation_history_repository.dart';

enum HistoryStatusFilter {
  all(labelKey: 'history.filter.all', value: ''),
  success(labelKey: 'history.status.success', value: 'success'),
  failed(labelKey: 'history.status.failed', value: 'failed');

  const HistoryStatusFilter({required this.labelKey, required this.value});

  final String labelKey;
  final String value;
}

enum HistoryDateFilter {
  all(labelKey: 'history.filter.all', days: 0),
  today(labelKey: 'history.date.today', days: 1),
  sevenDays(labelKey: 'history.date.sevenDays', days: 7),
  thirtyDays(labelKey: 'history.date.thirtyDays', days: 30);

  const HistoryDateFilter({required this.labelKey, required this.days});

  final String labelKey;
  final int days;
}

/// 历史记录控制器，读取最近的本地处理历史。
///
/// 设计意图：筛选条件集中在 Controller，页面只负责展示和转发用户输入；
/// 清理历史前由页面确认，Controller 只执行明确命令。
class HistoryController extends GetxController {
  HistoryController({required OperationHistoryRepository repository})
    : _repository = repository;

  final OperationHistoryRepository _repository;

  final items = <OperationHistoryData>[].obs;
  final isLoading = false.obs;
  final keyword = ''.obs;
  final statusFilter = HistoryStatusFilter.all.obs;
  final dateFilter = HistoryDateFilter.all.obs;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    isLoading.value = true;
    try {
      items.assignAll(
        await _repository.getRecentHistory(
          keyword: keyword.value,
          status: statusFilter.value.value,
          startDate: _startDateFor(dateFilter.value),
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateKeyword(String value) async {
    keyword.value = value;
    await loadHistory();
  }

  Future<void> updateStatusFilter(HistoryStatusFilter value) async {
    statusFilter.value = value;
    await loadHistory();
  }

  Future<void> updateDateFilter(HistoryDateFilter value) async {
    dateFilter.value = value;
    await loadHistory();
  }

  Future<void> clearHistory() async {
    isLoading.value = true;
    try {
      await _repository.clearHistory();
      items.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteHistoryItem(OperationHistoryData item) async {
    isLoading.value = true;
    try {
      await _repository.deleteHistoryItem(item.id);
      items.removeWhere((history) => history.id == item.id);
      showLatestSnackbar(
        'history.delete.success.title'.tr,
        'history.delete.success.message'.tr,
      );
    } catch (_) {
      showLatestSnackbar(
        'history.delete.failed.title'.tr,
        'history.delete.failed.message'.tr,
      );
    } finally {
      isLoading.value = false;
    }
  }

  DateTime? _startDateFor(HistoryDateFilter filter) {
    if (filter.days <= 0) {
      return null;
    }
    final now = DateTime.now();
    if (filter == HistoryDateFilter.today) {
      return DateTime(now.year, now.month, now.day);
    }
    return now.subtract(Duration(days: filter.days));
  }
}
