import 'dart:convert';
import 'package:http/http.dart' as http;

/// 应用更新服务
///
/// 通过 GitHub Releases 检查新版本。
/// 仓库地址：https://github.com/cheymin/Cloud-Mail-For-Android
class UpdateService {
  static const String repoOwner = 'cheymin';
  static const String repoName = 'Cloud-Mail-For-Android';
  static const String repoUrl =
      'https://github.com/$repoOwner/$repoName';

  /// 获取所有 release（用于更新页展示历史版本）
  static Future<List<ReleaseInfo>> fetchAllReleases() async {
    final url =
        'https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=20';
    final response = await http.get(Uri.parse(url), headers: {
      'Accept': 'application/vnd.github+json',
    });

    if (response.statusCode != 200) {
      throw Exception('GitHub 接口返回 ${response.statusCode}');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! List) return [];

    return json
        .map((e) => ReleaseInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 检查最新版本是否有更新
  /// currentVersion 不带前缀 v，例如 '4.0.0'
  static Future<UpdateInfo?> checkUpdate(String currentVersion) async {
    try {
      final releases = await fetchAllReleases();
      if (releases.isEmpty) {
        return UpdateInfo(
          version: currentVersion,
          tag: 'v$currentVersion',
          releaseNotes: '',
          downloadUrl: null,
          hasUpdate: false,
          latestRelease: null,
          allReleases: const [],
        );
      }

      final latest = releases.first;
      final latestVersion = latest.version; // 已去掉前缀 v

      final hasUpdate =
          _compareVersions(latestVersion, currentVersion) > 0;

      return UpdateInfo(
        version: latestVersion,
        tag: latest.tagName,
        releaseNotes: latest.body,
        downloadUrl: latest.apkUrl,
        hasUpdate: hasUpdate,
        latestRelease: latest,
        allReleases: releases,
      );
    } catch (_) {
      return UpdateInfo(
        version: currentVersion,
        tag: 'v$currentVersion',
        releaseNotes: '',
        downloadUrl: null,
        hasUpdate: false,
        latestRelease: null,
        allReleases: const [],
      );
    }
  }

  /// 比较版本号：v1 > v2 返回 1，相等返回 0，小于返回 -1
  static int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((p) {
      final match = RegExp(r'^\d+').firstMatch(p);
      return match != null ? int.parse(match.group(0)!) : 0;
    }).toList();
    final parts2 = v2.split('.').map((p) {
      final match = RegExp(r'^\d+').firstMatch(p);
      return match != null ? int.parse(match.group(0)!) : 0;
    }).toList();

    final length = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (var i = 0; i < length; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1.compareTo(p2);
    }
    return 0;
  }
}

/// 单个 Release 信息
class ReleaseInfo {
  final String tagName;
  final String version; // 不带 v 前缀
  final String name;
  final String body;
  final DateTime publishedAt;
  final bool prerelease;
  final String htmlUrl;
  final String? apkUrl;
  final List<ReleaseAsset> assets;

  ReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    required this.publishedAt,
    required this.prerelease,
    required this.htmlUrl,
    required this.apkUrl,
    required this.assets,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    final version = tag.replaceFirst(RegExp(r'^v'), '');
    final assetsRaw = (json['assets'] as List?) ?? [];
    final assets = assetsRaw
        .map((e) => ReleaseAsset.fromJson(e as Map<String, dynamic>))
        .toList();
    final apkAsset = assets.firstWhere(
      (a) => a.name.toLowerCase().endsWith('.apk'),
      orElse: () => assets.isNotEmpty
          ? assets.first
          : ReleaseAsset.empty(),
    );

    DateTime published;
    try {
      published = DateTime.parse(json['published_at'] as String? ?? '');
    } catch (_) {
      published = DateTime.now();
    }

    return ReleaseInfo(
      tagName: tag,
      version: version,
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      publishedAt: published,
      prerelease: json['prerelease'] as bool? ?? false,
      htmlUrl: json['html_url'] as String? ?? '',
      apkUrl: apkAsset.url,
      assets: assets,
    );
  }
}

class ReleaseAsset {
  final String name;
  final int size;
  final String url;
  final String contentType;

  ReleaseAsset({
    required this.name,
    required this.size,
    required this.url,
    required this.contentType,
  });

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      url: json['browser_download_url'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
    );
  }

  factory ReleaseAsset.empty() => ReleaseAsset(
        name: '',
        size: 0,
        url: '',
        contentType: '',
      );
}

class UpdateInfo {
  final String version;
  final String tag;
  final String releaseNotes;
  final String? downloadUrl;
  final bool hasUpdate;
  final ReleaseInfo? latestRelease;
  final List<ReleaseInfo> allReleases;

  UpdateInfo({
    required this.version,
    required this.tag,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.hasUpdate,
    required this.latestRelease,
    required this.allReleases,
  });
}
