import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_pages.dart';
import 'settings_controller.dart';

/// 设置页，展示离线隐私说明、默认压缩参数和导出偏好。
///
/// 构建设计：设置项直接写入本地 Drift，保证离线可用；未接入目录选择前，
/// 导出目录只展示当前策略，避免提供无法生效的编辑入口。
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr)),
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
                    Text(
                      'settings.privacy.title'.tr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('settings.privacy.body'.tr),
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
                        'settings.quality.title'.tr,
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
                        'settings.saveRule.title'.tr,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('settings.saveRule.body'.tr),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'timestamp',
                            label: Text('settings.saveRule.timestamp'.tr),
                          ),
                          ButtonSegment(
                            value: 'source_name',
                            label: Text('settings.saveRule.sourceName'.tr),
                          ),
                          ButtonSegment(
                            value: 'feature_folder',
                            label: Text('settings.saveRule.featureFolder'.tr),
                          ),
                        ],
                        selected: {controller.defaultSaveRule.value},
                        onSelectionChanged: (values) =>
                            controller.updateDefaultSaveRule(values.first),
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
                        'settings.format.title'.tr,
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
                      Text(
                        'settings.theme.title'.tr,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'system',
                            label: Text('settings.theme.system'.tr),
                          ),
                          ButtonSegment(
                            value: 'light',
                            label: Text('settings.theme.light'.tr),
                          ),
                          ButtonSegment(
                            value: 'dark',
                            label: Text('settings.theme.dark'.tr),
                          ),
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
                      Text(
                        'settings.language.title'.tr,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'system',
                            label: Text('settings.language.system'.tr),
                          ),
                          ButtonSegment(
                            value: 'zh_cn',
                            label: Text('settings.language.zhCn'.tr),
                          ),
                          ButtonSegment(
                            value: 'zh_tw',
                            label: Text('settings.language.zhTw'.tr),
                          ),
                          ButtonSegment(
                            value: 'en',
                            label: Text('settings.language.en'.tr),
                          ),
                        ],
                        selected: {controller.language.value},
                        onSelectionChanged: (values) =>
                            controller.updateLanguage(values.first),
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
                        'settings.directory.title'.tr,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.defaultExportDirectory.value ??
                            'settings.directory.cache'.tr,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text('settings.cache.title'.tr),
                subtitle: Text('settings.cache.subtitle'.tr),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(Routes.cache),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text('settings.logs.title'.tr),
                subtitle: Text('settings.logs.subtitle'.tr),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(Routes.logs),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.star_outline),
                title: Text('settings.favorites.title'.tr),
                subtitle: Text('settings.favorites.subtitle'.tr),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(Routes.favorites),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
