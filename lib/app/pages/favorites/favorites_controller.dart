import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import '../../repositories/favorite_templates_repository.dart';

enum FavoriteFeaturePreset {
  compress(label: '图片压缩', value: '图片压缩'),
  resize(label: '尺寸调整', value: '尺寸调整'),
  watermark(label: '文字水印', value: '文字水印'),
  annotation(label: '图片标注', value: '图片标注');

  const FavoriteFeaturePreset({required this.label, required this.value});

  final String label;
  final String value;
}

/// 收藏模板控制器，负责管理常用功能参数模板。
///
/// 异常策略：参数必须是 JSON 对象，写入前先解析验证；删除和清空操作由页面
/// 先确认，Controller 只执行明确命令，避免误删用户常用配置。
class FavoritesController extends GetxController {
  FavoritesController({required FavoriteTemplatesRepository repository})
    : _repository = repository;

  final FavoriteTemplatesRepository _repository;

  final items = <FavoriteTemplate>[].obs;
  final isLoading = false.obs;
  final keyword = ''.obs;
  final feature = FavoriteFeaturePreset.compress.obs;
  final templateNameController = TextEditingController(text: '高质量导出');
  final parametersController = TextEditingController(
    text: const JsonEncoder.withIndent(
      '  ',
    ).convert(<String, Object>{'quality': 90, 'format': 'jpg'}),
  );

  @override
  void onInit() {
    super.onInit();
    loadTemplates();
  }

  @override
  void onClose() {
    templateNameController.dispose();
    parametersController.dispose();
    super.onClose();
  }

  Future<void> loadTemplates() async {
    isLoading.value = true;
    try {
      items.assignAll(
        await _repository.getFavoriteTemplates(keyword: keyword.value),
      );
    } catch (_) {
      Get.snackbar('读取失败', '收藏模板读取失败，请稍后重试');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateKeyword(String value) async {
    keyword.value = value;
    await loadTemplates();
  }

  void setFeature(FavoriteFeaturePreset value) {
    feature.value = value;
    parametersController.text = _defaultParametersFor(value);
  }

  Future<void> createTemplate() async {
    if (isLoading.value) {
      return;
    }
    final templateName = templateNameController.text.trim();
    if (templateName.isEmpty) {
      _showError('模板名称不能为空');
      return;
    }

    late final Map<String, Object?> parameters;
    try {
      parameters = _parseParameters(parametersController.text);
    } on FormatException catch (error) {
      _showError(error.message);
      return;
    }

    isLoading.value = true;
    try {
      await _repository.createTemplate(
        featureName: feature.value.value,
        templateName: templateName,
        parameters: parameters,
      );
      await loadTemplates();
      Get.snackbar('收藏完成', '模板已保存到本地');
    } catch (_) {
      _showError('模板保存失败，请重试');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteTemplate(FavoriteTemplate item) async {
    isLoading.value = true;
    try {
      await _repository.deleteTemplate(item.id);
      items.removeWhere((template) => template.id == item.id);
      Get.snackbar('删除完成', '模板已删除');
    } catch (_) {
      _showError('模板删除失败，请重试');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> clearTemplates() async {
    isLoading.value = true;
    try {
      await _repository.clearTemplates();
      items.clear();
      Get.snackbar('清理完成', '收藏模板已清空');
    } catch (_) {
      _showError('模板清理失败，请重试');
    } finally {
      isLoading.value = false;
    }
  }

  String formatDateTime(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String compactJson(String value) {
    try {
      final decoded = jsonDecode(value);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return value;
    }
  }

  Map<String, Object?> _parseParameters(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      throw const FormatException('模板参数不能为空');
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('模板参数必须是 JSON 对象');
    }
    return decoded;
  }

  String _defaultParametersFor(FavoriteFeaturePreset preset) {
    final parameters = switch (preset) {
      FavoriteFeaturePreset.compress => <String, Object>{
        'quality': 90,
        'format': 'jpg',
      },
      FavoriteFeaturePreset.resize => <String, Object>{
        'width': 1080,
        'keepAspectRatio': true,
      },
      FavoriteFeaturePreset.watermark => <String, Object>{
        'text': 'Image Toolkit',
        'position': 'bottomRight',
        'opacity': 70,
      },
      FavoriteFeaturePreset.annotation => <String, Object>{
        'mode': 'arrow',
        'color': '#E53935',
        'strokeWidth': 12,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(parameters);
  }

  void _showError(String message) {
    Get.snackbar('操作失败', message);
  }
}
