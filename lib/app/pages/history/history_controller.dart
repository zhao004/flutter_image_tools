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

/// 历史记录控制器，按每页二十条读取本地处理历史。
///
/// 设计意图：筛选条件集中在 Controller，页面只负责展示和转发用户输入；
/// 首次加载和增量加载使用独立状态，并通过请求代次丢弃已过期的筛选结果。
class HistoryController extends GetxController {
  HistoryController({required OperationHistoryRepository repository})
    : _repository = repository;

  final OperationHistoryRepository _repository;

  static const int pageSize = 20;
  static const int _pageQuerySize = pageSize + 1;

  final items = <OperationHistoryData>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final hasLoadError = false.obs;
  final hasLoadMoreError = false.obs;
  final keyword = ''.obs;
  final statusFilter = HistoryStatusFilter.all.obs;
  final dateFilter = HistoryDateFilter.all.obs;
  int _loadGeneration = 0;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final generation = ++_loadGeneration;
    isLoading.value = true;
    isLoadingMore.value = false;
    hasLoadError.value = false;
    hasLoadMoreError.value = false;
    try {
      final page = await _loadPage(offset: 0);
      if (generation != _loadGeneration) {
        return;
      }
      items.assignAll(page.items);
      hasMore.value = page.hasMore;
    } catch (_) {
      if (generation == _loadGeneration) {
        hasLoadError.value = true;
        if (items.isEmpty) {
          hasMore.value = false;
        }
      }
    } finally {
      if (generation == _loadGeneration) {
        isLoading.value = false;
      }
    }
  }

  Future<void> loadMoreHistory() async {
    if (isLoading.value ||
        isLoadingMore.value ||
        !hasMore.value ||
        items.isEmpty) {
      return;
    }

    final generation = _loadGeneration;
    isLoadingMore.value = true;
    hasLoadMoreError.value = false;
    try {
      final page = await _loadPage(offset: items.length);
      if (generation != _loadGeneration) {
        return;
      }
      final existingIds = items.map((item) => item.id).toSet();
      items.addAll(page.items.where((item) => existingIds.add(item.id)));
      hasMore.value = page.hasMore;
    } catch (_) {
      if (generation == _loadGeneration) {
        hasLoadMoreError.value = true;
      }
    } finally {
      if (generation == _loadGeneration) {
        isLoadingMore.value = false;
      }
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
    _loadGeneration += 1;
    isLoadingMore.value = false;
    isLoading.value = true;
    try {
      await _repository.clearHistory();
      items.clear();
      hasMore.value = false;
      hasLoadError.value = false;
      hasLoadMoreError.value = false;
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

  Future<_HistoryPage> _loadPage({required int offset}) async {
    final records = await _repository.getRecentHistory(
      limit: _pageQuerySize,
      offset: offset,
      keyword: keyword.value,
      status: statusFilter.value.value,
      startDate: _startDateFor(dateFilter.value),
    );
    return _HistoryPage(
      items: records.take(pageSize).toList(growable: false),
      hasMore: records.length > pageSize,
    );
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

class _HistoryPage {
  const _HistoryPage({required this.items, required this.hasMore});

  final List<OperationHistoryData> items;
  final bool hasMore;
}
