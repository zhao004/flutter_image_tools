import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widgets/image_editor_scaffold.dart';
import 'filter_controller.dart';

/// 图片滤镜编辑页，选择图片后在编辑画布中实时预览滤镜效果。
///
/// 设计意图：滤镜选择放在底部工具栏，预览层使用轻量 ColorFilter 模拟
/// 视觉结果，导出仍走原生像素处理，保证输出质量和历史记录一致。
class FilterView extends GetView<FilterController> {
  const FilterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final image = controller.selectedImage.value;
      final result = controller.result.value;
      return ImageEditorScaffold(
        title: 'filter.title'.tr,
        selectedImage: image,
        isBusy: controller.isBusy.value,
        emptyIcon: Icons.filter_vintage_outlined,
        emptyTitle: 'filter.image.title'.tr,
        emptyMessage: 'filter.image.empty'.tr,
        pickLabel: 'filter.action.pickImage'.tr,
        repickLabel: 'filter.action.repickImage'.tr,
        exportLabel: 'common.saveToGallery'.tr,
        exportIcon: Icons.save_outlined,
        onPickImage: controller.pickImage,
        onExport: controller.applyFilter,
        imageMeta: image == null
            ? null
            : '${controller.formatDimensions(image)} · ${controller.formatBytes(image.sizeBytes)}',
        previewBuilder: (context, previewImage) => EditorImagePreview(
          image: previewImage,
          colorFilter: _colorFilterFor(controller.filter.value),
        ),
        toolbar: _FilterToolbar(controller: controller),
        resultSummary: result == null
            ? null
            : EditorResultPill(
                title: 'filter.result.title'.tr,
                detail:
                    '${controller.labelForFilterValue(result.filter)} · ${controller.formatBytes(result.outputSizeBytes)}',
                tooltip: result.outputPath,
              ),
      );
    });
  }

  ColorFilter? _colorFilterFor(ImageFilterType filter) {
    switch (filter) {
      case ImageFilterType.grayscale:
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.monochrome:
        return const ColorFilter.matrix([
          1.5,
          1.5,
          1.5,
          0,
          -180,
          1.5,
          1.5,
          1.5,
          0,
          -180,
          1.5,
          1.5,
          1.5,
          0,
          -180,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.sepia:
        return const ColorFilter.matrix([
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.invert:
        return const ColorFilter.matrix([
          -1,
          0,
          0,
          0,
          255,
          0,
          -1,
          0,
          0,
          255,
          0,
          0,
          -1,
          0,
          255,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.warm:
        return const ColorFilter.matrix([
          1.12,
          0,
          0,
          0,
          10,
          0,
          1.02,
          0,
          0,
          2,
          0,
          0,
          0.90,
          0,
          -8,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.cool:
        return const ColorFilter.matrix([
          0.90,
          0,
          0,
          0,
          -8,
          0,
          1.02,
          0,
          0,
          2,
          0,
          0,
          1.14,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.hdr:
        return const ColorFilter.matrix([
          1.25,
          0,
          0,
          0,
          -16,
          0,
          1.25,
          0,
          0,
          -16,
          0,
          0,
          1.25,
          0,
          -16,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.film:
        return const ColorFilter.matrix([
          1.05,
          0.05,
          0,
          0,
          8,
          0.04,
          0.98,
          0.02,
          0,
          4,
          0,
          0.06,
          0.92,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.sharpen:
        return const ColorFilter.matrix([
          1.12,
          0,
          0,
          0,
          -6,
          0,
          1.12,
          0,
          0,
          -6,
          0,
          0,
          1.12,
          0,
          -6,
          0,
          0,
          0,
          1,
          0,
        ]);
      case ImageFilterType.soften:
        return const ColorFilter.matrix([
          0.94,
          0.03,
          0.03,
          0,
          4,
          0.03,
          0.94,
          0.03,
          0,
          4,
          0.03,
          0.03,
          0.94,
          0,
          4,
          0,
          0,
          0,
          1,
          0,
        ]);
    }
  }
}

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({required this.controller});

  final FilterController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'filter.type.title'.tr,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        EditorOptionWrap<ImageFilterType>(
          values: ImageFilterType.values,
          selected: controller.filter.value,
          labelFor: (value) => value.label,
          enabled: !controller.isBusy.value,
          onSelected: controller.setFilter,
        ),
      ],
    );
  }
}
