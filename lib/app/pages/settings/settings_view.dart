import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_pages.dart';
import 'settings_controller.dart';

/// 设置页，展示导出、主题、语言和本地管理入口。
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
                      _SettingsDropdown(
                        value: controller.defaultSaveRule.value,
                        options: [
                          _SettingsOption(
                            value: 'timestamp',
                            label: 'settings.saveRule.timestamp'.tr,
                          ),
                          _SettingsOption(
                            value: 'source_name',
                            label: 'settings.saveRule.sourceName'.tr,
                          ),
                          _SettingsOption(
                            value: 'feature_folder',
                            label: 'settings.saveRule.featureFolder'.tr,
                          ),
                        ],
                        onChanged: controller.updateDefaultSaveRule,
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
                      _SettingsDropdown(
                        value: controller.defaultExportFormat.value,
                        options: const [
                          _SettingsOption(value: 'jpg', label: 'JPG'),
                          _SettingsOption(value: 'png', label: 'PNG'),
                          _SettingsOption(value: 'webp', label: 'WebP'),
                        ],
                        onChanged: controller.updateDefaultExportFormat,
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
                      _SettingsDropdown(
                        value: controller.themeMode.value,
                        options: [
                          _SettingsOption(
                            value: 'system',
                            label: 'settings.theme.system'.tr,
                          ),
                          _SettingsOption(
                            value: 'light',
                            label: 'settings.theme.light'.tr,
                          ),
                          _SettingsOption(
                            value: 'dark',
                            label: 'settings.theme.dark'.tr,
                          ),
                        ],
                        onChanged: controller.updateThemeMode,
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
                      _SettingsDropdown(
                        value: controller.language.value,
                        options: [
                          _SettingsOption(
                            value: 'system',
                            label: 'settings.language.system'.tr,
                          ),
                          _SettingsOption(
                            value: 'zh_cn',
                            label: 'settings.language.zhCn'.tr,
                          ),
                          _SettingsOption(
                            value: 'zh_tw',
                            label: 'settings.language.zhTw'.tr,
                          ),
                          _SettingsOption(
                            value: 'en',
                            label: 'settings.language.en'.tr,
                          ),
                        ],
                        onChanged: controller.updateLanguage,
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
                leading: const Icon(Icons.history_outlined),
                title: Text('settings.history.title'.tr),
                subtitle: Text('settings.history.subtitle'.tr),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Get.toNamed(Routes.history),
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

class _SettingsOption {
  const _SettingsOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _SettingsDropdown extends StatelessWidget {
  const _SettingsDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<_SettingsOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = options.any((option) => option.value == value)
        ? value
        : options.first.value;
    return DropdownButtonFormField<String>(
      key: ValueKey<String>('settings-dropdown-$safeValue'),
      initialValue: safeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.value,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: (nextValue) {
        if (nextValue == null || nextValue == value) {
          return;
        }
        onChanged(nextValue);
      },
    );
  }
}
