import 'local_image_file.dart';

/// 文字水印结果模型，记录输入文件、输出路径、水印文本和导出大小。
///
/// 设计意图：水印结果需要保留文本和位置参数，方便用户在历史记录中判断
/// 当前导出图片对应的水印配置。
class WatermarkedImageFile {
  const WatermarkedImageFile({
    required this.source,
    required this.outputPath,
    required this.outputSizeBytes,
    required this.text,
    required this.position,
  });

  final LocalImageFile source;
  final String outputPath;
  final int outputSizeBytes;
  final String text;
  final String position;

  factory WatermarkedImageFile.fromMap({
    required LocalImageFile source,
    required String text,
    required String position,
    required Map<Object?, Object?> map,
  }) {
    return WatermarkedImageFile(
      source: source,
      outputPath: map['outputPath'] as String? ?? '',
      outputSizeBytes: map['outputSizeBytes'] as int? ?? 0,
      text: text,
      position: map['position'] as String? ?? position,
    );
  }
}
