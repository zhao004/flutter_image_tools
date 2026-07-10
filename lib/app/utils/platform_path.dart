import 'dart:io';

/// 本地文件系统路径拼接工具。
///
/// 设计意图：输出文件必须使用运行平台的分隔符，避免 Android 将反斜杠
/// 当作普通文件名字符。测试可注入分隔符，覆盖不同平台的边界行为。
abstract final class PlatformPath {
  const PlatformPath._();

  /// 拼接父路径与子路径，并移除边界处重复的路径分隔符。
  ///
  /// 异常策略：父路径、子路径为空或分隔符非法时立即抛出参数异常，
  /// 防止生成位置不明确的输出文件。
  static String join(String parent, String child, {String? separator}) {
    if (parent.trim().isEmpty) {
      throw ArgumentError.value(parent, 'parent', '父路径不能为空');
    }
    if (child.trim().isEmpty) {
      throw ArgumentError.value(child, 'child', '子路径不能为空');
    }

    final effectiveSeparator = separator ?? Platform.pathSeparator;
    if (effectiveSeparator != '/' && effectiveSeparator != r'\') {
      throw ArgumentError.value(
        effectiveSeparator,
        'separator',
        '路径分隔符必须是正斜杠或反斜杠',
      );
    }

    var normalizedParent = parent;
    while (normalizedParent.length > 1 &&
        (normalizedParent.endsWith('/') || normalizedParent.endsWith(r'\'))) {
      normalizedParent = normalizedParent.substring(
        0,
        normalizedParent.length - 1,
      );
    }

    var normalizedChild = child;
    while (normalizedChild.startsWith('/') ||
        normalizedChild.startsWith(r'\')) {
      normalizedChild = normalizedChild.substring(1);
    }
    if (normalizedChild.isEmpty) {
      throw ArgumentError.value(child, 'child', '子路径不能只包含分隔符');
    }

    if (normalizedParent == effectiveSeparator) {
      return '$effectiveSeparator$normalizedChild';
    }
    return '$normalizedParent$effectiveSeparator$normalizedChild';
  }
}
