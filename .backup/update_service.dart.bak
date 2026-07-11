import 'dart:convert';
import 'package:http/http.dart' as http;

class UpdateService {
  static const String repoOwner = 'cheymin';
  static const String repoName = 'vpn';

  static Future<UpdateInfo?> checkUpdate(String currentVersion) async {
    try {
      final url =
          'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        final latestTag = json['tag_name'] as String?;
        final releaseNotes = json['body'] as String?;
        final assets = json['assets'] as List?;

        if (latestTag != null && latestTag.isNotEmpty) {
          String? downloadUrl;
          if (assets != null && assets.isNotEmpty) {
            for (final asset in assets) {
              final name = asset['name'] as String?;
              if (name != null && name.endsWith('.apk')) {
                downloadUrl = asset['browser_download_url'] as String?;
                break;
              }
            }
          }

          final latestVersion = latestTag.replaceFirst('v', '');
          if (_compareVersions(latestVersion, currentVersion) > 0) {
            return UpdateInfo(
              version: latestVersion,
              tag: latestTag,
              releaseNotes: releaseNotes ?? '',
              downloadUrl: downloadUrl,
              hasUpdate: true,
            );
          }
        }
      }
    } catch (_) {}

    return UpdateInfo(
      version: currentVersion,
      tag: '',
      releaseNotes: '',
      downloadUrl: null,
      hasUpdate: false,
    );
  }

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

class UpdateInfo {
  final String version;
  final String tag;
  final String releaseNotes;
  final String? downloadUrl;
  final bool hasUpdate;

  UpdateInfo({
    required this.version,
    required this.tag,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.hasUpdate,
  });
}