import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../exceptions/app_exception.dart';

/// GIF 后台处理服务，负责生成、拆帧和压缩。
///
/// 设计意图：GIF 编解码属于 CPU 和内存密集任务，统一放入独立 isolate，
/// 避免阻塞 Flutter 主 isolate；任务先读取 GIF 元数据并限制文件、帧数和
/// 总像素，再完整合成动画，兼顾增量帧正确性与异常输入防护。
class GifProcessingService {
  const GifProcessingService._();

  static const int maxInputFileBytes = 48 * 1024 * 1024;
  static const int maxInputFrames = 500;
  static const int maxOutputFrames = 120;
  static const int maxOutputPixels = 12000000;
  static const int maxDecodedAnimationPixels = 48000000;

  static Future<Map<String, Object?>> createGif({
    required List<String> paths,
    required String outputPath,
    required int delayMs,
  }) async {
    final arguments = <String, Object?>{
      'paths': List<String>.of(paths, growable: false),
      'outputPath': outputPath,
      'delayMs': delayMs,
    };
    final result = await Isolate.run(() => _createGifTask(arguments));
    return _requireSuccess(result, fallbackMessage: '生成 GIF 失败，请重试');
  }

  static Future<Map<String, Object?>> exportFrames({
    required String sourcePath,
    required String outputDirectory,
    required int frameStepMs,
  }) async {
    final arguments = <String, Object?>{
      'sourcePath': sourcePath,
      'outputDirectory': outputDirectory,
      'frameStepMs': frameStepMs,
    };
    final result = await Isolate.run(() => _exportGifFramesTask(arguments));
    return _requireSuccess(result, fallbackMessage: 'GIF 拆帧失败，请重试');
  }

  static Future<Map<String, Object?>> compressGif({
    required String sourcePath,
    required String outputPath,
    required int frameStepMs,
    required int scalePercent,
  }) async {
    final arguments = <String, Object?>{
      'sourcePath': sourcePath,
      'outputPath': outputPath,
      'frameStepMs': frameStepMs,
      'scalePercent': scalePercent,
    };
    final result = await Isolate.run(() => _compressGifTask(arguments));
    return _requireSuccess(result, fallbackMessage: 'GIF 压缩失败，请重试');
  }

  static Map<String, Object?> _requireSuccess(
    Map<String, Object?> result, {
    required String fallbackMessage,
  }) {
    if (result['ok'] != true) {
      throw AppException(result['message'] as String? ?? fallbackMessage);
    }
    return result;
  }
}

Map<String, Object?> _createGifTask(Map<String, Object?> arguments) {
  return _guardGifTask(() {
    final paths = (arguments['paths'] as List<Object?>).whereType<String>();
    final outputPath = arguments['outputPath'] as String;
    final delayMs = arguments['delayMs'] as int;
    final encoder = _createEncoder();
    var targetWidth = 0;
    var targetHeight = 0;
    var frameCount = 0;

    for (final path in paths) {
      final decoded = _decodeStaticImage(path);
      targetWidth = targetWidth == 0 ? decoded.width : targetWidth;
      targetHeight = targetHeight == 0 ? decoded.height : targetHeight;
      _validateOutputDimensions(targetWidth, targetHeight);

      final frame =
          decoded.width == targetWidth && decoded.height == targetHeight
          ? decoded
          : img.copyResize(
              decoded,
              width: targetWidth,
              height: targetHeight,
              interpolation: img.Interpolation.linear,
            );
      encoder.addFrame(frame, duration: math.max(1, (delayMs / 10).round()));
      frameCount++;
    }

    if (frameCount < 2) {
      throw const _GifTaskException('请至少选择两张图片生成 GIF');
    }
    final bytes = encoder.finish();
    if (bytes == null || bytes.isEmpty) {
      throw const _GifTaskException('GIF 编码结果为空，请重试');
    }
    final output = _writeOutputFile(outputPath, bytes);
    return <String, Object?>{
      'ok': true,
      'outputPath': output.path,
      'outputSizeBytes': output.lengthSync(),
      'frameCount': frameCount,
      'delayMs': delayMs,
      'width': targetWidth,
      'height': targetHeight,
    };
  });
}

Map<String, Object?> _exportGifFramesTask(Map<String, Object?> arguments) {
  return _guardGifTask(() {
    final sourcePath = arguments['sourcePath'] as String;
    final outputDirectory = arguments['outputDirectory'] as String;
    final frameStepMs = arguments['frameStepMs'] as int;
    final animation = _decodeGifAnimation(sourcePath);
    final sampling = _sampleAnimation(animation, frameStepMs);
    final directory = Directory(outputDirectory)..createSync(recursive: true);
    final outputPaths = <String>[];
    var totalOutputSizeBytes = 0;

    for (var index = 0; index < sampling.frameIndices.length; index++) {
      final sourceFrame = animation.frames[sampling.frameIndices[index]];
      final frame = img.Image.from(sourceFrame, noAnimation: true);
      final output = File(
        '${directory.path}${Platform.pathSeparator}'
        'frame_${(index + 1).toString().padLeft(3, '0')}.png',
      );
      output.writeAsBytesSync(img.encodePng(frame), flush: true);
      if (!output.existsSync() || output.lengthSync() <= 0) {
        throw const _GifTaskException('GIF 帧导出失败，请重试');
      }
      outputPaths.add(output.path);
      totalOutputSizeBytes += output.lengthSync();
    }

    return <String, Object?>{
      'ok': true,
      'outputDirectory': directory.path,
      'outputPaths': outputPaths,
      'totalOutputSizeBytes': totalOutputSizeBytes,
      'frameCount': outputPaths.length,
      'durationMs': sampling.durationMs,
      'frameStepMs': frameStepMs,
      'width': animation.width,
      'height': animation.height,
    };
  });
}

Map<String, Object?> _compressGifTask(Map<String, Object?> arguments) {
  return _guardGifTask(() {
    final sourcePath = arguments['sourcePath'] as String;
    final outputPath = arguments['outputPath'] as String;
    final frameStepMs = arguments['frameStepMs'] as int;
    final scalePercent = arguments['scalePercent'] as int;
    final sourceFile = _requireInputFile(sourcePath);
    final animation = _decodeGifAnimation(sourcePath);
    final sampling = _sampleAnimation(animation, frameStepMs);
    final targetWidth = math.max(
      1,
      (animation.width * scalePercent / 100).round(),
    );
    final targetHeight = math.max(
      1,
      (animation.height * scalePercent / 100).round(),
    );
    _validateOutputDimensions(targetWidth, targetHeight);

    final encoder = _createEncoder();
    for (final frameIndex in sampling.frameIndices) {
      final sourceFrame = img.Image.from(
        animation.frames[frameIndex],
        noAnimation: true,
      );
      final frame =
          sourceFrame.width == targetWidth && sourceFrame.height == targetHeight
          ? sourceFrame
          : img.copyResize(
              sourceFrame,
              width: targetWidth,
              height: targetHeight,
              interpolation: img.Interpolation.linear,
            );
      encoder.addFrame(
        frame,
        duration: math.max(1, (frameStepMs / 10).round()),
      );
    }

    final bytes = encoder.finish();
    if (bytes == null || bytes.isEmpty) {
      throw const _GifTaskException('GIF 压缩结果为空，请重试');
    }
    final output = _writeOutputFile(outputPath, bytes);
    return <String, Object?>{
      'ok': true,
      'outputPath': output.path,
      'outputSizeBytes': output.lengthSync(),
      'originalSizeBytes': sourceFile.lengthSync(),
      'frameCount': sampling.frameIndices.length,
      'frameStepMs': frameStepMs,
      'scalePercent': scalePercent,
      'width': targetWidth,
      'height': targetHeight,
    };
  });
}

img.GifEncoder _createEncoder() {
  return img.GifEncoder(
    repeat: 0,
    quantizerType: img.QuantizerType.octree,
    dither: img.DitherKernel.none,
    dispose: 2,
  );
}

img.Image _decodeStaticImage(String path) {
  final file = _requireInputFile(path);
  final bytes = file.readAsBytesSync();
  final decoder = img.findDecoderForData(bytes);
  final image = decoder?.decode(bytes, frame: 0);
  if (image == null || image.width <= 0 || image.height <= 0) {
    throw const _GifTaskException('图片格式不支持或文件已损坏');
  }
  if (image.width * image.height >
      GifProcessingService.maxDecodedAnimationPixels) {
    throw const _GifTaskException('图片尺寸过大，请先缩小后再生成 GIF');
  }
  return img.Image.from(image, noAnimation: true);
}

img.Image _decodeGifAnimation(String path) {
  final file = _requireInputFile(path);
  final bytes = file.readAsBytesSync();
  final decoder = img.GifDecoder();
  final info = decoder.startDecode(bytes);
  if (info == null ||
      info.width <= 0 ||
      info.height <= 0 ||
      info.numFrames <= 0) {
    throw const _GifTaskException('GIF 格式不支持或文件已损坏');
  }
  if (info.numFrames > GifProcessingService.maxInputFrames) {
    throw const _GifTaskException('GIF 帧数过多，请使用不超过 500 帧的文件');
  }
  final totalPixels = info.width * info.height * info.numFrames;
  if (totalPixels > GifProcessingService.maxDecodedAnimationPixels) {
    throw const _GifTaskException('GIF 尺寸或帧数过大，请先压缩后再处理');
  }
  _validateOutputDimensions(info.width, info.height);

  final animation = decoder.decode(bytes);
  if (animation == null || animation.frames.isEmpty) {
    throw const _GifTaskException('GIF 解码失败，请确认文件未损坏');
  }
  return animation;
}

_GifSampling _sampleAnimation(img.Image animation, int frameStepMs) {
  final durations = animation.frames
      .map(
        (frame) => frame.frameDuration > 0
            ? frame.frameDuration.clamp(10, 60000)
            : frameStepMs,
      )
      .map((duration) => duration.toInt())
      .toList(growable: false);
  final durationMs = durations.fold<int>(0, (sum, value) => sum + value);
  final frameIndices = <int>[];
  var frameIndex = 0;
  var frameStartMs = 0;

  for (
    var sampleTimeMs = 0;
    sampleTimeMs < durationMs &&
        frameIndices.length < GifProcessingService.maxOutputFrames;
    sampleTimeMs += frameStepMs
  ) {
    while (frameIndex < durations.length - 1 &&
        sampleTimeMs >= frameStartMs + durations[frameIndex]) {
      frameStartMs += durations[frameIndex];
      frameIndex++;
    }
    frameIndices.add(frameIndex);
  }

  if (frameIndices.isEmpty) {
    frameIndices.add(0);
  }
  return _GifSampling(frameIndices: frameIndices, durationMs: durationMs);
}

void _validateOutputDimensions(int width, int height) {
  if (width <= 0 || height <= 0) {
    throw const _GifTaskException('GIF 输出尺寸无效');
  }
  if (width * height > GifProcessingService.maxOutputPixels) {
    throw const _GifTaskException('GIF 输出尺寸过大，请先缩小图片');
  }
}

File _requireInputFile(String path) {
  final normalizedPath = path.trim();
  if (normalizedPath.isEmpty) {
    throw const _GifTaskException('文件路径为空，请重新选择');
  }
  final file = File(normalizedPath);
  if (!file.existsSync()) {
    throw const _GifTaskException('文件不存在，请重新选择');
  }
  final length = file.lengthSync();
  if (length <= 0) {
    throw const _GifTaskException('文件为空，请重新选择');
  }
  if (length > GifProcessingService.maxInputFileBytes) {
    throw const _GifTaskException('文件过大，请选择不超过 48 MB 的文件');
  }
  return file;
}

File _writeOutputFile(String outputPath, List<int> bytes) {
  final output = File(outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(bytes, flush: true);
  if (!output.existsSync() || output.lengthSync() <= 0) {
    throw const _GifTaskException('GIF 文件写入失败，请检查存储空间');
  }
  return output;
}

Map<String, Object?> _guardGifTask(Map<String, Object?> Function() operation) {
  try {
    return operation();
  } on _GifTaskException catch (error) {
    return <String, Object?>{'ok': false, 'message': error.message};
  } on FileSystemException {
    return <String, Object?>{'ok': false, 'message': '文件读写失败，请检查存储空间和文件权限'};
  } catch (_) {
    return <String, Object?>{'ok': false, 'message': 'GIF 处理失败，请重试'};
  }
}

class _GifSampling {
  const _GifSampling({required this.frameIndices, required this.durationMs});

  final List<int> frameIndices;
  final int durationMs;
}

class _GifTaskException implements Exception {
  const _GifTaskException(this.message);

  final String message;
}
