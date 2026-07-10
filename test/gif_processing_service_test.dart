import 'dart:io';

import 'package:flutter_image_tools/app/exceptions/app_exception.dart';
import 'package:flutter_image_tools/app/services/gif_processing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'image_toolkit_gif_test_',
    );
  });

  tearDown(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  test('后台生成、拆帧和压缩 GIF 保持完整结果', () async {
    final first = _writeSolidPng(
      temporaryDirectory,
      name: 'first.png',
      color: img.ColorRgb8(240, 32, 32),
    );
    final second = _writeSolidPng(
      temporaryDirectory,
      name: 'second.png',
      color: img.ColorRgb8(32, 80, 240),
    );
    final gifOutput = File('${temporaryDirectory.path}/generated.gif');

    final generated = await GifProcessingService.createGif(
      paths: [first.path, second.path],
      outputPath: gifOutput.path,
      delayMs: 120,
    );

    expect(generated['frameCount'], 2);
    expect(generated['width'], 32);
    expect(generated['height'], 24);
    expect(gifOutput.existsSync(), isTrue);
    final decoded = img.decodeGif(gifOutput.readAsBytesSync());
    expect(decoded, isNotNull);
    expect(decoded!.numFrames, 2);
    expect(decoded.frames.every((frame) => frame.frameDuration == 120), isTrue);

    final framesDirectory = Directory(
      '${temporaryDirectory.path}/exported_frames',
    );
    final exported = await GifProcessingService.exportFrames(
      sourcePath: gifOutput.path,
      outputDirectory: framesDirectory.path,
      frameStepMs: 120,
    );
    final outputPaths = (exported['outputPaths'] as List<Object?>)
        .whereType<String>()
        .toList(growable: false);

    expect(exported['frameCount'], 2);
    expect(exported['durationMs'], 240);
    expect(outputPaths, hasLength(2));
    expect(outputPaths.every((path) => File(path).existsSync()), isTrue);

    final compressedOutput = File('${temporaryDirectory.path}/compressed.gif');
    final compressed = await GifProcessingService.compressGif(
      sourcePath: gifOutput.path,
      outputPath: compressedOutput.path,
      frameStepMs: 120,
      scalePercent: 50,
    );

    expect(compressed['frameCount'], 2);
    expect(compressed['width'], 16);
    expect(compressed['height'], 12);
    expect(compressedOutput.existsSync(), isTrue);
    final compressedImage = img.decodeGif(compressedOutput.readAsBytesSync());
    expect(compressedImage, isNotNull);
    expect(compressedImage!.numFrames, 2);
  });

  test('空 GIF 文件返回可读异常而不是导致进程崩溃', () async {
    final emptyGif = File('${temporaryDirectory.path}/empty.gif')
      ..writeAsBytesSync(const []);

    expect(
      () => GifProcessingService.exportFrames(
        sourcePath: emptyGif.path,
        outputDirectory: '${temporaryDirectory.path}/frames',
        frameStepMs: 200,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.message,
          'message',
          contains('文件为空'),
        ),
      ),
    );
  });
}

File _writeSolidPng(
  Directory directory, {
  required String name,
  required img.Color color,
}) {
  final image = img.Image(width: 32, height: 24);
  img.fill(image, color: color);
  final file = File('${directory.path}/$name');
  file.writeAsBytesSync(img.encodePng(image), flush: true);
  return file;
}
