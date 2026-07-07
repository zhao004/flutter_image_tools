import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_painter_v2/flutter_painter.dart';
import 'package:get/get.dart';

import '../../exceptions/app_exception.dart';
import '../../models/annotated_image_file.dart';
import '../../models/local_image_file.dart';
import '../filter/filter_controller.dart';
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
  arrow(labelKey: 'annotation.mode.arrow', value: 'arrow'),
  filter(labelKey: 'annotation.mode.filter', value: 'filter'),
  rotate(labelKey: 'annotation.mode.rotate', value: 'rotate'),
  flip(labelKey: 'annotation.mode.flip', value: 'flip'),
  resize(labelKey: 'annotation.mode.resize', value: 'resize'),
  crop(labelKey: 'annotation.mode.crop', value: 'crop');

  const AnnotationMode({required this.labelKey, required this.value});

  final String labelKey;
  final String value;

  String get label => labelKey.tr;
}

enum EditableLayerType { text, rectangle, circle, arrow }

enum AnnotationTextFont {
  system(labelKey: 'annotation.text.font.system', family: null),
  serif(labelKey: 'annotation.text.font.serif', family: 'serif'),
  sansSerif(labelKey: 'annotation.text.font.sansSerif', family: 'sans-serif'),
  monospace(labelKey: 'annotation.text.font.monospace', family: 'monospace');

  const AnnotationTextFont({required this.labelKey, required this.family});

  final String labelKey;
  final String? family;

  String get label => labelKey.tr;
}

enum EditableArrowStyle {
  solid(labelKey: 'annotation.arrow.solid'),
  outline(labelKey: 'annotation.arrow.outline');

  const EditableArrowStyle({required this.labelKey});

  final String labelKey;

  String get label => labelKey.tr;
}

enum MosaicDrawMode {
  freehand(labelKey: 'annotation.mosaic.freehand'),
  rectangle(labelKey: 'annotation.mosaic.rectangle'),
  circle(labelKey: 'annotation.mosaic.circle');

  const MosaicDrawMode({required this.labelKey});

  final String labelKey;

  String get label => labelKey.tr;
}

enum MosaicStrokeKind { freehand, rectangle, circle }

enum AnnotationShapeScaleCorner { topLeft, topRight, bottomLeft, bottomRight }

class AnnotationShapeScaleHandle {
  const AnnotationShapeScaleHandle({
    required this.corner,
    required this.center,
  });

  final AnnotationShapeScaleCorner corner;
  final Offset center;
}

enum AnnotationCropPreset {
  original(labelKey: 'annotation.crop.original', aspectRatio: null),
  square(labelKey: 'crop.preset.square', aspectRatio: 1),
  landscape16x9(labelKey: 'crop.preset.landscape16x9', aspectRatio: 16 / 9),
  landscape4x3(labelKey: 'crop.preset.landscape4x3', aspectRatio: 4 / 3),
  portrait9x16(labelKey: 'crop.preset.portrait9x16', aspectRatio: 9 / 16);

  const AnnotationCropPreset({
    required this.labelKey,
    required this.aspectRatio,
  });

  final String labelKey;
  final double? aspectRatio;

  String get label => labelKey.tr;
}

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

  DrawingStroke copyWith({Color? color, double? width, List<Offset>? points}) {
    return DrawingStroke(
      mode: mode,
      kind: kind,
      color: color ?? this.color,
      width: width ?? this.width,
      points: List<Offset>.unmodifiable(points ?? this.points),
    );
  }
}

class AnnotationObjectControlGeometry {
  const AnnotationObjectControlGeometry({
    this.rotateHandle,
    this.shapeScaleHandles = const <AnnotationShapeScaleHandle>[],
    this.arrowStart,
    this.arrowEnd,
    this.arrowDirectionHandle,
  });

  final Offset? rotateHandle;
  final List<AnnotationShapeScaleHandle> shapeScaleHandles;
  final Offset? arrowStart;
  final Offset? arrowEnd;
  final Offset? arrowDirectionHandle;
}

/// 可编辑箭头图层，支持实心/空心箭头并暴露稳定的首尾端点。
///
/// 设计意图：第三方默认箭头只支持实心箭头且端点控制有限，因此在本地实现
/// 一个兼容 `ObjectDrawable` 的箭头，避免修改依赖源码。
class EditableArrowDrawable extends ObjectDrawable implements ShapeDrawable {
  EditableArrowDrawable({
    required this.length,
    required super.position,
    required this.paint,
    required this.style,
    this.arrowHeadSize,
    super.rotationAngle = 0,
    super.scale = 1,
    super.assists = const <ObjectDrawableAssist>{},
    super.assistPaints = const <ObjectDrawableAssist, Paint>{},
    super.locked = false,
    super.hidden = false,
  });

  final double length;
  final double? arrowHeadSize;
  final EditableArrowStyle style;

  @override
  Paint paint;

  double get _headSize => arrowHeadSize ?? math.max(18, paint.strokeWidth * 4);

  @override
  void drawObject(Canvas canvas, Size size) {
    final headSize = _headSize;
    final halfLength = length * scale / 2;
    final start = position.translate(-halfLength, 0);
    final headBaseX = position.dx + halfLength - headSize;
    final tip = position.translate(halfLength, 0);
    final shaftEnd = Offset(headBaseX, position.dy);
    if ((shaftEnd - start).distance > 0) {
      canvas.drawLine(start, shaftEnd, paint);
    }

    final headPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(headBaseX, position.dy - headSize / 2)
      ..lineTo(headBaseX, position.dy + headSize / 2)
      ..close();
    final headPaint = Paint()
      ..color = paint.color
      ..strokeWidth = paint.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = style == EditableArrowStyle.solid
          ? PaintingStyle.fill
          : PaintingStyle.stroke;
    canvas.drawPath(headPath, headPaint);
  }

  @override
  Size getSize({double minWidth = 0.0, double maxWidth = double.infinity}) {
    final width = math.max(minWidth, length * scale + paint.strokeWidth);
    final height = _headSize + paint.strokeWidth * 2;
    return Size(width, height);
  }

  @override
  EditableArrowDrawable copyWith({
    bool? hidden,
    Set<ObjectDrawableAssist>? assists,
    Offset? position,
    double? rotation,
    double? scale,
    double? length,
    Paint? paint,
    bool? locked,
    double? arrowHeadSize,
    EditableArrowStyle? style,
    Map<ObjectDrawableAssist, Paint>? assistPaints,
  }) {
    return EditableArrowDrawable(
      hidden: hidden ?? this.hidden,
      assists: assists ?? this.assists,
      assistPaints: assistPaints ?? this.assistPaints,
      position: position ?? this.position,
      rotationAngle: rotation ?? rotationAngle,
      scale: scale ?? this.scale,
      length: length ?? this.length,
      paint: paint ?? this.paint,
      locked: locked ?? this.locked,
      arrowHeadSize: arrowHeadSize ?? this.arrowHeadSize,
      style: style ?? this.style,
    );
  }
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
  static const double minTextSize = 12;
  static const double maxTextSize = 96;
  static const double _defaultArrowLength = 180;
  static const Size _defaultRectangleSize = Size(140, 92);
  static const Size _defaultCircleSize = Size(120, 120);
  static const double _minDrawableSide = 16;
  static const double _maxShapeStrokeWidth = 32;
  static const Color _defaultAnnotationColor = Color(0xFFE53935);
  static const String _defaultText = '请输入文字';
  static const int _minResizeDimension = 1;
  static const int _maxResizeDimension = LocalImageChannel.maxResizeDimension;

  final LocalImageChannel _imageChannel;
  final OperationHistoryRepository _historyRepository;
  final RecentFilesRepository _recentFilesRepository;

  final selectedImage = Rxn<LocalImageFile>();
  final result = Rxn<AnnotatedImageFile>();
  final mode = AnnotationMode.select.obs;
  final isPropertyPanelVisible = false.obs;
  final mosaicDrawMode = MosaicDrawMode.freehand.obs;
  final arrowStyle = EditableArrowStyle.solid.obs;
  final color = _defaultAnnotationColor.obs;
  final strokeWidth = 12.obs;
  final isBusy = false.obs;
  final strokes = <DrawingStroke>[].obs;
  final selectedObject = Rxn<ObjectDrawable>();
  final selectedMosaicIndex = RxnInt();
  final editRevision = 0.obs;
  final textController = TextEditingController();
  final textSize = _defaultTextSize.obs;
  final textFont = AnnotationTextFont.system.obs;
  final painterController = PainterController();
  final filter = Rxn<ImageFilterType>();
  final rotationDegrees = 0.obs;
  final flipHorizontal = false.obs;
  final flipVertical = false.obs;
  final resizeKeepAspectRatio = true.obs;
  final resizePercent = 100.0.obs;
  final cropPreset = AnnotationCropPreset.original.obs;
  final resizeWidthController = TextEditingController();
  final resizeHeightController = TextEditingController();

  ui.Image? _backgroundImage;
  Size _canvasSize = Size.zero;

  bool get hasEdits {
    editRevision.value;
    return painterController.drawables.isNotEmpty ||
        strokes.isNotEmpty ||
        hasImageAdjustments;
  }

  bool get hasImageAdjustments {
    editRevision.value;
    final image = selectedImage.value;
    return filter.value != null ||
        rotationDegrees.value % 360 != 0 ||
        flipHorizontal.value ||
        flipVertical.value ||
        cropPreset.value.aspectRatio != null ||
        _hasResizeAdjustment(image);
  }

  double previewAspectRatioFor(LocalImageFile image) {
    editRevision.value;
    final size = previewSizeFor(image);
    return _safeAspectRatio(size.width, size.height);
  }

  Size previewSizeFor(LocalImageFile image) {
    editRevision.value;
    if (!image.hasValidDimensions) {
      return const Size(1, 1);
    }

    var width = image.width.toDouble();
    var height = image.height.toDouble();
    final cropAspectRatio = cropPreset.value.aspectRatio;
    if (cropAspectRatio != null && cropAspectRatio.isFinite) {
      final sourceAspectRatio = _safeAspectRatio(width, height);
      if (sourceAspectRatio > cropAspectRatio) {
        width = height * cropAspectRatio;
      } else {
        height = width / cropAspectRatio;
      }
    }

    final normalizedRotation = rotationDegrees.value.abs() % 180;
    if (normalizedRotation == 90) {
      final nextWidth = height;
      height = width;
      width = nextWidth;
    }

    final resizeDimensions = _hasResizeAdjustment(image)
        ? _readResizeDimensions(showError: false)
        : null;
    if (resizeDimensions != null) {
      width = resizeDimensions.width.toDouble();
      height = resizeDimensions.height.toDouble();
    }

    return Size(
      width.clamp(1, _maxResizeDimension).toDouble(),
      height.clamp(1, _maxResizeDimension).toDouble(),
    );
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
          showScaleRotationControlsResolver: () => false,
        );
    _applyPainterMode();
  }

  @override
  void onClose() {
    painterController.removeListener(_notifyPainterChanged);
    painterController.dispose();
    _backgroundImage?.dispose();
    textController.dispose();
    resizeWidthController.dispose();
    resizeHeightController.dispose();
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
      _resetImageAdjustments(image);
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
    isPropertyPanelVisible.value = value != AnnotationMode.select;
    if (_isLayerCreationMode(value) || _isImageProcessingMode(value)) {
      painterController.deselectObjectDrawable();
      selectedObject.value = null;
      selectedMosaicIndex.value = null;
    }
    _applyPainterMode();
  }

  void closePropertyPanel() {
    isPropertyPanelVisible.value = false;
  }

  void setFilter(ImageFilterType? value) {
    filter.value = value;
    _markImageAdjustmentChanged();
  }

  void setRotationDegrees(int degrees) {
    rotationDegrees.value = degrees.clamp(-360, 360);
    _markImageAdjustmentChanged();
  }

  void rotateByQuarterTurn(int degrees) {
    final normalized = (rotationDegrees.value + degrees) % 360;
    rotationDegrees.value = normalized > 180 ? normalized - 360 : normalized;
    _markImageAdjustmentChanged();
  }

  void setFlipHorizontal(bool value) {
    flipHorizontal.value = value;
    _markImageAdjustmentChanged();
  }

  void setFlipVertical(bool value) {
    flipVertical.value = value;
    _markImageAdjustmentChanged();
  }

  void setCropPreset(AnnotationCropPreset value) {
    cropPreset.value = value;
    _markImageAdjustmentChanged();
  }

  void setResizeKeepAspectRatio(bool value) {
    resizeKeepAspectRatio.value = value;
    final image = selectedImage.value;
    if (value && image != null && image.hasValidDimensions) {
      _syncResizeHeightFromWidth(image);
    }
    _markImageAdjustmentChanged();
  }

  void updateResizeWidth(String value) {
    resizeWidthController.text = value;
    final image = selectedImage.value;
    if (resizeKeepAspectRatio.value &&
        image != null &&
        image.hasValidDimensions) {
      _syncResizeHeightFromWidth(image);
    }
    _updateResizePercentFromFields(image);
    _markImageAdjustmentChanged();
  }

  void updateResizeHeight(String value) {
    resizeHeightController.text = value;
    final image = selectedImage.value;
    if (resizeKeepAspectRatio.value &&
        image != null &&
        image.hasValidDimensions) {
      _syncResizeWidthFromHeight(image);
    }
    _updateResizePercentFromFields(image);
    _markImageAdjustmentChanged();
  }

  void updateResizePercent(double value) {
    final image = selectedImage.value;
    if (image == null || !image.hasValidDimensions) {
      return;
    }
    final percent = value.clamp(10, 300).toDouble();
    resizePercent.value = percent;
    resizeWidthController.text = _scaleDimension(
      image.width,
      percent,
    ).toString();
    resizeHeightController.text = _scaleDimension(
      image.height,
      percent,
    ).toString();
    _markImageAdjustmentChanged();
  }

  String get colorHex {
    final rgb = color.value.toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void setColor(Color value) {
    color.value = value;
    _applyPainterMode();
    _updateSelectedObjectColor(value);
    _updateSelectedMosaicColor(value);
    result.value = null;
    editRevision.value++;
  }

  void updateStrokeWidth(double value) {
    strokeWidth.value = value.round().clamp(2, 60);
    _applyPainterMode();
    _updateSelectedShapeStrokeWidth(strokeWidth.value.toDouble());
    _updateSelectedMosaicStrokeWidth(strokeWidth.value.toDouble());
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
      style: _textStyle(color: color.value),
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

    final paint = _shapePaint(color.value, strokeWidth.value.toDouble());
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
      EditableLayerType.arrow => EditableArrowDrawable(
        length: _defaultArrowLength,
        position: _canvasCenter,
        paint: paint,
        style: arrowStyle.value,
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
    final paint = _shapePaint(color.value, strokeWidth.value.toDouble());
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
    selectedMosaicIndex.value = null;
    mode.value = AnnotationMode.select;
    if (drawable != null) {
      isPropertyPanelVisible.value = true;
    }
    if (drawable is TextDrawable) {
      _syncTextControlsFromDrawable(drawable);
    }
    if (drawable is ShapeDrawable) {
      strokeWidth.value = drawable.paint.strokeWidth
          .round()
          .clamp(2, _maxShapeStrokeWidth)
          .toInt();
    }
    if (drawable is EditableArrowDrawable) {
      arrowStyle.value = drawable.style;
    }
    _applyPainterMode();
  }

  void deleteSelectedObject() {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable == null) {
      deleteSelectedMosaic();
      return;
    }
    painterController.removeDrawable(drawable);
    painterController.deselectObjectDrawable(isRemoved: true);
    selectedObject.value = null;
    isPropertyPanelVisible.value = false;
    result.value = null;
    editRevision.value++;
  }

  void deselectSelectedObject() {
    if (selectedObject.value == null && selectedMosaicIndex.value == null) {
      return;
    }
    painterController.deselectObjectDrawable();
    selectedObject.value = null;
    selectedMosaicIndex.value = null;
    isPropertyPanelVisible.value = false;
    editRevision.value++;
  }

  void deselectSelectedObjectIfBlankTap(Offset point) {
    handleCanvasTap(point);
  }

  void handleCanvasTap(Offset point) {
    if (selectedMosaicIndex.value != null && _isPointOnSelectedMosaic(point)) {
      isPropertyPanelVisible.value = true;
      return;
    }
    if (selectedObject.value == null || _isPointOnSelectedObject(point)) {
      if (selectedObject.value != null) {
        isPropertyPanelVisible.value = true;
      }
      final drawable = selectedObject.value == null
          ? _topObjectDrawableAt(point)
          : null;
      if (drawable != null) {
        painterController.selectObjectDrawable(drawable);
        selectObject(drawable);
        return;
      }
      if (selectedObject.value == null && selectMosaicAt(point)) {
        return;
      }
      return;
    }
    final drawable = _topObjectDrawableAt(point);
    if (drawable != null) {
      painterController.selectObjectDrawable(drawable);
      selectObject(drawable);
      return;
    }
    if (selectMosaicAt(point)) {
      return;
    }
    deselectSelectedObject();
  }

  bool selectMosaicAt(Offset point) {
    final index = _topMosaicIndexAt(point);
    if (index == null) {
      return false;
    }
    painterController.deselectObjectDrawable();
    selectedObject.value = null;
    selectedMosaicIndex.value = index;
    final stroke = strokes[index];
    mosaicDrawMode.value = switch (stroke.kind) {
      MosaicStrokeKind.freehand => MosaicDrawMode.freehand,
      MosaicStrokeKind.rectangle => MosaicDrawMode.rectangle,
      MosaicStrokeKind.circle => MosaicDrawMode.circle,
    };
    color.value = stroke.color;
    strokeWidth.value = stroke.width.round().clamp(2, 60);
    mode.value = AnnotationMode.select;
    isPropertyPanelVisible.value = true;
    _applyPainterMode();
    editRevision.value++;
    return true;
  }

  bool selectTextObjectAt(Offset point) {
    final drawable = _topTextDrawableAt(point);
    if (drawable == null) {
      return false;
    }
    painterController.selectObjectDrawable(drawable);
    selectedObject.value = drawable;
    mode.value = AnnotationMode.select;
    isPropertyPanelVisible.value = true;
    _syncTextControlsFromDrawable(drawable);
    editRevision.value++;
    return true;
  }

  /// 设计意图：`flutter_painter_v2` 会在“已选中文字再次点击”时弹出旧版居中文本编辑框。
  /// 本页面统一使用底部文本弹窗，所以在指针按下阶段只清空库内部选中态，
  /// 让后续点击走普通选中通知，保留拖动、删除和属性面板的业务选中态。
  void suppressLegacyTextEditorOnPointerDown(Offset point) {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable is! TextDrawable ||
        !_isPointInsideTextDrawable(point, drawable)) {
      return;
    }
    painterController.deselectObjectDrawable();
    selectedObject.value = drawable;
    mode.value = AnnotationMode.select;
    isPropertyPanelVisible.value = true;
    _syncTextControlsFromDrawable(drawable);
  }

  void setMosaicDrawMode(MosaicDrawMode value) {
    mosaicDrawMode.value = value;
    setMode(AnnotationMode.mosaic);
  }

  void setArrowStyle(EditableArrowStyle value) {
    arrowStyle.value = value;
    _updateSelectedArrowStyle(value);
  }

  void updateTextSize(double value) {
    textSize.value = value.clamp(minTextSize, maxTextSize).toDouble();
    _updateSelectedTextStyle();
  }

  void setTextFont(AnnotationTextFont value) {
    textFont.value = value;
    _updateSelectedTextStyle();
  }

  void rotateSelectedShapeTo(Offset point) {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable is RectangleDrawable) {
      final vector = point - drawable.position;
      if (vector.distance < _minDrawableSide) {
        return;
      }
      final next = drawable.copyWith(rotation: vector.direction - math.pi / 2);
      painterController.replaceDrawable(drawable, next);
      painterController.selectObjectDrawable(next);
      selectedObject.value = next;
      result.value = null;
      editRevision.value++;
    }
    if (drawable is OvalDrawable) {
      final vector = point - drawable.position;
      if (vector.distance < _minDrawableSide) {
        return;
      }
      final next = drawable.copyWith(rotation: vector.direction - math.pi / 2);
      painterController.replaceDrawable(drawable, next);
      painterController.selectObjectDrawable(next);
      selectedObject.value = next;
      result.value = null;
      editRevision.value++;
    }
  }

  void resizeSelectedShapeFromCorner({
    required AnnotationShapeScaleCorner corner,
    required Offset point,
  }) {
    if (selectedMosaicIndex.value != null) {
      resizeSelectedMosaicFromCorner(corner: corner, point: point);
      return;
    }
    final drawable = painterController.selectedObjectDrawable;
    if (drawable is RectangleDrawable) {
      final next = _resizedRectangleFromCorner(drawable, corner, point);
      _replaceSelectedObject(drawable, next);
      return;
    }
    if (drawable is OvalDrawable) {
      final next = _resizedOvalFromCorner(drawable, corner, point);
      _replaceSelectedObject(drawable, next);
    }
  }

  void updateSelectedArrowScaleHandle({
    required bool isHead,
    required Offset point,
  }) {
    final drawable = painterController.selectedObjectDrawable;
    final endpoints = _arrowEndpoints(drawable);
    if (drawable == null || endpoints == null) {
      return;
    }
    final direction = Offset.fromDirection(drawable.rotationAngle);
    final start = isHead
        ? endpoints.start
        : endpoints.end -
              direction *
                  math.max(
                    _projectDistance(endpoints.end - point, direction),
                    _minDrawableSide,
                  );
    final end = isHead
        ? endpoints.start +
              direction *
                  math.max(
                    _projectDistance(point - endpoints.start, direction),
                    _minDrawableSide,
                  )
        : endpoints.end;
    final length = (end - start).distance;
    final next = _copyArrowDrawable(
      drawable,
      position: Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2),
      length: length,
      scale: 1,
    );
    if (next == null) {
      return;
    }
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
    result.value = null;
    editRevision.value++;
  }

  void rotateSelectedArrowTo(Offset point) {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable == null || _arrowEndpoints(drawable) == null) {
      return;
    }
    final vector = point - drawable.position;
    if (vector.distance < _minDrawableSide) {
      return;
    }
    final next = _copyArrowDrawable(drawable, rotation: vector.direction);
    if (next == null) {
      return;
    }
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
    result.value = null;
    editRevision.value++;
  }

  void addMosaicStroke(List<Offset> points, {required MosaicStrokeKind kind}) {
    if (points.length < 2) {
      return;
    }
    final nextPoints = _normalizedMosaicPoints(points, kind);
    mosaicDrawMode.value = switch (kind) {
      MosaicStrokeKind.freehand => MosaicDrawMode.freehand,
      MosaicStrokeKind.rectangle => MosaicDrawMode.rectangle,
      MosaicStrokeKind.circle => MosaicDrawMode.circle,
    };
    strokes.add(
      DrawingStroke(
        mode: AnnotationMode.mosaic,
        kind: kind,
        color: color.value,
        width: strokeWidth.value.toDouble(),
        points: nextPoints,
      ),
    );
    if (kind == MosaicStrokeKind.rectangle || kind == MosaicStrokeKind.circle) {
      painterController.deselectObjectDrawable();
      selectedObject.value = null;
      selectedMosaicIndex.value = strokes.length - 1;
      mode.value = AnnotationMode.select;
      isPropertyPanelVisible.value = true;
    }
    editRevision.value++;
    result.value = null;
  }

  void deleteSelectedMosaic() {
    final index = selectedMosaicIndex.value;
    if (index == null || index < 0 || index >= strokes.length) {
      return;
    }
    strokes.removeAt(index);
    selectedMosaicIndex.value = null;
    isPropertyPanelVisible.value = false;
    result.value = null;
    editRevision.value++;
  }

  void moveSelectedMosaicBy(Offset delta) {
    final index = selectedMosaicIndex.value;
    if (index == null || index < 0 || index >= strokes.length) {
      return;
    }
    final stroke = strokes[index];
    if (stroke.kind == MosaicStrokeKind.freehand) {
      return;
    }
    final movedPoints = stroke.points
        .map((point) => point + delta)
        .toList(growable: false);
    strokes[index] = stroke.copyWith(points: movedPoints);
    result.value = null;
    editRevision.value++;
  }

  void resizeSelectedMosaicFromCorner({
    required AnnotationShapeScaleCorner corner,
    required Offset point,
  }) {
    final index = selectedMosaicIndex.value;
    if (index == null || index < 0 || index >= strokes.length) {
      return;
    }
    final stroke = strokes[index];
    if (stroke.kind == MosaicStrokeKind.freehand || stroke.points.length < 2) {
      return;
    }
    final rect = _rectFromMosaicPoints(stroke.points);
    final fixedCorner = _oppositeRectCorner(rect, corner);
    var width = (point.dx - fixedCorner.dx)
        .abs()
        .clamp(_minDrawableSide, double.infinity)
        .toDouble();
    var height = (point.dy - fixedCorner.dy)
        .abs()
        .clamp(_minDrawableSide, double.infinity)
        .toDouble();
    if (stroke.kind == MosaicStrokeKind.circle) {
      final side = math.max(width, height);
      width = side;
      height = side;
    }
    final sign = _cornerSign(corner);
    final dragged = Offset(
      fixedCorner.dx + sign.dx * width,
      fixedCorner.dy + sign.dy * height,
    );
    final nextRect = Rect.fromPoints(fixedCorner, dragged);
    strokes[index] = stroke.copyWith(
      points: [nextRect.topLeft, nextRect.bottomRight],
    );
    result.value = null;
    editRevision.value++;
  }

  void undo() {
    if (mode.value == AnnotationMode.mosaic && strokes.isNotEmpty) {
      strokes.removeLast();
      selectedMosaicIndex.value = null;
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
      selectedMosaicIndex.value = null;
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
    selectedMosaicIndex.value = null;
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
      final dimensions = _readResizeDimensionsIfNeeded(source);
      final annotated = await _imageChannel.saveEditedImageBytes(
        source: source,
        bytes: pngBytes,
        filter: filter.value?.value,
        rotationDegrees: rotationDegrees.value,
        flipHorizontal: flipHorizontal.value,
        flipVertical: flipVertical.value,
        resizeWidth: dimensions?.width,
        resizeHeight: dimensions?.height,
        cropAspectRatio: cropPreset.value.aspectRatio,
      );
      result.value = annotated;
      await _historyRepository.recordOperationSuccess(
        featureName: 'annotation.featureName'.tr,
        inputPath: source.path,
        outputPath: annotated.outputPath,
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

  AnnotationObjectControlGeometry? get selectedControlGeometry {
    editRevision.value;
    final mosaicIndex = selectedMosaicIndex.value;
    if (mosaicIndex != null &&
        mosaicIndex >= 0 &&
        mosaicIndex < strokes.length &&
        strokes[mosaicIndex].kind != MosaicStrokeKind.freehand) {
      return AnnotationObjectControlGeometry(
        shapeScaleHandles: _mosaicScaleHandles(strokes[mosaicIndex]),
      );
    }
    final drawable = selectedObject.value;
    if (drawable is RectangleDrawable) {
      return AnnotationObjectControlGeometry(
        rotateHandle: _shapeBottomCenter(drawable),
        shapeScaleHandles: _shapeScaleHandles(drawable),
      );
    }
    if (drawable is OvalDrawable) {
      return AnnotationObjectControlGeometry(
        rotateHandle: _shapeBottomCenter(drawable),
        shapeScaleHandles: _shapeScaleHandles(drawable),
      );
    }
    final endpoints = _arrowEndpoints(drawable);
    if (endpoints != null) {
      return AnnotationObjectControlGeometry(
        arrowStart: endpoints.start,
        arrowEnd: endpoints.end,
        arrowDirectionHandle: _arrowDirectionHandle(drawable, endpoints),
      );
    }
    return null;
  }

  void _addObjectDrawable(ObjectDrawable drawable) {
    painterController.addDrawables([drawable]);
    painterController.selectObjectDrawable(drawable);
    selectedObject.value = drawable;
    selectedMosaicIndex.value = null;
    mode.value = AnnotationMode.select;
    isPropertyPanelVisible.value = true;
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
    final snapshot = _CanvasContentRatioSnapshot.capture(
      drawables: painterController.drawables,
      selected: painterController.selectedObjectDrawable,
      strokes: strokes,
      size: from,
    );
    if (strokes.isNotEmpty) {
      strokes.assignAll(snapshot.restoreStrokes(to));
    }
    if (painterController.drawables.isEmpty) {
      editRevision.value++;
      return;
    }
    final updatedDrawables = snapshot.restoreDrawables(to);
    final nextSelected = snapshot.restoreSelected(updatedDrawables);
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
      color: color.value,
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

  void _updateSelectedMosaicColor(Color nextColor) {
    final index = selectedMosaicIndex.value;
    if (index == null || index < 0 || index >= strokes.length) {
      return;
    }
    strokes[index] = strokes[index].copyWith(color: nextColor);
  }

  void _replaceSelectedObject(ObjectDrawable current, ObjectDrawable next) {
    painterController.replaceDrawable(current, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
    result.value = null;
    editRevision.value++;
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
    editRevision.value++;
  }

  void _updateSelectedMosaicStrokeWidth(double width) {
    final index = selectedMosaicIndex.value;
    if (index == null || index < 0 || index >= strokes.length) {
      return;
    }
    final stroke = strokes[index];
    if (stroke.kind == MosaicStrokeKind.freehand) {
      return;
    }
    strokes[index] = stroke.copyWith(width: width.clamp(2, 60).toDouble());
    result.value = null;
    editRevision.value++;
  }

  void _updateSelectedArrowStyle(EditableArrowStyle style) {
    final drawable = painterController.selectedObjectDrawable;
    final next = _copyArrowDrawable(drawable, style: style);
    if (drawable == null || next == null) {
      return;
    }
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
    result.value = null;
    editRevision.value++;
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
    final next = drawable.copyWith(
      text: nextText,
      style: _textStyle(
        color: drawable.style.color ?? color.value,
        shadows: drawable.style.shadows,
      ),
    );
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
    result.value = null;
    editRevision.value++;
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
    final paint = Paint()..style = PaintingStyle.fill;
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

  Map<String, Object> _historyParameters() {
    return <String, Object>{
      'mode': 'editor',
      'layers': painterController.drawables.length,
      'strokes': strokes.length,
      'strokeWidth': strokeWidth.value,
      'color': colorHex,
      'filter': filter.value?.value ?? 'none',
      'rotationDegrees': rotationDegrees.value,
      'flipHorizontal': flipHorizontal.value,
      'flipVertical': flipVertical.value,
      'resizeWidth': resizeWidthController.text.trim(),
      'resizeHeight': resizeHeightController.text.trim(),
      'resizePercent': resizePercent.value.round(),
      'cropPreset': cropPreset.value.name,
    };
  }

  void _notifyPainterChanged() {
    selectedObject.value = painterController.selectedObjectDrawable;
    editRevision.value++;
    result.value = null;
  }

  void _resetImageAdjustments(LocalImageFile image) {
    filter.value = null;
    rotationDegrees.value = 0;
    flipHorizontal.value = false;
    flipVertical.value = false;
    resizeKeepAspectRatio.value = true;
    resizePercent.value = 100;
    cropPreset.value = AnnotationCropPreset.original;
    resizeWidthController.text = image.hasValidDimensions
        ? image.width.toString()
        : '';
    resizeHeightController.text = image.hasValidDimensions
        ? image.height.toString()
        : '';
  }

  void _markImageAdjustmentChanged() {
    result.value = null;
    editRevision.value++;
  }

  bool _hasResizeAdjustment(LocalImageFile? image) {
    if (image == null || !image.hasValidDimensions) {
      return false;
    }
    final dimensions = _readResizeDimensions(showError: false);
    if (dimensions == null) {
      return false;
    }
    return dimensions.width != image.width || dimensions.height != image.height;
  }

  _ResizeDimensions? _readResizeDimensionsIfNeeded(LocalImageFile source) {
    if (!_hasResizeAdjustment(source)) {
      return null;
    }
    return _readResizeDimensions(showError: true);
  }

  _ResizeDimensions? _readResizeDimensions({required bool showError}) {
    final width = int.tryParse(resizeWidthController.text.trim());
    final height = int.tryParse(resizeHeightController.text.trim());
    if (width == null || height == null) {
      if (showError) {
        _showError('annotation.error.invalidDimensions'.tr);
      }
      return null;
    }
    if (width < _minResizeDimension || height < _minResizeDimension) {
      if (showError) {
        _showError('annotation.error.nonPositiveDimensions'.tr);
      }
      return null;
    }
    if (width > _maxResizeDimension || height > _maxResizeDimension) {
      if (showError) {
        _showError(
          'annotation.error.dimensionsTooLarge'.trParams({
            'max': _maxResizeDimension.toString(),
          }),
        );
      }
      return null;
    }
    return _ResizeDimensions(width: width, height: height);
  }

  void _syncResizeHeightFromWidth(LocalImageFile image) {
    final width = int.tryParse(resizeWidthController.text.trim());
    if (width == null || width <= 0 || image.width <= 0 || image.height <= 0) {
      return;
    }
    resizeHeightController.text = _scaledCompanion(
      changed: width,
      sourceChanged: image.width,
      sourceCompanion: image.height,
    ).toString();
  }

  void _syncResizeWidthFromHeight(LocalImageFile image) {
    final height = int.tryParse(resizeHeightController.text.trim());
    if (height == null ||
        height <= 0 ||
        image.width <= 0 ||
        image.height <= 0) {
      return;
    }
    resizeWidthController.text = _scaledCompanion(
      changed: height,
      sourceChanged: image.height,
      sourceCompanion: image.width,
    ).toString();
  }

  void _updateResizePercentFromFields(LocalImageFile? image) {
    if (image == null || !image.hasValidDimensions) {
      return;
    }
    final width = int.tryParse(resizeWidthController.text.trim());
    if (width == null || width <= 0 || image.width <= 0) {
      return;
    }
    resizePercent.value = (width / image.width * 100).clamp(10, 300);
  }

  int _scaledCompanion({
    required int changed,
    required int sourceChanged,
    required int sourceCompanion,
  }) {
    if (changed <= 0 || sourceChanged <= 0 || sourceCompanion <= 0) {
      return _minResizeDimension;
    }
    return (changed * sourceCompanion / sourceChanged).round().clamp(
      _minResizeDimension,
      _maxResizeDimension,
    );
  }

  int _scaleDimension(int value, double percent) {
    return (value * percent / 100).round().clamp(
      _minResizeDimension,
      _maxResizeDimension,
    );
  }

  double _safeAspectRatio(double width, double height) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return 1;
    }
    return width / height;
  }

  bool _isLayerCreationMode(AnnotationMode value) {
    return switch (value) {
      AnnotationMode.brush ||
      AnnotationMode.mosaic ||
      AnnotationMode.text ||
      AnnotationMode.rectangle ||
      AnnotationMode.circle ||
      AnnotationMode.arrow => true,
      AnnotationMode.select ||
      AnnotationMode.filter ||
      AnnotationMode.rotate ||
      AnnotationMode.flip ||
      AnnotationMode.resize ||
      AnnotationMode.crop => false,
    };
  }

  bool _isImageProcessingMode(AnnotationMode value) {
    return switch (value) {
      AnnotationMode.filter ||
      AnnotationMode.rotate ||
      AnnotationMode.flip ||
      AnnotationMode.resize ||
      AnnotationMode.crop => true,
      AnnotationMode.select ||
      AnnotationMode.brush ||
      AnnotationMode.mosaic ||
      AnnotationMode.text ||
      AnnotationMode.rectangle ||
      AnnotationMode.circle ||
      AnnotationMode.arrow => false,
    };
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
    return EditableArrowDrawable(
      length: length,
      position: center,
      rotationAngle: math.atan2(delta.dy, delta.dx),
      paint: paint,
      style: arrowStyle.value,
      arrowHeadSize: math.max(18, paint.strokeWidth * 4),
    );
  }

  Offset _shapeBottomCenter(ObjectDrawable drawable) {
    final Size size = switch (drawable) {
      RectangleDrawable item => item.size * item.scale,
      OvalDrawable item => item.size * item.scale,
      _ => Size.zero,
    };
    final localBottom = Offset(0, size.height / 2);
    return drawable.position +
        _rotateOffset(localBottom, drawable.rotationAngle);
  }

  List<AnnotationShapeScaleHandle> _shapeScaleHandles(ObjectDrawable drawable) {
    final Size size = switch (drawable) {
      RectangleDrawable item => item.size * item.scale,
      OvalDrawable item => item.size * item.scale,
      _ => Size.zero,
    };
    if (size.width <= 0 || size.height <= 0) {
      return const <AnnotationShapeScaleHandle>[];
    }
    final localCorners = <AnnotationShapeScaleCorner, Offset>{
      AnnotationShapeScaleCorner.topLeft: Offset(
        -size.width / 2,
        -size.height / 2,
      ),
      AnnotationShapeScaleCorner.topRight: Offset(
        size.width / 2,
        -size.height / 2,
      ),
      AnnotationShapeScaleCorner.bottomLeft: Offset(
        -size.width / 2,
        size.height / 2,
      ),
      AnnotationShapeScaleCorner.bottomRight: Offset(
        size.width / 2,
        size.height / 2,
      ),
    };
    return localCorners.entries
        .map(
          (entry) => AnnotationShapeScaleHandle(
            corner: entry.key,
            center:
                drawable.position +
                _rotateOffset(entry.value, drawable.rotationAngle),
          ),
        )
        .toList(growable: false);
  }

  List<AnnotationShapeScaleHandle> _mosaicScaleHandles(DrawingStroke stroke) {
    final rect = _rectFromMosaicPoints(stroke.points);
    if (rect.width <= 0 || rect.height <= 0) {
      return const <AnnotationShapeScaleHandle>[];
    }
    final corners = <AnnotationShapeScaleCorner, Offset>{
      AnnotationShapeScaleCorner.topLeft: rect.topLeft,
      AnnotationShapeScaleCorner.topRight: rect.topRight,
      AnnotationShapeScaleCorner.bottomLeft: rect.bottomLeft,
      AnnotationShapeScaleCorner.bottomRight: rect.bottomRight,
    };
    return corners.entries
        .map(
          (entry) => AnnotationShapeScaleHandle(
            corner: entry.key,
            center: entry.value,
          ),
        )
        .toList(growable: false);
  }

  RectangleDrawable _resizedRectangleFromCorner(
    RectangleDrawable drawable,
    AnnotationShapeScaleCorner corner,
    Offset point,
  ) {
    final nextGeometry = _shapeResizeGeometry(
      position: drawable.position,
      rotation: drawable.rotationAngle,
      size: drawable.size * drawable.scale,
      corner: corner,
      point: point,
      keepSquare: false,
    );
    return drawable.copyWith(
      position: nextGeometry.center,
      scale: 1,
      size: nextGeometry.size,
    );
  }

  OvalDrawable _resizedOvalFromCorner(
    OvalDrawable drawable,
    AnnotationShapeScaleCorner corner,
    Offset point,
  ) {
    final nextGeometry = _shapeResizeGeometry(
      position: drawable.position,
      rotation: drawable.rotationAngle,
      size: drawable.size * drawable.scale,
      corner: corner,
      point: point,
      keepSquare: true,
    );
    return drawable.copyWith(
      position: nextGeometry.center,
      scale: 1,
      size: nextGeometry.size,
    );
  }

  _ShapeResizeGeometry _shapeResizeGeometry({
    required Offset position,
    required double rotation,
    required Size size,
    required AnnotationShapeScaleCorner corner,
    required Offset point,
    required bool keepSquare,
  }) {
    final draggedLocal = _rotateOffset(point - position, -rotation);
    final fixedLocal = _oppositeLocalCorner(size, corner);
    var width = (draggedLocal.dx - fixedLocal.dx)
        .abs()
        .clamp(_minDrawableSide, double.infinity)
        .toDouble();
    var height = (draggedLocal.dy - fixedLocal.dy)
        .abs()
        .clamp(_minDrawableSide, double.infinity)
        .toDouble();
    if (keepSquare) {
      final side = math.max(width, height);
      width = side;
      height = side;
    }
    final draggedSign = _cornerSign(corner);
    final draggedLocalClamped = Offset(
      fixedLocal.dx + draggedSign.dx * width,
      fixedLocal.dy + draggedSign.dy * height,
    );
    final localCenter = Offset(
      (fixedLocal.dx + draggedLocalClamped.dx) / 2,
      (fixedLocal.dy + draggedLocalClamped.dy) / 2,
    );
    return _ShapeResizeGeometry(
      center: position + _rotateOffset(localCenter, rotation),
      size: Size(width, height),
    );
  }

  Offset _oppositeLocalCorner(Size size, AnnotationShapeScaleCorner corner) {
    final opposite = switch (corner) {
      AnnotationShapeScaleCorner.topLeft =>
        AnnotationShapeScaleCorner.bottomRight,
      AnnotationShapeScaleCorner.topRight =>
        AnnotationShapeScaleCorner.bottomLeft,
      AnnotationShapeScaleCorner.bottomLeft =>
        AnnotationShapeScaleCorner.topRight,
      AnnotationShapeScaleCorner.bottomRight =>
        AnnotationShapeScaleCorner.topLeft,
    };
    final sign = _cornerSign(opposite);
    return Offset(sign.dx * size.width / 2, sign.dy * size.height / 2);
  }

  Offset _oppositeRectCorner(Rect rect, AnnotationShapeScaleCorner corner) {
    return switch (corner) {
      AnnotationShapeScaleCorner.topLeft => rect.bottomRight,
      AnnotationShapeScaleCorner.topRight => rect.bottomLeft,
      AnnotationShapeScaleCorner.bottomLeft => rect.topRight,
      AnnotationShapeScaleCorner.bottomRight => rect.topLeft,
    };
  }

  Offset _cornerSign(AnnotationShapeScaleCorner corner) {
    return switch (corner) {
      AnnotationShapeScaleCorner.topLeft => const Offset(-1, -1),
      AnnotationShapeScaleCorner.topRight => const Offset(1, -1),
      AnnotationShapeScaleCorner.bottomLeft => const Offset(-1, 1),
      AnnotationShapeScaleCorner.bottomRight => const Offset(1, 1),
    };
  }

  _ArrowEndpoints? _arrowEndpoints(ObjectDrawable? drawable) {
    if (drawable is EditableArrowDrawable) {
      final half = drawable.length * drawable.scale / 2;
      final start =
          drawable.position +
          Offset.fromDirection(drawable.rotationAngle, -half);
      final end =
          drawable.position +
          Offset.fromDirection(drawable.rotationAngle, half);
      return _ArrowEndpoints(start: start, end: end);
    }
    if (drawable is ArrowDrawable) {
      final half = drawable.length * drawable.scale / 2;
      final start =
          drawable.position +
          Offset.fromDirection(drawable.rotationAngle, -half);
      final end =
          drawable.position +
          Offset.fromDirection(drawable.rotationAngle, half);
      return _ArrowEndpoints(start: start, end: end);
    }
    return null;
  }

  Offset _arrowDirectionHandle(
    ObjectDrawable? drawable,
    _ArrowEndpoints endpoints,
  ) {
    final direction = switch (drawable) {
      ObjectDrawable item => Offset.fromDirection(item.rotationAngle),
      _ => const Offset(1, 0),
    };
    final double spacing = switch (drawable) {
      EditableArrowDrawable item => math.max(28, item.paint.strokeWidth * 3),
      ArrowDrawable item => math.max(28, item.paint.strokeWidth * 3),
      _ => 28.0,
    };
    return endpoints.end + direction * spacing;
  }

  bool _isPointOnSelectedObject(Offset point) {
    final drawable = selectedObject.value;
    if (drawable == null) {
      return false;
    }
    final geometry = selectedControlGeometry;
    const controlHitRadius = 30.0;
    final controlPoints = <Offset?>[
      geometry?.rotateHandle,
      ...?geometry?.shapeScaleHandles.map((handle) => handle.center),
      geometry?.arrowStart,
      geometry?.arrowEnd,
      geometry?.arrowDirectionHandle,
    ];
    if (controlPoints.any(
      (controlPoint) =>
          controlPoint != null &&
          (point - controlPoint).distance <= controlHitRadius,
    )) {
      return true;
    }
    if (drawable is EditableArrowDrawable || drawable is ArrowDrawable) {
      final endpoints = _arrowEndpoints(drawable);
      if (endpoints == null) {
        return false;
      }
      final strokeWidth = switch (drawable) {
        EditableArrowDrawable item => item.paint.strokeWidth,
        ArrowDrawable item => item.paint.strokeWidth,
        _ => 0.0,
      };
      return _distanceToSegment(point, endpoints.start, endpoints.end) <=
          math.max(18, strokeWidth + 10);
    }
    if (drawable is TextDrawable) {
      return _isPointInsideTextDrawable(point, drawable);
    }
    final size = drawable.getSize();
    final local = _rotateOffset(
      point - drawable.position,
      -drawable.rotationAngle,
    );
    return local.dx.abs() <= size.width / 2 &&
        local.dy.abs() <= size.height / 2;
  }

  bool _isPointOnSelectedMosaic(Offset point) {
    final index = selectedMosaicIndex.value;
    if (index == null || index < 0 || index >= strokes.length) {
      return false;
    }
    final geometry = selectedControlGeometry;
    const controlHitRadius = 30.0;
    if (geometry?.shapeScaleHandles.any(
          (handle) => (point - handle.center).distance <= controlHitRadius,
        ) ??
        false) {
      return true;
    }
    return _isPointInsideMosaicStroke(point, strokes[index]);
  }

  TextDrawable? _topTextDrawableAt(Offset point) {
    for (final drawable in painterController.drawables.reversed) {
      if (drawable is TextDrawable &&
          _isPointInsideTextDrawable(point, drawable)) {
        return drawable;
      }
    }
    return null;
  }

  int? _topMosaicIndexAt(Offset point) {
    for (var index = strokes.length - 1; index >= 0; index--) {
      final stroke = strokes[index];
      if (stroke.kind == MosaicStrokeKind.freehand) {
        continue;
      }
      if (_isPointInsideMosaicStroke(point, stroke)) {
        return index;
      }
    }
    return null;
  }

  bool _isPointInsideMosaicStroke(Offset point, DrawingStroke stroke) {
    if (stroke.points.length < 2) {
      return false;
    }
    final rect = _rectFromMosaicPoints(stroke.points).inflate(8);
    if (stroke.kind == MosaicStrokeKind.rectangle) {
      return rect.contains(point);
    }
    if (stroke.kind == MosaicStrokeKind.circle) {
      final center = rect.center;
      final radiusX = rect.width / 2;
      final radiusY = rect.height / 2;
      if (radiusX <= 0 || radiusY <= 0) {
        return false;
      }
      final normalizedX = (point.dx - center.dx) / radiusX;
      final normalizedY = (point.dy - center.dy) / radiusY;
      return normalizedX * normalizedX + normalizedY * normalizedY <= 1;
    }
    return false;
  }

  ObjectDrawable? _topObjectDrawableAt(Offset point) {
    for (final drawable in painterController.drawables.reversed) {
      if (drawable is ObjectDrawable &&
          !drawable.hidden &&
          _isPointInsideObjectDrawable(point, drawable)) {
        return drawable;
      }
    }
    return null;
  }

  bool _isPointInsideObjectDrawable(Offset point, ObjectDrawable drawable) {
    if (drawable is EditableArrowDrawable || drawable is ArrowDrawable) {
      final endpoints = _arrowEndpoints(drawable);
      if (endpoints == null) {
        return false;
      }
      final strokeWidth = switch (drawable) {
        EditableArrowDrawable item => item.paint.strokeWidth,
        ArrowDrawable item => item.paint.strokeWidth,
        _ => 0.0,
      };
      return _distanceToSegment(point, endpoints.start, endpoints.end) <=
          math.max(18, strokeWidth + 10);
    }
    if (drawable is TextDrawable) {
      return _isPointInsideTextDrawable(point, drawable);
    }
    final size = drawable.getSize();
    final local = _rotateOffset(
      point - drawable.position,
      -drawable.rotationAngle,
    );
    return local.dx.abs() <= size.width / 2 &&
        local.dy.abs() <= size.height / 2;
  }

  bool _isPointInsideTextDrawable(Offset point, TextDrawable drawable) {
    final size = _textDrawableHitSize(drawable);
    final local = _rotateOffset(
      point - drawable.position,
      -drawable.rotationAngle,
    );
    return local.dx.abs() <= size.width / 2 &&
        local.dy.abs() <= size.height / 2;
  }

  Size _textDrawableHitSize(TextDrawable drawable) {
    final fontSize = (drawable.style.fontSize ?? _defaultTextSize)
        .clamp(minTextSize, maxTextSize)
        .toDouble();
    final textLength = drawable.text.runes.length.clamp(1, 40).toDouble();
    final width = math.max(_minDrawableSide, textLength * fontSize * 0.72);
    final height = math.max(_minDrawableSide, fontSize * 1.6);
    return Size(width * drawable.scale, height * drawable.scale);
  }

  void _syncTextControlsFromDrawable(TextDrawable drawable) {
    textController.text = drawable.text;
    textSize.value = (drawable.style.fontSize ?? _defaultTextSize)
        .clamp(minTextSize, maxTextSize)
        .toDouble();
    textFont.value = _textFontFromFamily(drawable.style.fontFamily);
  }

  void _updateSelectedTextStyle() {
    final drawable = painterController.selectedObjectDrawable;
    if (drawable is! TextDrawable) {
      return;
    }
    final next = drawable.copyWith(
      style: _textStyle(
        color: drawable.style.color ?? color.value,
        shadows: drawable.style.shadows,
      ),
    );
    painterController.replaceDrawable(drawable, next);
    painterController.selectObjectDrawable(next);
    selectedObject.value = next;
    result.value = null;
    editRevision.value++;
  }

  TextStyle _textStyle({required Color color, List<Shadow>? shadows}) {
    return TextStyle(
      color: color,
      fontSize: textSize.value.clamp(minTextSize, maxTextSize).toDouble(),
      fontFamily: textFont.value.family,
      fontWeight: FontWeight.w800,
      shadows: shadows ?? const [Shadow(color: Colors.black54, blurRadius: 2)],
    );
  }

  AnnotationTextFont _textFontFromFamily(String? family) {
    for (final item in AnnotationTextFont.values) {
      if (item.family == family) {
        return item;
      }
    }
    return AnnotationTextFont.system;
  }

  double _projectDistance(Offset vector, Offset direction) {
    return vector.dx * direction.dx + vector.dy * direction.dy;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared <= 0) {
      return (point - start).distance;
    }
    final t =
        (((point.dx - start.dx) * segment.dx +
                    (point.dy - start.dy) * segment.dy) /
                lengthSquared)
            .clamp(0.0, 1.0);
    final projection = Offset(
      start.dx + segment.dx * t,
      start.dy + segment.dy * t,
    );
    return (point - projection).distance;
  }

  ObjectDrawable? _copyArrowDrawable(
    ObjectDrawable? drawable, {
    Offset? position,
    double? length,
    double? rotation,
    double? scale,
    Paint? paint,
    EditableArrowStyle? style,
  }) {
    if (drawable is EditableArrowDrawable) {
      return drawable.copyWith(
        position: position,
        length: length,
        rotation: rotation,
        scale: scale,
        paint: paint,
        style: style,
      );
    }
    if (drawable is ArrowDrawable) {
      return EditableArrowDrawable(
        position: position ?? drawable.position,
        length: length ?? drawable.length,
        rotationAngle: rotation ?? drawable.rotationAngle,
        scale: scale ?? drawable.scale,
        paint: paint ?? drawable.paint,
        style: style ?? arrowStyle.value,
        arrowHeadSize: drawable.arrowHeadSize,
        assists: drawable.assists,
        assistPaints: drawable.assistPaints,
        locked: drawable.locked,
        hidden: drawable.hidden,
      );
    }
    return null;
  }

  Offset _rotateOffset(Offset offset, double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Offset(
      offset.dx * cos - offset.dy * sin,
      offset.dx * sin + offset.dy * cos,
    );
  }

  void _drawMosaicStroke(
    Canvas canvas,
    Paint paint,
    DrawingStroke stroke, {
    required double scaleX,
    required double scaleY,
  }) {
    // 设计意图：马赛克用于遮盖敏感区域，导出时强制使用不透明色，避免半透明覆盖泄露底图细节。
    paint.color = stroke.color.withValues(alpha: 1);
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

  List<Offset> _normalizedMosaicPoints(
    List<Offset> points,
    MosaicStrokeKind kind,
  ) {
    if (kind == MosaicStrokeKind.freehand || points.length < 2) {
      return List<Offset>.unmodifiable(points);
    }
    final rect = _rectFromMosaicPoints(points);
    if (kind == MosaicStrokeKind.circle) {
      final side = math.max(rect.width, rect.height);
      final square = Rect.fromCenter(
        center: rect.center,
        width: side,
        height: side,
      );
      return List<Offset>.unmodifiable([square.topLeft, square.bottomRight]);
    }
    return List<Offset>.unmodifiable([rect.topLeft, rect.bottomRight]);
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

class _ArrowEndpoints {
  const _ArrowEndpoints({required this.start, required this.end});

  final Offset start;
  final Offset end;
}

class _ShapeResizeGeometry {
  const _ShapeResizeGeometry({required this.center, required this.size});

  final Offset center;
  final Size size;
}

class _CanvasContentRatioSnapshot {
  const _CanvasContentRatioSnapshot({
    required this.drawables,
    required this.selectedIndex,
    required this.strokes,
  });

  final List<Drawable> drawables;
  final int selectedIndex;
  final List<_StrokeRatioSnapshot> strokes;

  static _CanvasContentRatioSnapshot capture({
    required List<Drawable> drawables,
    required ObjectDrawable? selected,
    required List<DrawingStroke> strokes,
    required Size size,
  }) {
    return _CanvasContentRatioSnapshot(
      drawables: drawables
          .map((drawable) => _normalizeDrawable(drawable, size))
          .toList(growable: false),
      selectedIndex: selected == null ? -1 : drawables.indexOf(selected),
      strokes: strokes
          .map((stroke) => _StrokeRatioSnapshot.capture(stroke, size))
          .toList(growable: false),
    );
  }

  List<Drawable> restoreDrawables(Size size) {
    return drawables
        .map((drawable) => _restoreDrawable(drawable, size))
        .toList(growable: false);
  }

  ObjectDrawable? restoreSelected(List<Drawable> restoredDrawables) {
    if (selectedIndex < 0 || selectedIndex >= restoredDrawables.length) {
      return null;
    }
    final selected = restoredDrawables[selectedIndex];
    return selected is ObjectDrawable ? selected : null;
  }

  List<DrawingStroke> restoreStrokes(Size size) {
    return strokes
        .map((stroke) => stroke.restore(size))
        .toList(growable: false);
  }

  static Drawable _normalizeDrawable(Drawable drawable, Size size) {
    if (drawable is! ObjectDrawable) {
      return drawable;
    }
    return drawable.copyWith(
      position: _normalizeOffset(drawable.position, size),
    );
  }

  static Drawable _restoreDrawable(Drawable drawable, Size size) {
    if (drawable is! ObjectDrawable) {
      return drawable;
    }
    return drawable.copyWith(position: _restoreOffset(drawable.position, size));
  }
}

class _StrokeRatioSnapshot {
  const _StrokeRatioSnapshot({
    required this.stroke,
    required this.widthRatio,
    required this.points,
  });

  final DrawingStroke stroke;
  final double widthRatio;
  final List<Offset> points;

  static _StrokeRatioSnapshot capture(DrawingStroke stroke, Size size) {
    final averageSide = _averageSide(size);
    return _StrokeRatioSnapshot(
      stroke: stroke.copyWith(points: const <Offset>[]),
      widthRatio: averageSide <= 0 ? stroke.width : stroke.width / averageSide,
      points: stroke.points
          .map((point) => _normalizeOffset(point, size))
          .toList(growable: false),
    );
  }

  DrawingStroke restore(Size size) {
    final averageSide = _averageSide(size);
    return stroke.copyWith(
      width: averageSide <= 0 ? stroke.width : widthRatio * averageSide,
      points: points
          .map((point) => _restoreOffset(point, size))
          .toList(growable: false),
    );
  }
}

Offset _normalizeOffset(Offset point, Size size) {
  if (size.width <= 0 || size.height <= 0) {
    return point;
  }
  return Offset(point.dx / size.width, point.dy / size.height);
}

Offset _restoreOffset(Offset point, Size size) {
  return Offset(point.dx * size.width, point.dy * size.height);
}

double _averageSide(Size size) {
  return (size.width + size.height) / 2;
}

class _ResizeDimensions {
  const _ResizeDimensions({required this.width, required this.height});

  final int width;
  final int height;
}
