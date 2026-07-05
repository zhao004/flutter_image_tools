import 'package:get/get.dart';

import '../../database/database.dart';
import '../../repositories/operation_history_repository.dart';

enum HistoryStatusFilter {
  all(label: '全部', value: ''),
  success(label: '成功', value: 'success'),
  failed(label: '失败', value: 'failed');

  const HistoryStatusFilter({required this.label, required this.value});

  final String label;
  final String value;
}

enum HistoryDateFilter {
  all(label: '全部', days: 0),
  today(label: '今天', days: 1),
  sevenDays(label: '近 7 天', days: 7),
  thirtyDays(label: '近 30 天', days: 30);

  const HistoryDateFilter({required this.label, required this.days});

  final String label;
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
      Get.snackbar('删除完成', '该条历史记录已删除');
    } catch (_) {
      Get.snackbar('删除失败', '历史记录删除失败，请稍后重试');
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
