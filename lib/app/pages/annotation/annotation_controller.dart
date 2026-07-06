import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

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

class DrawingStroke {
  const DrawingStroke({
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

/// 图片编辑控制器，使用第三方画布库处理文字、形状、箭头、画笔和对象变换。
///
/// 设计意图：`flutter_painter_v2` 负责可移动、可旋转、可缩放对象与画笔；
/// 马赛克保留为独立涂抹层，导出时叠加到库渲染结果，兼顾稳定性和现有需求。
class AnnotationController extends GetxController {
  AnnotationController({
    required LocalImageChannel imageChannel,
    required OperationHistoryRepository historyRepository,
    required RecentFilesRepository recentFilesRepository,
  }) : _imageChannel = imageChannel,
       _historyRepository = historyRepository,
       _recentFilesRepository = recentFilesRepository;

  static const double _defaultTextSize = 32;
  static const double _defaultShapeStrokeWidth = 6;
  static const double _defaultArrowLength = 180;
  static const Size _defaultRectangleSize = Size(140, 92);
  static const Size _defaultCircleSize = Size(120, 120);

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImage = Rxn<LocalImageFile>();
  final result = Rxn<AnnotatedImageFile>();
  final mode = AnnotationMode.select.obs;
  final color = AnnotationColor.red.obs;
  final strokeWidth = 12.obs;
  final isBusy = false.obs;
  final strokes = <DrawingStroke>[].obs;
  final selectedObject = Rxn<ObjectDrawable>();
  final editRevision = 0.obs;
  final textController = TextEditingController();
  final painterController = PainterController();

  ui.Image? _backgroundImage;
  Size _canvasSize = Size.zero;

  bool get hasEdits {
    editRevision.value;
    return painterController.drawables.isNotEmpty || strokes.isNotEmpty;
  }

  @override
  void onInit() {
    super.onInit();
    painterController.addListener(_notifyPainterChanged);
    _applyPainterMode();
  }

  @override
  void onClose() {
    painterController.removeListener(_notifyPainterChanged);
    painterController.dispose();
    _backgroundImage?.dispose();
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
      await _loadBackground(image);
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
    if (value != AnnotationMode.select) {
      painterController.deselectObjectDrawable();
      selectedObject.value = null;
    }
    _applyPainterMode();
  }

  void setColor(AnnotationColor value) {
    color.value = value;
    _applyPainterMode();
    _updateSelectedObjectColor(value.color);
  }

  void updateStrokeWidth(double value) {
    strokeWidth.value = value.round().clamp(2, 60);
    _applyPainterMode();
  }

  void updateCanvasSize(Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }
    if ((_canvasSize.width - size.width).abs() < 0.5 &&
        (_canvasSize.height - size.height).abs() < 0.5) {
      return;
    }
    _canvasSize = size;
  }

  void addTextLayer() {
    final text = textController.text.trim();
    if (selectedImage.value == null) {
      _showError('annotation.error.pickImageFirst'.tr);
      return;
    }
    if (text.isEmpty) {
      _showError('annotation.error.textRequired'.tr);
      return;
    }
    if (text.length > 40) {
      _showError('annotation.error.textTooLong'.trParams({'max': '40'}));
      return;
    }

    final drawable = TextDrawable(
      text: text,
      position: _canvasCenter,
      style: TextStyle(
        color: color.value.color,
        fontSize: _defaultTextSize,
        fontWeight: FontWeight.w800,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
      ),
      direction: TextDirection.ltr,
    );
    _addObjectDrawable(drawable);
    textController.clear();
  }

  void addShapeLayer(EditableLayerType type) {
    if (selectedImage.value == null) {
      _showError('annotation.error.pickImageFirst'.tr);
      return;
    }

    final paint = _shapePaint(color.value.color);
    final ObjectDrawable drawable = switch (type) {
      EditableLayerType.text => throw const AppException('标注类型无效'),
      EditableLayerType.rectangle => RectangleDrawable(
        size: _defaultRectangleSize,
        position: _canvasCenter,
        paint: paint,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      EditableLayerType.circle => OvalDrawable(
        size: _defaultCircleSize,
        position: _canvasCenter,
        paint: paint,
      ),
      EditableLayerType.arrow => ArrowDrawable(
        length: _defaultArrowLength,
        position: _canvasCenter,
        paint: paint,
        arrowHeadSize: 24,
      ),
    };
    _addObjectDrawable(drawable);
  }

  void selectObject(ObjectDrawable? drawable) {
    selectedObject.value = drawable;
    mode.value = AnnotationMode.select;
    _applyPainterMode();
  }

  void updateSelectedObjectScale(double value) {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable == null) {
      return;
    }
    final next = drawable.copyWith(scale: value.clamp(0.4, 3.0));
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
  }

  void updateSelectedObjectRotation(double degrees) {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable == null) {
      return;
    }
    final radians = degrees.clamp(-180, 180) * math.pi / 180;
    final next = drawable.copyWith(rotation: radians);
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
  }

  void deleteSelectedObject() {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable == null) {
      return;
    }
    painterController.removeDrawable(drawable);
    painterController.deselectObjectDrawable(isRemoved: true);
    selectedObject.value = null;
    result.value = null;
  }

  void addMosaicStroke(List<Offset> points) {
    if (points.length < 2) {
      return;
    }
    strokes.add(
      DrawingStroke(
        mode: AnnotationMode.mosaic,
        color: Colors.black,
        width: strokeWidth.value.toDouble(),
        points: List<Offset>.unmodifiable(points),
      ),
    );
    editRevision.value++;
    result.value = null;
  }

  void undo() {
    if (mode.value == AnnotationMode.mosaic && strokes.isNotEmpty) {
      strokes.removeLast();
      editRevision.value++;
      return;
    }
    if (painterController.canUndo) {
      painterController.undo();
      selectedObject.value = painterController.selectedObjectDrawable;
      return;
    }
    if (strokes.isNotEmpty) {
      strokes.removeLast();
      editRevision.value++;
    }
  }

  void clearEdits({bool showMessage = true}) {
    painterController.clearDrawables();
    painterController.deselectObjectDrawable();
    strokes.clear();
    selectedObject.value = null;
    result.value = null;
    _applyPainterMode();
    editRevision.value++;
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
    if (!source.hasValidDimensions) {
      _showError('annotation.error.exportFailed'.tr);
      return;
    }
    final canvasSize = _validCanvasSize;
    if (canvasSize == null) {
      _showError('annotation.error.canvasUnavailable'.tr);
      return;
    }

    isBusy.value = true;
    try {
      final outputSize = Size(
        source.width.toDouble(),
        source.height.toDouble(),
      );
      final renderedImage = await painterController.renderImage(outputSize);
      final pngBytes = await _encodeWithMosaic(
        renderedImage,
        outputSize: outputSize,
        canvasSize: canvasSize,
      );
      if (pngBytes.isEmpty) {
        throw AppException('annotation.error.exportEmpty'.tr);
      }
      final output = await _createOutputFile(pngBytes);
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

  void _addObjectDrawable(ObjectDrawable drawable) {
    painterController.addDrawables([drawable]);
    painterController.selectObjectDrawable(drawable);
    selectedObject.value = drawable;
    mode.value = AnnotationMode.select;
    _applyPainterMode();
    result.value = null;
  }

  Future<void> _loadBackground(LocalImageFile image) async {
    if (image.path.trim().isEmpty) {
      throw AppException('annotation.error.pickImageFirst'.tr);
    }
    final file = File(image.path);
    if (!file.existsSync()) {
      throw AppException('annotation.error.pickImageFirst'.tr);
    }
    final background = await FileImage(file).image;
    _backgroundImage?.dispose();
    _backgroundImage = background;
    painterController.background = background.backgroundDrawable;
  }

  void _applyPainterMode() {
    final activeMode = mode.value;
    final nextFreeStyleMode = activeMode == AnnotationMode.brush
        ? FreeStyleMode.draw
        : FreeStyleMode.none;
    painterController.freeStyleSettings = FreeStyleSettings(
      mode: nextFreeStyleMode,
      color: color.value.color,
      strokeWidth: strokeWidth.value.toDouble(),
    );
    painterController.shapeSettings = const ShapeSettings(factory: null);
  }

  void _updateSelectedObjectColor(Color nextColor) {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable == null) {
      return;
    }
    final next = switch (drawable) {
      TextDrawable item => item.copyWith(
        style: item.style.copyWith(color: nextColor),
      ),
      ShapeDrawable item => item.copyWith(paint: _shapePaint(nextColor)),
      _ => null,
    };
    if (next == null) {
      return;
    }
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
  }

  Future<Uint8List> _encodeWithMosaic(
    ui.Image renderedImage, {
    required Size outputSize,
    required Size canvasSize,
  }) async {
    if (strokes.isEmpty) {
      final byteData = await renderedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List() ?? Uint8List(0);
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(renderedImage, Offset.zero, Paint());
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    final scaleX = outputSize.width / canvasSize.width;
    final scaleY = outputSize.height / canvasSize.height;
    for (final stroke in strokes) {
      for (final point in stroke.points) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(point.dx * scaleX, point.dy * scaleY),
            width: stroke.width * 1.8 * scaleX,
            height: stroke.width * 1.8 * scaleY,
          ),
          paint,
        );
      }
    }
    final image = await recorder.endRecording().toImage(
      outputSize.width.round(),
      outputSize.height.round(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List() ?? Uint8List(0);
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
      'layers': painterController.drawables.length,
      'strokes': strokes.length,
      'strokeWidth': strokeWidth.value,
      'color': color.value.value,
    };
  }

  void _notifyPainterChanged() {
    selectedObject.value = painterController.selectedObjectDrawable;
    editRevision.value++;
    result.value = null;
  }

  Offset get _canvasCenter =>
      Offset(_effectiveCanvasSize.width / 2, _effectiveCanvasSize.height / 2);

  Size get _effectiveCanvasSize {
    final canvasSize = _validCanvasSize;
    if (canvasSize != null) {
      return canvasSize;
    }
    final image = selectedImage.value;
    if (image == null || !image.hasValidDimensions) {
      return const Size(320, 320);
    }
    final ratio = image.width / image.height;
    const maxSide = 320.0;
    if (ratio >= 1) {
      return Size(maxSide, maxSide / ratio);
    }
    return Size(maxSide * ratio, maxSide);
  }

  Size? get _validCanvasSize {
    if (_canvasSize.width <= 0 ||
        _canvasSize.height <= 0 ||
        !_canvasSize.width.isFinite ||
        !_canvasSize.height.isFinite) {
      final contextSize = painterController.painterKey.currentContext?.size;
      if (contextSize == null ||
          contextSize.width <= 0 ||
          contextSize.height <= 0 ||
          !contextSize.width.isFinite ||
          !contextSize.height.isFinite) {
        return null;
      }
      return contextSize;
    }
    return _canvasSize;
  }

  Paint _shapePaint(Color paintColor) {
    return Paint()
      ..color = paintColor
      ..strokeWidth = _defaultShapeStrokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  void _showError(String message) {
    showLatestSnackbar('annotation.error.title'.tr, message);
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
