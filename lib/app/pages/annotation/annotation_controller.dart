import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart' as signature;

import '../../exceptions/app_exception.dart';
import '../../models/annotated_image_file.dart';
import '../../models/local_image_file.dart';
import '../../repositories/operation_history_repository.dart';
import '../../repositories/recent_files_repository.dart';
import '../../services/local_image_channel.dart';
import '../../utils/latest_snackbar.dart';

enum AnnotationMode {
  select(labelKey: 'annotation.mode.select', value: 'select'),
  brush(labelKey: 'annotation.mode.brush', value: 'brush'),
  mosaic(labelKey: 'annotation.mode.mosaic', value: 'mosaic'),
  text(labelKey: 'annotation.mode.text', value: 'text'),
  rectangle(labelKey: 'annotation.mode.rectangle', value: 'rectangle'),
  circle(labelKey: 'annotation.mode.circle', value: 'circle'),
  arrow(labelKey: 'annotation.mode.arrow', value: 'arrow');

  const AnnotationMode({required this.labelKey, required this.value});

  final String labelKey;
  final String value;

  String get label => labelKey.tr;
}

enum AnnotationColor {
  red(labelKey: 'annotation.color.red', value: '#E53935'),
  yellow(labelKey: 'annotation.color.yellow', value: '#FDD835'),
  blue(labelKey: 'annotation.color.blue', value: '#1E88E5'),
  green(labelKey: 'annotation.color.green', value: '#43A047'),
  white(labelKey: 'annotation.color.white', value: '#FFFFFF');

  const AnnotationColor({required this.labelKey, required this.value});

  final String labelKey;
  final String value;

  String get label => labelKey.tr;

  Color get color => _colorFromHex(value);
}

enum EditableLayerType { text, rectangle, circle, arrow }

class EditableLayer {
  EditableLayer({
    required this.id,
    required this.type,
    required this.position,
    required this.color,
    this.text = '',
    this.rotation = 0,
    this.scale = 1,
  });

  final int id;
  final EditableLayerType type;
  Offset position;
  Color color;
  String text;
  double rotation;
  double scale;

  EditableLayer copy() {
    return EditableLayer(
      id: id,
      type: type,
      position: position,
      color: color,
      text: text,
      rotation: rotation,
      scale: scale,
    );
  }
}

class DrawingStroke {
  DrawingStroke({
    required this.mode,
    required this.color,
    required this.width,
    required this.points,
  });

  final AnnotationMode mode;
  final Color color;
  final double width;
  final List<Offset> points;
}

/// 图片编辑控制器，管理选图、图层、涂抹轨迹、变换参数和截图导出。
///
/// 设计意图：编辑操作先在 Flutter 画布中完成，文字/形状/箭头使用图层模型，
/// 画笔和马赛克使用路径模型；导出时截图整个编辑画布，避免覆盖原图。
class AnnotationController extends GetxController {
  AnnotationController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _imageChannel = imageChannel,
       _historyRepository = historyRepository,
       _recentFilesRepository = recentFilesRepository;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final canvasKey = GlobalKey();
  final selectedImage = Rxn<LocalImageFile>();
  final result = Rxn<AnnotatedImageFile>();
  final mode = AnnotationMode.select.obs;
  final color = AnnotationColor.red.obs;
  final strokeWidth = 12.obs;
  final isBusy = false.obs;
  final layers = <EditableLayer>[].obs;
  final strokes = <DrawingStroke>[].obs;
  final selectedLayerId = RxnInt();
  final textController = TextEditingController();
  final signatureController = signature.SignatureController(
    penColor: Colors.red,
    penStrokeWidth: 12,
    strokeCap: StrokeCap.round,
    strokeJoin: StrokeJoin.round,
  );

  int _nextLayerId = 1;

  EditableLayer? get selectedLayer {
    final id = selectedLayerId.value;
    if (id == null) {
      return null;
    }
    for (final layer in layers) {
      if (layer.id == id) {
        return layer;
      }
    }
    return null;
  }

  bool get hasEdits =>
      layers.isNotEmpty || strokes.isNotEmpty || signatureController.isNotEmpty;

  @override
  void onClose() {
    signatureController.dispose();
    textController.dispose();
    super.onClose();
  }

  Future<void> pickImage() async {
    if (isBusy.value) {
      return;
    }
    try {
      final image = await _imageChannel.pickSingleImage();
      if (image == null) {
        return;
      }
      selectedImage.value = image;
      result.value = null;
      clearEdits(showMessage: false);
      await _recentFilesRepository.recordImage(image);
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('annotation.error.recentFileFailed'.tr);
    }
  }

  void setMode(AnnotationMode value) {
    mode.value = value;
    if (value == AnnotationMode.brush || value == AnnotationMode.mosaic) {
      selectedLayerId.value = null;
    }
  }

  void setColor(AnnotationColor value) {
    color.value = value;
    final layer = selectedLayer;
    if (layer != null) {
      layer.color = value.color;
      layers.refresh();
    }
  }

  void updateStrokeWidth(double value) {
    strokeWidth.value = value.round().clamp(2, 60);
  }

  void addTextLayer() {
    final text = textController.text.trim();
    if (text.isEmpty) {
      _showError('annotation.error.textRequired'.tr);
      return;
    }
    if (text.length > 40) {
      _showError('annotation.error.textTooLong'.trParams({'max': '40'}));
      return;
    }
    _addLayer(EditableLayerType.text, text: text);
    textController.clear();
  }

  void addShapeLayer(EditableLayerType type) {
    _addLayer(type);
  }

  void selectLayer(int id) {
    selectedLayerId.value = id;
    mode.value = AnnotationMode.select;
  }

  void moveSelectedLayer(Offset delta) {
    final layer = selectedLayer;
    if (layer == null) {
      return;
    }
    layer.position += delta;
    layers.refresh();
  }

  void updateSelectedLayerScale(double value) {
    final layer = selectedLayer;
    if (layer == null) {
      return;
    }
    layer.scale = value.clamp(0.4, 3.0);
    layers.refresh();
  }

  void updateSelectedLayerRotation(double value) {
    final layer = selectedLayer;
    if (layer == null) {
      return;
    }
    layer.rotation = value.clamp(-180, 180);
    layers.refresh();
  }

  void deleteSelectedLayer() {
    final id = selectedLayerId.value;
    if (id == null) {
      return;
    }
    layers.removeWhere((layer) => layer.id == id);
    selectedLayerId.value = null;
  }

  void addStroke({
    required AnnotationMode strokeMode,
    required List<Offset> points,
  }) {
    if (points.length < 2) {
      return;
    }
    strokes.add(
      DrawingStroke(
        mode: strokeMode,
        color: color.value.color,
        width: strokeWidth.value.toDouble(),
        points: List<Offset>.unmodifiable(points),
      ),
    );
    _syncSignatureController();
    result.value = null;
  }

  void undo() {
    if (selectedLayerId.value != null) {
      deleteSelectedLayer();
      return;
    }
    if (strokes.isNotEmpty) {
      strokes.removeLast();
      _syncSignatureController();
      return;
    }
    if (layers.isNotEmpty) {
      layers.removeLast();
    }
  }

  void clearEdits({bool showMessage = true}) {
    layers.clear();
    strokes.clear();
    signatureController.clear();
    selectedLayerId.value = null;
    result.value = null;
    if (showMessage) {
      showLatestSnackbar(
        'annotation.clear.success.title'.tr,
        'annotation.clear.success.message'.tr,
      );
    }
  }

  Future<void> exportEditedImage() async {
    if (isBusy.value) {
      return;
    }
    final source = selectedImage.value;
    if (source == null) {
      _showError('annotation.error.pickImageFirst'.tr);
      return;
    }
    if (!hasEdits) {
      _showError('annotation.error.noEdits'.tr);
      return;
    }

    isBusy.value = true;
    try {
      final boundary =
          canvasKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw AppException('annotation.error.canvasUnavailable'.tr);
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw AppException('annotation.error.exportEmpty'.tr);
      }
      final output = await _createOutputFile(byteData.buffer.asUint8List());
      await _imageChannel.saveImageToGallery(output.path);
      final annotated = AnnotatedImageFile(
        source: source,
        outputPath: output.path,
        outputSizeBytes: await output.length(),
        mode: 'editor',
      );
      result.value = annotated;
      await _historyRepository.recordOperationSuccess(
        featureName: 'annotation.featureName'.tr,
        inputPath: source.path,
        outputPath: output.path,
        parameters: _historyParameters(),
      );
      showLatestSnackbar(
        'annotation.export.success.title'.tr,
        'annotation.export.success.message'.tr,
      );
    } catch (error) {
      await _historyRepository.recordOperationFailure(
        featureName: 'annotation.featureName'.tr,
        inputPath: source.path,
        parameters: _historyParameters(),
        errorMessage: error is AppException ? error.message : '$error',
      );
      _showError(
        error is AppException
            ? error.message
            : 'annotation.error.exportFailed'.tr,
      );
    } finally {
      isBusy.value = false;
    }
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) {
      return 'common.unknownSize'.tr;
    }
    const unit = 1024;
    if (bytes < unit) {
      return '$bytes B';
    }
    final kib = bytes / unit;
    if (kib < unit) {
      return '${kib.toStringAsFixed(1)} KB';
    }
    final mib = kib / unit;
    return '${mib.toStringAsFixed(1)} MB';
  }

  String formatDimensions(LocalImageFile image) {
    if (!image.hasValidDimensions) {
      return 'annotation.dimension.unknown'.tr;
    }
    return '${image.width} × ${image.height} px';
  }

  String labelForModeValue(String value) {
    for (final mode in AnnotationMode.values) {
      if (mode.value == value) {
        return mode.label;
      }
    }
    return value == 'editor' ? 'annotation.mode.editor'.tr : value;
  }

  void _addLayer(EditableLayerType type, {String text = ''}) {
    if (selectedImage.value == null) {
      _showError('annotation.error.pickImageFirst'.tr);
      return;
    }
    final layer = EditableLayer(
      id: _nextLayerId++,
      type: type,
      position: const Offset(0, 0),
      color: color.value.color,
      text: text,
    );
    layers.add(layer);
    selectedLayerId.value = layer.id;
    mode.value = AnnotationMode.select;
    result.value = null;
  }

  Future<File> _createOutputFile(Uint8List bytes) async {
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/edited_images');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final output = File(
      '${directory.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await output.writeAsBytes(bytes, flush: true);
    return output;
  }

  Map<String, Object> _historyParameters() {
    return <String, Object>{
      'mode': 'editor',
      'layers': layers.length,
      'strokes': strokes.length,
      'strokeWidth': strokeWidth.value,
      'color': color.value.value,
    };
  }

  void _showError(String message) {
    showLatestSnackbar('annotation.error.title'.tr, message);
  }

  void _syncSignatureController() {
    final points = <signature.Point>[];
    for (final stroke in strokes) {
      if (stroke.mode != AnnotationMode.brush) {
        continue;
      }
      for (var index = 0; index < stroke.points.length; index++) {
        points.add(
          signature.Point(
            stroke.points[index],
            index == 0 ? signature.PointType.tap : signature.PointType.move,
            1,
          ),
        );
      }
    }
    signatureController.points = points;
  }
}

Color _colorFromHex(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return Colors.red;
  }
  return Color(0xFF000000 | parsed);
}

double degreesToRadians(double value) => value * math.pi / 180;
