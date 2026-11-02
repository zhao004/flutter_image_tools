import 'package:pub_semver/pub_semver.dart';

/// 尝试解析应用版本；无效标签返回 null，由调用方决定异常策略。
Version? tryParseAppUpdateVersion(String value) {
  try {
    return Version.parse(value.trim());
  } on FormatException {
    return null;
  }
}

/// GitHub Release 中的单个下载资产。
class AppUpdateAsset {
  const AppUpdateAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  final String name;
  final Uri downloadUrl;
  final int sizeBytes;

  /// 从 GitHub API 资产对象创建模型，格式异常时抛出 [FormatException]。
  factory AppUpdateAsset.fromJson(Map<String, Object?> json) {
    final name = json['name'] as String?;
    final downloadUrl = json['browser_download_url'] as String?;
    final sizeBytes = json['size'];
    final uri = downloadUrl == null ? null : Uri.tryParse(downloadUrl);
    if (name == null ||
        name.trim().isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        sizeBytes is! num) {
      throw const FormatException('GitHub Release 资产格式无效');
    }
    return AppUpdateAsset(
      name: name,
      downloadUrl: uri,
      sizeBytes: sizeBytes.toInt(),
    );
  }
}

/// GitHub 最新正式 Release 及其可下载资产。
class AppUpdateRelease {
  const AppUpdateRelease({
    required this.tagName,
    required this.displayName,
    required this.releaseNotes,
    required this.publishedAt,
    required this.assets,
    required this.isPrerelease,
    required this.isDraft,
  });

  final String tagName;
  final String displayName;
  final String releaseNotes;
  final DateTime? publishedAt;
  final List<AppUpdateAsset> assets;
  final bool isPrerelease;
  final bool isDraft;

  String get versionText {
    final normalized = tagName.trim();
    return normalized.startsWith('v') ? normalized.substring(1) : normalized;
  }

  Version? get version => tryParseAppUpdateVersion(versionText);

  bool get isStable => !isDraft && !isPrerelease && version != null;

  AppUpdateAsset? assetNamed(String name) {
    for (final asset in assets) {
      if (asset.name == name) {
        return asset;
      }
    }
    return null;
  }

  /// 从 GitHub API Release 对象创建模型，格式异常时抛出 [FormatException]。
  factory AppUpdateRelease.fromJson(Map<String, Object?> json) {
    final tagName = json['tag_name'] as String?;
    final rawAssets = json['assets'];
    if (tagName == null || tagName.trim().isEmpty || rawAssets is! List) {
      throw const FormatException('GitHub Release 格式无效');
    }
    final publishedAt = DateTime.tryParse(
      json['published_at'] as String? ?? '',
    );
    final assets = rawAssets
        .whereType<Map>()
        .map(
          (asset) => AppUpdateAsset.fromJson(
            asset.map(
              (key, value) => MapEntry(key.toString(), value as Object?),
            ),
          ),
        )
        .toList(growable: false);
    final name = (json['name'] as String?)?.trim();
    return AppUpdateRelease(
      tagName: tagName.trim(),
      displayName: name == null || name.isEmpty ? tagName.trim() : name,
      releaseNotes: (json['body'] as String?)?.trim() ?? '',
      publishedAt: publishedAt?.toUtc(),
      assets: assets,
      isPrerelease: json['prerelease'] == true,
      isDraft: json['draft'] == true,
    );
  }
}

/// 一次版本检查结果；未发现更新时 release 为空。
class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    required this.release,
    required this.preferredAbi,
  });

  final String currentVersion;
  final String? latestVersion;
  final AppUpdateRelease? release;
  final String? preferredAbi;

  bool get updateAvailable => release != null;
}

/// 下载并校验完成的 APK。
class AppUpdateDownload {
  const AppUpdateDownload({
    required this.filePath,
    required this.sizeBytes,
    required this.sha256,
  });

  final String filePath;
  final int sizeBytes;
  final String sha256;
}
