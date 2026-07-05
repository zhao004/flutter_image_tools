import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'settings_controller.dart';

/// 设置页，展示离线隐私说明和默认压缩参数。
///
/// 构建设计：第一阶段不写入持久化设置，避免与后续 app_settings 表迁移冲突；
/// 用户可以先了解默认策略，持久化会在数据库表补全后接入。
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
          ],
        ),
      ),
    );
  }
}
