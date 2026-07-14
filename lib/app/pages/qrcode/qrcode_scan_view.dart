import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/barcode_scan_result.dart';
import '../../widgets/tool_task_layout.dart';
import 'qrcode_controller.dart';

/// 二维码识别页，提供相册图片和实时相机两个互补入口。
class QrcodeScanView extends GetView<QrcodeController> {
  const QrcodeScanView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.scanResult.value;
      return AdaptiveTaskScaffold(
        title: 'qrcode.hub.scan.title'.tr,
        primary: ToolTaskSection(
          title: 'qrcode.scan.method.title'.tr,
          description: 'qrcode.scan.method.description'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ScanMethodButton(
                key: const ValueKey('qrcode-scan-gallery'),
                icon: Icons.photo_library_outlined,
                label: 'qrcode.scan.method.gallery'.tr,
                onPressed: controller.isBusy.value
                    ? null
                    : controller.scanFromGallery,
              ),
              const SizedBox(height: 12),
              _ScanMethodButton(
                key: const ValueKey('qrcode-scan-live-camera'),
                icon: Icons.center_focus_strong,
                label: 'qrcode.scan.method.live'.tr,
                filled: true,
                onPressed: controller.isBusy.value
                    ? null
                    : controller.scanFromLiveCamera,
              ),
              if (controller.isBusy.value) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (image != null) ...[
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: image.hasValidDimensions
                      ? image.width / image.height
                      : 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(image.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.black12,
                        child: Center(
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        secondary: ToolTaskSection(
          title: 'qrcode.scan.result.title'.tr,
          description: result == null ? 'qrcode.scan.result.empty'.tr : null,
          child: result == null
              ? const SizedBox.shrink()
              : _ScanResult(controller: controller, result: result),
        ),
      );
    });
  }
}

class _ScanMethodButton extends StatelessWidget {
  const _ScanMethodButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return filled
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}

class _ScanResult extends StatelessWidget {
  const _ScanResult({required this.controller, required this.result});

  final QrcodeController controller;
  final BarcodeScanResult result;

  @override
  Widget build(BuildContext context) {
    final originKey = switch (result.origin) {
      BarcodeScanOrigin.gallery => 'qrcode.scan.origin.gallery',
      BarcodeScanOrigin.liveCamera => 'qrcode.scan.origin.live',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('qrcode.scan.result.origin'.trParams({'origin': originKey.tr})),
        Text('qrcode.result.format'.trParams({'format': result.format})),
        Text(
          'qrcode.result.contentLength'.trParams({
            'length': '${result.text.length}',
          }),
        ),
        const SizedBox(height: 12),
        SelectableText(result.text),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: controller.copyScanText,
          icon: const Icon(Icons.copy_outlined),
          label: Text('qrcode.action.copyContent'.tr),
        ),
      ],
    );
  }
}
