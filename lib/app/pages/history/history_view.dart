import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'history_controller.dart';

/// 历史记录页，展示本机图片处理记录。
///
/// 边界处理：空列表显示明确占位；读取失败后由后续日志体系记录，当前页面
/// 先保持可恢复刷新入口。
class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('历史记录')),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 48),
                  const SizedBox(height: 12),
                  const Text('暂无处理记录'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: controller.loadHistory,
                    child: const Text('刷新'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: controller.loadHistory,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: controller.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = controller.items[index];
                final isSuccess = item.status == 'success';
                return Card(
                  child: ListTile(
                    leading: Icon(
                      isSuccess
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                    ),
                    title: Text(item.featureName),
                    subtitle: Text(
                      item.outputPath ?? item.errorMessage ?? item.inputPath,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(isSuccess ? '成功' : '失败'),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
