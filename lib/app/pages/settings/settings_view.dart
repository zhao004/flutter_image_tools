import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'settings_controller.dart';

/// 设置页，展示离线隐私说明和默认压缩参数。
///
/// 构建设计：设置项直接写入本地 Drift，保证离线可用；未接入目录选择前，
/// 导出目录只展示当前策略，避免提供无法生效的编辑入口。
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('隐私模式', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('所有图片均在本机处理，不上传服务器，不需要登录。'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '默认压缩质量',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('${controller.defaultQuality.value}%'),
                      Slider(
                        value: controller.defaultQuality.value.toDouble(),
                        min: 1,
                        max: 100,
                        divisions: 99,
                        label: '${controller.defaultQuality.value}%',
                        onChanged: controller.updateDefaultQuality,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '默认导出格式',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'jpg', label: Text('JPG')),
                          ButtonSegment(value: 'png', label: Text('PNG')),
                          ButtonSegment(value: 'webp', label: Text('WebP')),
                        ],
                        selected: {controller.defaultExportFormat.value},
                        onSelectionChanged: (values) =>
                            controller.updateDefaultExportFormat(values.first),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('主题模式', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'system', label: Text('系统')),
                          ButtonSegment(value: 'light', label: Text('浅色')),
                          ButtonSegment(value: 'dark', label: Text('深色')),
                        ],
                        selected: {controller.themeMode.value},
                        onSelectionChanged: (values) =>
                            controller.updateThemeMode(values.first),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('默认导出目录', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        controller.defaultExportDirectory.value ?? '应用缓存目录',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
