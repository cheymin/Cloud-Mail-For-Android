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

  /// 拉取所有已发布的 release（用于更新页展示历史版本列表）
  ///
  /// 失败时抛出 [UpdateException]，UI 层可据此显示具体原因。
  static Future<List<ReleaseInfo>> fetchAllReleases() async {
    final url =
        'https://api.github.com/repos/$repoOwner/$repoName/releases?per_page=30';
    // GitHub API 要求所有请求带 User-Agent，否则可能被拒绝
    final response = await http.get(Uri.parse(url), headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'Cloud-Mail-App',
    });

    if (response.statusCode == 404) {
      // 仓库不存在或没有任何 release
      throw UpdateException('仓库暂无任何已发布版本', code: 404);
    }
    if (response.statusCode == 403) {
      // 未认证请求限流（60次/小时）
      final body = _safeDecode(response);
      final msg = body is Map ? (body['message'] as String? ?? '') : '';
      throw UpdateException(
        msg.contains('rate limit')
            ? 'GitHub 请求过于频繁，请稍后再试'
            : 'GitHub 拒绝了请求（403）',
        code: 403,
      );
    }
    if (response.statusCode != 200) {
      // 带上响应体片段便于排查
      final body = utf8.decode(response.bodyBytes);
      final snippet = body.length > 200 ? body.substring(0, 200) : body;
      throw UpdateException(
          'GitHub 接口返回 ${response.statusCode}: $snippet',
          code: response.statusCode);
    }

    final json = _safeDecode(response);
    if (json is! List) return [];

    return json
        .map((e) => ReleaseInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 检查更新
  ///
  /// [currentVersion] 不带前缀 v，例如 '4.1.0'。
  /// 优先用 /releases/latest 判断「是否有新版本」，
  /// 同时拉取全部 releases 供用户手动选择下载。
  ///
  /// 如果没有任何 release（404），返回 hasUpdate=false 且 allReleases=[]，
  /// UI 层据此显示「暂无发布版本」。
  static Future<UpdateInfo> checkUpdate(String currentVersion) async {
    // 先拉全部 releases（用户可手动选下载）
    List<ReleaseInfo> allReleases;
    try {
      allReleases = await fetchAllReleases();
    } on UpdateException catch (e) {
      // 404 = 没有 release，不算错误，只是没有可下载的版本
      if (e.code == 404) {
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
      // 其他错误（限流、网络）向上抛
      rethrow;
    }

    if (allReleases.isEmpty) {
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

    // 第一个就是最新版（GitHub 默认按发布时间倒序）
    final latest = allReleases.first;
    final latestVersion = latest.version; // 已去掉前缀 v

    final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;

    return UpdateInfo(
      version: latestVersion,
      tag: latest.tagName,
      releaseNotes: latest.body,
      downloadUrl: latest.apkUrl,
      hasUpdate: hasUpdate,
      latestRelease: latest,
      allReleases: allReleases,
    );
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

  static dynamic _safeDecode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }
}

/// 更新服务异常，带状态码便于 UI 区分处理
class UpdateException implements Exception {
  final String message;
  final int code;
  UpdateException(this.message, {required this.code});

  @override
  String toString() => message;
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
    // 找 .apk 后缀的资源；找不到就用第一个；都没有就 null
    String? apk;
    if (assets.isNotEmpty) {
      final apkAsset = assets.firstWhere(
        (a) => a.name.toLowerCase().endsWith('.apk'),
        orElse: () => assets.first,
      );
      apk = apkAsset.url;
    }

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
      apkUrl: apk,
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
