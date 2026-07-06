import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import '../../repositories/favorite_templates_repository.dart';

enum FavoriteFeaturePreset {
  compress(labelKey: 'favorites.feature.compress', value: '图片压缩'),
  resize(labelKey: 'favorites.feature.resize', value: '尺寸调整'),
  watermark(labelKey: 'favorites.feature.watermark', value: '文字水印'),
  annotation(labelKey: 'favorites.feature.annotation', value: '图片标注');

  const FavoriteFeaturePreset({required this.labelKey, required this.value});

  final String labelKey;
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
  final templateNameController = TextEditingController(
    text: 'favorites.defaultTemplateName'.tr,
  );
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
      Get.snackbar(
        'favorites.read.failed.title'.tr,
        'favorites.read.failed.message'.tr,
      );
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
      _showError('favorites.validation.nameRequired'.tr);
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
      Get.snackbar(
        'favorites.create.success.title'.tr,
        'favorites.create.success.message'.tr,
      );
    } catch (_) {
      _showError('favorites.create.failed.message'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteTemplate(FavoriteTemplate item) async {
    isLoading.value = true;
    try {
      await _repository.deleteTemplate(item.id);
      items.removeWhere((template) => template.id == item.id);
      Get.snackbar(
        'favorites.delete.success.title'.tr,
        'favorites.delete.success.message'.tr,
      );
    } catch (_) {
      _showError('favorites.delete.failed.message'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> clearTemplates() async {
    isLoading.value = true;
    try {
      await _repository.clearTemplates();
      items.clear();
      Get.snackbar(
        'favorites.clear.success.title'.tr,
        'favorites.clear.success.message'.tr,
      );
    } catch (_) {
      _showError('favorites.clear.failed.message'.tr);
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
      throw FormatException('favorites.validation.parametersRequired'.tr);
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('favorites.validation.parametersObject'.tr);
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
    Get.snackbar('favorites.operation.failed.title'.tr, message);
  }
}
