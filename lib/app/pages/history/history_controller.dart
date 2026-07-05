import 'package:get/get.dart';

import '../../database/database.dart';
import '../../repositories/operation_history_repository.dart';

/// 历史记录控制器，读取最近的本地处理历史。
///
/// 设计意图：第一阶段只展示最近记录；搜索、删除和日期筛选后续在仓储层扩展，
/// 不让页面直接拼接数据库条件。
class HistoryController extends GetxController {
  HistoryController({required OperationHistoryRepository repository})
      : _repository = repository;

  final OperationHistoryRepository _repository;

  final items = <OperationHistoryData>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  Future<void> loadHistory() async {
    isLoading.value = true;
    try {
      items.assignAll(await _repository.getRecentHistory());
    } finally {
      isLoading.value = false;
    }
  }
}
