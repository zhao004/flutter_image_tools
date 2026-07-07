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

enum MosaicDrawMode {
  freehand(labelKey: 'annotation.mosaic.freehand'),
  rectangle(labelKey: 'annotation.mosaic.rectangle'),
  circle(labelKey: 'annotation.mosaic.circle');

  const MosaicDrawMode({required this.labelKey});

  final String labelKey;

  String get label => labelKey.tr;
}

enum MosaicStrokeKind { freehand, rectangle, circle }

class DrawingStroke {
  const DrawingStroke({
    required this.mode,
    required this.kind,
    required this.color,
    required this.width,
    required this.points,
  });

  final AnnotationMode mode;
  final MosaicStrokeKind kind;
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
  static const double _defaultArrowLength = 180;
  static const Size _defaultRectangleSize = Size(140, 92);
  static const Size _defaultCircleSize = Size(120, 120);
  static const double _minDrawableSide = 16;
  static const double _maxShapeStrokeWidth = 32;
  static const String _defaultText = '请输入文字';

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImage = Rxn<LocalImageFile>();
  final result = Rxn<AnnotatedImageFile>();
  final mode = AnnotationMode.select.obs;
  final mosaicDrawMode = MosaicDrawMode.freehand.obs;
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

  bool get canUndo {
    editRevision.value;
    return painterController.canUndo || strokes.isNotEmpty;
  }

  bool get canRedo {
    editRevision.value;
    return painterController.canRedo;
  }

  @override
  void onInit() {
    super.onInit();
    painterController.addListener(_notifyPainterChanged);
    painterController.objectSettings = painterController.objectSettings
        .copyWith(
          // 设计意图：移动端默认会放大对象控制点；这里固定为较小尺寸，避免矩形/圆形四个拖动点遮挡图层。
          enlargeControlsResolver: () => false,
        );
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
    _updateSelectedShapeStrokeWidth(strokeWidth.value.toDouble());
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
    if (_canvasSize.width > 0 &&
        _canvasSize.height > 0 &&
        (painterController.drawables.isNotEmpty || strokes.isNotEmpty)) {
      _rescaleCanvasContent(from: _canvasSize, to: size);
    }
    _canvasSize = size;
  }

  void createDefaultTextLayer() {
    if (selectedImage.value == null) {
      _showError('annotation.error.pickImageFirst'.tr);
      return;
    }
    textController.text = _defaultText;
    addTextLayer(text: _defaultText);
  }

  void addTextLayer({String? text}) {
    final nextText = (text ?? textController.text).trim();
    if (selectedImage.value == null) {
      _showError('annotation.error.pickImageFirst'.tr);
      return;
    }
    if (nextText.isEmpty) {
      _showError('annotation.error.textRequired'.tr);
      return;
    }
    if (nextText.length > 40) {
      _showError('annotation.error.textTooLong'.trParams({'max': '40'}));
      return;
    }

    final drawable = TextDrawable(
      text: nextText,
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
    textController.text = nextText;
  }

  void addShapeLayer(EditableLayerType type) {
    if (selectedImage.value == null) {
      _showError('annotation.error.pickImageFirst'.tr);
      return;
    }

    final paint = _shapePaint(color.value.color, strokeWidth.value.toDouble());
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

  void addShapeFromDrag(EditableLayerType type, Offset start, Offset end) {
    if (selectedImage.value == null) {
      _showError('annotation.error.pickImageFirst'.tr);
      return;
    }
    if (!start.dx.isFinite ||
        !start.dy.isFinite ||
        !end.dx.isFinite ||
        !end.dy.isFinite) {
      return;
    }

    final delta = end - start;
    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    final paint = _shapePaint(color.value.color, strokeWidth.value.toDouble());
    final ObjectDrawable? drawable = switch (type) {
      EditableLayerType.text => null,
      EditableLayerType.rectangle => _rectangleFromDrag(center, delta, paint),
      EditableLayerType.circle => _circleFromDrag(center, delta, paint),
      EditableLayerType.arrow => _arrowFromDrag(start, end, paint),
    };
    if (drawable == null) {
      return;
    }
    _addObjectDrawable(drawable);
  }

  void selectShapeTool(EditableLayerType type) {
    final nextMode = switch (type) {
      EditableLayerType.text => AnnotationMode.text,
      EditableLayerType.rectangle => AnnotationMode.rectangle,
      EditableLayerType.circle => AnnotationMode.circle,
      EditableLayerType.arrow => AnnotationMode.arrow,
    };
    setMode(nextMode);
  }

  void selectObject(ObjectDrawable? drawable) {
    selectedObject.value = drawable;
    mode.value = AnnotationMode.select;
    if (drawable is ShapeDrawable) {
      strokeWidth.value = drawable.paint.strokeWidth
          .round()
          .clamp(2, _maxShapeStrokeWidth)
          .toInt();
    }
    _applyPainterMode();
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
    editRevision.value++;
  }

  void setMosaicDrawMode(MosaicDrawMode value) {
    mosaicDrawMode.value = value;
  }

  void addMosaicStroke(List<Offset> points, {required MosaicStrokeKind kind}) {
    if (points.length < 2) {
      return;
    }
    strokes.add(
      DrawingStroke(
        mode: AnnotationMode.mosaic,
        kind: kind,
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
      result.value = null;
      return;
    }
    if (painterController.canUndo) {
      painterController.undo();
      selectedObject.value = painterController.selectedObjectDrawable;
      editRevision.value++;
      result.value = null;
      return;
    }
    if (strokes.isNotEmpty) {
      strokes.removeLast();
      editRevision.value++;
      result.value = null;
    }
  }

  void redo() {
    if (!painterController.canRedo) {
      return;
    }
    painterController.redo();
    selectedObject.value = painterController.selectedObjectDrawable;
    editRevision.value++;
    result.value = null;
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

  void _rescaleCanvasContent({required Size from, required Size to}) {
    if (from.width <= 0 ||
        from.height <= 0 ||
        to.width <= 0 ||
        to.height <= 0) {
      return;
    }
    final scaleX = to.width / from.width;
    final scaleY = to.height / from.height;
    if (strokes.isNotEmpty) {
      final scaledStrokes = strokes
          .map(
            (stroke) => DrawingStroke(
              mode: stroke.mode,
              kind: stroke.kind,
              color: stroke.color,
              width: stroke.width * ((scaleX + scaleY) / 2),
              points: stroke.points
                  .map((point) => Offset(point.dx * scaleX, point.dy * scaleY))
                  .toList(growable: false),
            ),
          )
          .toList(growable: false);
      strokes.assignAll(scaledStrokes);
    }
    if (painterController.drawables.isEmpty) {
      editRevision.value++;
      return;
    }
    final updatedDrawables = painterController.drawables
        .map((drawable) {
          if (drawable is! ObjectDrawable) {
            return drawable;
          }
          return drawable.copyWith(
            position: Offset(
              drawable.position.dx * scaleX,
              drawable.position.dy * scaleY,
            ),
          );
        })
        .toList(growable: false);
    final selected = painterController.selectedObjectDrawable;
    final selectedIndex = selected == null
        ? -1
        : painterController.drawables.indexOf(selected);
    final nextSelected = selectedIndex < 0
        ? null
        : updatedDrawables[selectedIndex] as ObjectDrawable;
    painterController.value = painterController.value.copyWith(
      drawables: updatedDrawables,
      selectedObjectDrawable: nextSelected,
    );
    selectedObject.value = nextSelected;
    editRevision.value++;
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
      ShapeDrawable item => item.copyWith(
        paint: _shapePaint(nextColor, item.paint.strokeWidth),
      ),
      _ => null,
    };
    if (next == null) {
      return;
    }
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
  }

  void _updateSelectedShapeStrokeWidth(double width) {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable is! ShapeDrawable) {
      return;
    }
    final nextWidth = width.clamp(2, _maxShapeStrokeWidth).toDouble();
    final next = drawable.copyWith(
      paint: _shapePaint(drawable.paint.color, nextWidth),
    );
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
    result.value = null;
  }

  bool updateSelectedTextLayer() {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable is! TextDrawable) {
      return false;
    }
    final nextText = textController.text.trim();
    if (nextText.isEmpty) {
      _showError('annotation.error.textRequired'.tr);
      return false;
    }
    if (nextText.length > 40) {
      _showError('annotation.error.textTooLong'.trParams({'max': '40'}));
      return false;
    }
    final next = drawable.copyWith(text: nextText);
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
    result.value = null;
    return true;
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
      _drawMosaicStroke(canvas, paint, stroke, scaleX: scaleX, scaleY: scaleY);
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

  ObjectDrawable _rectangleFromDrag(Offset center, Offset delta, Paint paint) {
    final size = Size(
      delta.dx.abs().clamp(_minDrawableSide, double.infinity),
      delta.dy.abs().clamp(_minDrawableSide, double.infinity),
    );
    return RectangleDrawable(
      size: size,
      position: center,
      paint: paint,
      borderRadius: const BorderRadius.all(Radius.circular(4)),
    );
  }

  ObjectDrawable _circleFromDrag(Offset center, Offset delta, Paint paint) {
    final side = math
        .max(delta.dx.abs(), delta.dy.abs())
        .clamp(_minDrawableSide, double.infinity);
    return OvalDrawable(
      size: Size.square(side),
      position: center,
      paint: paint,
    );
  }

  ObjectDrawable _arrowFromDrag(Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final length = math.max(delta.distance, _minDrawableSide);
    final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    return ArrowDrawable(
      length: length,
      position: center,
      rotationAngle: math.atan2(delta.dy, delta.dx),
      paint: paint,
      arrowHeadSize: math.max(18, paint.strokeWidth * 4),
    );
  }

  void _drawMosaicStroke(
    Canvas canvas,
    Paint paint,
    DrawingStroke stroke, {
    required double scaleX,
    required double scaleY,
  }) {
    switch (stroke.kind) {
      case MosaicStrokeKind.freehand:
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
      case MosaicStrokeKind.rectangle:
      case MosaicStrokeKind.circle:
        final rect = _rectFromMosaicPoints(stroke.points);
        final scaledRect = Rect.fromLTRB(
          rect.left * scaleX,
          rect.top * scaleY,
          rect.right * scaleX,
          rect.bottom * scaleY,
        );
        if (stroke.kind == MosaicStrokeKind.rectangle) {
          canvas.drawRect(scaledRect, paint);
        } else {
          canvas.drawOval(scaledRect, paint);
        }
    }
  }

  Rect _rectFromMosaicPoints(List<Offset> points) {
    final start = points.first;
    final end = points.last;
    return Rect.fromLTRB(
      math.min(start.dx, end.dx),
      math.min(start.dy, end.dy),
      math.max(start.dx, end.dx),
      math.max(start.dy, end.dy),
    );
  }

  Paint _shapePaint(Color paintColor, double strokeWidth) {
    return Paint()
      ..color = paintColor
      ..strokeWidth = strokeWidth.clamp(2, _maxShapeStrokeWidth)
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
