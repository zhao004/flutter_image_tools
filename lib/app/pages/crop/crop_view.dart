import 'dart:io';
import 'package:crop_your_image/crop_your_image.dart' as cropper;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../models/local_image_file.dart';
import '../../widgets/image_editor_scaffold.dart';
import 'crop_controller.dart';

/// 图片裁剪编辑页：选择图片后使用第三方裁剪组件处理裁剪框交互。
///
/// 设计意图：裁剪框拖动、缩放和比例约束交给 `crop_your_image` 管理，
/// 页面只负责把当前比例传给组件，并在用户点击保存时触发裁剪结果落盘。
class CropView extends GetView<CropController> {
  const CropView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'crop.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.crop_outlined,
        emptyTitle: 'crop.image.title'.tr,
        emptyMessage: 'crop.image.empty'.tr,
        pickLabel: 'crop.action.pickSingle'.tr,
        repickLabel: 'crop.action.repickSingle'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.save_outlined,
        onPickImage: controller.pickImage,
        onExport: controller.cropCurrentImage,
        lockPreviewScroll: true,
        imageMeta: image == null
            ? null
            : '${controller.formatDimensions(image)} · ${controller.currentRatioText()}',
        previewBuilder: (context, previewImage) => _CropEditor(
          key: ValueKey(
            '${previewImage.path}-${controller.preset.value.name}-${controller.currentRatioText()}',
          ),
          image: previewImage,
          controller: controller,
          aspectRatio: _previewAspectRatio(),
        ),
        bottomToolbar: _CropBottomToolPanel(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'crop.result.title'.tr,
                detail:
                    '${result.width} × ${result.height} px · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputPath,
              ),
      );
    });
  }

  double _previewAspectRatio() {
    final preset = controller.preset.value;
    if (preset != CropPreset.custom) {
      return preset.aspectRatio;
    }
    final width = double.tryParse(controller.customWidthController.text.trim());
    final height = double.tryParse(
      controller.customHeightController.text.trim(),
    );
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 1;
    }
    return (width / height).clamp(0.1, 10);
  }
}

class _CropBottomToolPanel extends StatelessWidget {
  const _CropBottomToolPanel({required this.controller});

  final CropController controller;

  @override
  Widget build(BuildContext context) {
    return EditorDynamicToolPanel(
      categories: [
        ToolCategory(
          id: 'ratio',
          name: 'crop.ratio.title'.tr,
          icon: Icons.crop_outlined,
          subItems: CropPreset.values
              .map(
                (preset) => ToolSubItem(
                  id: preset.name,
                  name: '${preset.labelKey.tr} ${preset.ratioText.tr}',
                  icon: _cropPresetIcon(preset),
                ),
              )
              .toList(growable: false),
        ),
      ],
      activeCategoryId: 'ratio',
      activeSubItemId: controller.preset.value.name,
      onCategorySelected: (_) {},
      onSubItemSelected: controller.isBusy.value
          ? null
          : (item) {
              final preset = CropPreset.values.firstWhereOrNull(
                (value) => value.name == item.id,
              );
              if (preset != null) {
                controller.setPreset(preset);
              }
            },
      activePanel: controller.preset.value == CropPreset.custom
          ? _CropCustomRatioPanel(controller: controller)
          : _CropRatioSummary(controller: controller),
      maxPanelHeight: 150,
      showPanelHeader: false,
    );
  }
}

class _CropEditor extends StatefulWidget {
  const _CropEditor({
    super.key,
    required this.image,
    required this.controller,
    required this.aspectRatio,
  });

  final LocalImageFile image;
  final CropController controller;
  final double aspectRatio;

  @override
  State<_CropEditor> createState() => _CropEditorState();
}

class _CropEditorState extends State<_CropEditor> {
  late Future<Uint8List> _imageBytesFuture;

  @override
  void initState() {
    super.initState();
    _imageBytesFuture = _readImageBytes(widget.image);
  }

  @override
  void didUpdateWidget(covariant _CropEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.path != widget.image.path) {
      _imageBytesFuture = _readImageBytes(widget.image);
    }
    if (oldWidget.aspectRatio != widget.aspectRatio) {
      widget.controller.cropEditorController.aspectRatio = widget.aspectRatio;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _imageBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(child: Text('crop.error.pickImageFirst'.tr));
        }
        final imageBytes = snapshot.data!;
        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: cropper.Crop(
                  image: imageBytes,
                  controller: widget.controller.cropEditorController,
                  aspectRatio: widget.aspectRatio,
                  initialRectBuilder:
                      cropper.InitialRectBuilder.withSizeAndRatio(
                        size: 0.88,
                        aspectRatio: widget.aspectRatio,
                      ),
                  interactive: true,
                  fixCropRect: false,
                  baseColor: Colors.black,
                  maskColor: Colors.black.withValues(alpha: 0.42),
                  radius: 6,
                  cornerDotBuilder: (size, edgeAlignment) =>
                      const cropper.DotControl(color: Colors.white),
                  progressIndicator: const CircularProgressIndicator(),
                  onCropped: (cropResult) {
                    switch (cropResult) {
                      case cropper.CropSuccess(:final croppedImage):
                        widget.controller.completeSingleCrop(croppedImage);
                      case cropper.CropFailure(:final cause):
                        widget.controller.failSingleCrop(cause);
                    }
                  },
                ),
              ),
            ),
            Positioned(top: 12, right: 12, child: const SizedBox.shrink()),
          ],
        );
      },
    );
  }

  Future<Uint8List> _readImageBytes(LocalImageFile image) async {
    final path = image.path.trim();
    if (path.isEmpty) {
      throw const FormatException('图片路径为空');
    }
    final file = File(path);
    if (!file.existsSync()) {
      throw const FileSystemException('图片文件不存在');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('图片文件为空');
    }
    return bytes;
  }
}

class _CropRatioSummary extends StatelessWidget {
  const _CropRatioSummary({required this.controller});

  final CropController controller;

  @override
  Widget build(BuildContext context) {
    return Text(
      'crop.ratio.current'.trParams({'ratio': controller.currentRatioText()}),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CropCustomRatioPanel extends StatelessWidget {
  const _CropCustomRatioPanel({required this.controller});

  final CropController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller.customWidthController,
            enabled: !controller.isBusy.value,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => controller.preset.refresh(),
            decoration: InputDecoration(
              labelText: 'crop.ratio.width'.tr,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller.customHeightController,
            enabled: !controller.isBusy.value,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => controller.preset.refresh(),
            decoration: InputDecoration(
              labelText: 'crop.ratio.height'.tr,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

IconData _cropPresetIcon(CropPreset preset) {
  return switch (preset) {
    CropPreset.square => Icons.crop_square,
    CropPreset.landscape16x9 || CropPreset.landscape4x3 => Icons.crop_landscape,
    CropPreset.portrait9x16 => Icons.crop_portrait,
    CropPreset.custom => Icons.tune,
  };
}
