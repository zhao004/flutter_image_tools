import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

/// Base64 编码输出，完整文本仅供复制与导出，界面应使用短预览。
class Base64EncodeOutput {
  const Base64EncodeOutput({required this.text, required this.sourceSizeBytes});

  final String text;
  final int sourceSizeBytes;
}

/// Base64 图片解码输出，避免把大字节数组传回主 isolate。
class Base64DecodeOutput {
  const Base64DecodeOutput({
    required this.outputPath,
    required this.outputSizeBytes,
    required this.base64Length,
    required this.mimeType,
  });

  final String outputPath;
  final int outputSizeBytes;
  final int base64Length;
  final String mimeType;
}

/// Base64 后台处理服务。
///
/// 设计意图：大文件读取、字符串编码、空白清洗和字节解码都在独立 isolate
/// 执行；解码任务直接写入目标目录，仅返回轻量元数据。异常策略：参数和文件
/// 边界在调度前校验，格式错误保留为 [FormatException] 交由控制器转换提示。
class Base64ProcessingService {
  const Base64ProcessingService._();

  static Future<Base64EncodeOutput> encodeFile({
    required String path,
    required int maxInputBytes,
  }) async {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw ArgumentError.value(path, 'path', '图片路径不能为空');
    }
    if (maxInputBytes <= 0) {
      throw ArgumentError.value(maxInputBytes, 'maxInputBytes', '文件上限必须大于 0');
    }
    final file = File(normalizedPath);
    if (!await file.exists()) {
      throw const FileSystemException('图片文件不存在');
    }
    final sizeBytes = await file.length();
    if (sizeBytes <= 0) {
      throw const FileSystemException('图片文件为空');
    }
    if (sizeBytes > maxInputBytes) {
      throw RangeError.range(sizeBytes, 1, maxInputBytes, 'sizeBytes');
    }

    final text = await Isolate.run(() {
      final bytes = File(normalizedPath).readAsBytesSync();
      return base64Encode(bytes);
    });
    return Base64EncodeOutput(text: text, sourceSizeBytes: sizeBytes);
  }

  static Future<Base64DecodeOutput> decodeToImage({
    required String rawText,
    required String outputDirectory,
    required int maxBase64Chars,
  }) async {
    if (rawText.isEmpty) {
      throw const FormatException('Base64 内容为空');
    }
    if (maxBase64Chars <= 0) {
      throw ArgumentError.value(maxBase64Chars, 'maxBase64Chars', '文本上限必须大于 0');
    }
    if (rawText.length > maxBase64Chars) {
      throw RangeError.range(
        rawText.length,
        1,
        maxBase64Chars,
        'rawText.length',
      );
    }
    final normalizedDirectory = outputDirectory.trim();
    if (normalizedDirectory.isEmpty) {
      throw ArgumentError.value(outputDirectory, 'outputDirectory', '输出目录不能为空');
    }

    final result = await Isolate.run(
      () => _decodeTask(rawText, normalizedDirectory),
    );
    return Base64DecodeOutput(
      outputPath: result['outputPath']! as String,
      outputSizeBytes: result['outputSizeBytes']! as int,
      base64Length: result['base64Length']! as int,
      mimeType: result['mimeType']! as String,
    );
  }

  static Future<int> writeTextFile({
    required String text,
    required String outputPath,
  }) {
    if (text.isEmpty) {
      throw ArgumentError.value(text, 'text', '导出文本不能为空');
    }
    if (outputPath.trim().isEmpty) {
      throw ArgumentError.value(outputPath, 'outputPath', '输出路径不能为空');
    }
    return Isolate.run(() {
      final file = File(outputPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(text, encoding: utf8, flush: true);
      return file.lengthSync();
    });
  }

  static String buildPreview(String text, {int edgeLength = 72}) {
    if (edgeLength <= 0) {
      throw ArgumentError.value(edgeLength, 'edgeLength', '预览长度必须大于 0');
    }
    if (text.length <= edgeLength * 2) {
      return text;
    }
    return '${text.substring(0, edgeLength)}\n...\n'
        '${text.substring(text.length - edgeLength)}';
  }
}

Map<String, Object> _decodeTask(String rawText, String outputDirectory) {
  final normalized = rawText.replaceAll(RegExp(r'\s+'), '');
  if (normalized.isEmpty) {
    throw const FormatException('Base64 内容为空');
  }

  var payload = normalized;
  var mimeType = 'image/png';
  if (normalized.startsWith('data:')) {
    final separatorIndex = normalized.indexOf(',');
    if (separatorIndex <= 5) {
      throw const FormatException('Data URI 缺少内容');
    }
    final header = normalized.substring(5, separatorIndex);
    if (!header.toLowerCase().contains(';base64')) {
      throw const FormatException('Data URI 不是 Base64 编码');
    }
    final declaredMimeType = header.split(';').first.trim().toLowerCase();
    if (declaredMimeType.startsWith('image/')) {
      mimeType = declaredMimeType;
    }
    payload = normalized.substring(separatorIndex + 1);
  }
  if (payload.isEmpty) {
    throw const FormatException('Base64 内容为空');
  }

  final bytes = base64Decode(payload);
  if (bytes.isEmpty) {
    throw const FormatException('Base64 内容为空');
  }
  final extension = switch (mimeType) {
    'image/jpeg' || 'image/jpg' => 'jpg',
    'image/webp' => 'webp',
    'image/bmp' => 'bmp',
    _ => 'png',
  };
  final directory = Directory(outputDirectory)..createSync(recursive: true);
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final output = File('${directory.path}/decoded_base64_$timestamp.$extension');
  output.writeAsBytesSync(bytes, flush: true);
  return <String, Object>{
    'outputPath': output.path,
    'outputSizeBytes': output.lengthSync(),
    'base64Length': payload.length,
    'mimeType': mimeType,
  };
}
