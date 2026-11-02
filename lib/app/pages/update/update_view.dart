import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/app_update_release.dart';
import 'update_controller.dart';

/// 软件更新页，展示版本信息、更新说明、下载进度和安装入口。
///
/// 构建设计：页面只观察全局 AppUpdateController，下载在离开页面后仍可
/// 继续；权限与安装状态通过同一控制器恢复，避免重复下载已验证的 APK。
class UpdateView extends GetView<AppUpdateController> {
  const UpdateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('update.title'.tr)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Obx(() {
              final phase = controller.phase.value;
              final release = controller.availableRelease.value;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _VersionCard(controller: controller),
                  if (release != null) ...[
                    const SizedBox(height: 16),
                    _ReleaseCard(release: release),
                  ],
                  if (phase == AppUpdatePhase.downloading ||
                      phase == AppUpdatePhase.verifying ||
                      phase == AppUpdatePhase.installing) ...[
                    const SizedBox(height: 16),
                    _ProgressCard(controller: controller),
                  ],
                  if (phase == AppUpdatePhase.error) ...[
                    const SizedBox(height: 16),
                    _ErrorCard(message: controller.errorMessage),
                  ],
                  if (phase == AppUpdatePhase.installPermissionRequired) ...[
                    const SizedBox(height: 16),
                    _PermissionCard(
                      onOpenSettings: controller.openInstallPermissionSettings,
                    ),
                  ],
                  const SizedBox(height: 20),
                  _UpdateAction(controller: controller),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.controller});

  final AppUpdateController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentVersion = controller.currentVersion.value.isEmpty
        ? 'update.version.unknown'.tr
        : controller.currentVersion.value;
    final latestVersion = controller.latestVersion.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update_alt, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'update.currentVersion'.tr,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  currentVersion,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (latestVersion != null && latestVersion.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Text('update.latestVersion'.tr)),
                  Text(
                    latestVersion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _statusText(controller.phase.value),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release});

  final AppUpdateRelease release;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = release.releaseNotes.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'update.releaseNotes'.tr,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (release.publishedAt != null)
                  Text(
                    _formatDate(release.publishedAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              notes.isEmpty ? 'update.releaseNotes.empty'.tr : notes,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.controller});

  final AppUpdateController controller;

  @override
  Widget build(BuildContext context) {
    final phase = controller.phase.value;
    final progress = controller.progress.value.clamp(0.0, 1.0);
    final downloaded = controller.downloadedBytes.value;
    final total = controller.totalBytes.value;
    final message = switch (phase) {
      AppUpdatePhase.verifying => 'update.verifying'.tr,
      AppUpdatePhase.installing => 'update.installing'.tr,
      _ => 'update.downloading'.trParams({
        'percent': '${(progress * 100).round()}',
      }),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: phase == AppUpdatePhase.downloading ? progress : null,
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatBytes(downloaded)} / ${_formatBytes(total)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onOpenSettings});

  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'update.permission.title'.tr,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text('update.permission.message'.tr),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              label: Text('update.permission.openSettings'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateAction extends StatelessWidget {
  const _UpdateAction({required this.controller});

  final AppUpdateController controller;

  @override
  Widget build(BuildContext context) {
    final phase = controller.phase.value;
    return switch (phase) {
      AppUpdatePhase.checking ||
      AppUpdatePhase.downloading ||
      AppUpdatePhase.verifying ||
      AppUpdatePhase.installing => const SizedBox.shrink(),
      AppUpdatePhase.updateAvailable => FilledButton.icon(
        onPressed: controller.downloadAndInstall,
        icon: const Icon(Icons.download),
        label: Text('update.download'.tr),
      ),
      AppUpdatePhase.installPermissionRequired => const SizedBox.shrink(),
      AppUpdatePhase.installReady => FilledButton.icon(
        onPressed: controller.installDownloaded,
        icon: const Icon(Icons.install_mobile),
        label: Text('update.install'.tr),
      ),
      AppUpdatePhase.installerOpened => OutlinedButton.icon(
        onPressed: controller.installDownloaded,
        icon: const Icon(Icons.open_in_new),
        label: Text('update.installerOpened'.tr),
      ),
      AppUpdatePhase.error when controller.hasDownloadedFile =>
        OutlinedButton.icon(
          onPressed: controller.installDownloaded,
          icon: const Icon(Icons.refresh),
          label: Text('update.retry'.tr),
        ),
      AppUpdatePhase.error when controller.availableRelease.value != null =>
        OutlinedButton.icon(
          onPressed: controller.downloadAndInstall,
          icon: const Icon(Icons.refresh),
          label: Text('update.retry'.tr),
        ),
      AppUpdatePhase.error => OutlinedButton.icon(
        onPressed: controller.checkForUpdates,
        icon: const Icon(Icons.refresh),
        label: Text('update.retry'.tr),
      ),
      AppUpdatePhase.unsupported => const SizedBox.shrink(),
      _ => FilledButton.tonalIcon(
        onPressed: controller.checkForUpdates,
        icon: const Icon(Icons.refresh),
        label: Text('update.check'.tr),
      ),
    };
  }
}

String _statusText(AppUpdatePhase phase) {
  return switch (phase) {
    AppUpdatePhase.idle => 'update.status.idle'.tr,
    AppUpdatePhase.checking => 'update.checking'.tr,
    AppUpdatePhase.upToDate => 'update.upToDate'.tr,
    AppUpdatePhase.updateAvailable => 'update.status.available'.tr,
    AppUpdatePhase.downloading => 'update.status.downloading'.tr,
    AppUpdatePhase.verifying => 'update.verifying'.tr,
    AppUpdatePhase.installing => 'update.installing'.tr,
    AppUpdatePhase.installPermissionRequired => 'update.permission.required'.tr,
    AppUpdatePhase.installReady => 'update.installReady'.tr,
    AppUpdatePhase.installerOpened => 'update.installerOpened'.tr,
    AppUpdatePhase.error => 'update.status.error'.tr,
    AppUpdatePhase.unsupported => 'update.unsupported'.tr,
  };
}

String _formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  final fractionDigits = unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}

String _formatDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
