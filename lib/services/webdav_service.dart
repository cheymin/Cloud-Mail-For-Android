import 'dart:convert';
import 'package:http/http.dart' as http;

/// WebDAV 同步配置
class WebDavConfig {
  final String url;       // 服务器地址，如 https://dav.example.com/remote.php/dav/files/user
  final String username;
  final String password;
  final String remoteDir; // 远程目录，如 /CloudMail

  const WebDavConfig({
    required this.url,
    required this.username,
    required this.password,
    this.remoteDir = '/CloudMail',
  });

  bool get isConfigured =>
      url.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'url': url,
        'username': username,
        'password': password,
        'remoteDir': remoteDir,
      };

  factory WebDavConfig.fromJson(Map<String, dynamic> json) => WebDavConfig(
        url: json['url'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
        remoteDir: json['remoteDir'] as String? ?? '/CloudMail',
      );
}

/// WebDAV 同步结果
class SyncResult {
  final bool success;
  final String message;
  final int changed; // 变更条目数

  const SyncResult({
    required this.success,
    required this.message,
    this.changed = 0,
  });
}

/// WebDAV 客户端，支持上传/下载文件
/// 用于同步联系人、邮件缓存等数据到云端
class WebDavService {
  final WebDavConfig config;

  WebDavService(this.config);

  String get _baseUrl => config.url.endsWith('/')
      ? config.url.substring(0, config.url.length - 1)
      : config.url;

  String _remotePath(String filename) {
    final dir = config.remoteDir.startsWith('/')
        ? config.remoteDir
        : '/${config.remoteDir}';
    return '$_baseUrl$dir/$filename';
  }

  Map<String, String> get _auth => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}',
      };

  /// 确保远程目录存在（MKCOL，已存在返回 405 也算成功）
  Future<bool> ensureDir() async {
    final dir = config.remoteDir.startsWith('/')
        ? config.remoteDir
        : '/${config.remoteDir}';
    final url = '$_baseUrl$dir';
    try {
      final req = http.Request('MKCOL', Uri.parse(url));
      req.headers.addAll(_auth);
      final client = http.Client();
      final res = await client.send(req);
      client.close();
      // 201=创建成功，405=已存在，301=重定向（部分服务）
      return res.statusCode == 201 ||
          res.statusCode == 405 ||
          res.statusCode == 301;
    } catch (_) {
      return false;
    }
  }

  /// 上传字符串内容到远程文件
  Future<bool> uploadString(String filename, String content) async {
    if (!config.isConfigured) return false;
    try {
      await ensureDir();
      final res = await http.put(
        Uri.parse(_remotePath(filename)),
        headers: {
          ..._auth,
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: utf8.encode(content),
      );
      // 200/201/204 都算成功
      return res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// 下载远程文件为字符串
  Future<String?> downloadString(String filename) async {
    if (!config.isConfigured) return null;
    try {
      final res = await http.get(
        Uri.parse(_remotePath(filename)),
        headers: _auth,
      );
      if (res.statusCode == 200) {
        return utf8.decode(res.bodyBytes);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 测试连接：尝试 PROPFIND 根目录
  Future<bool> testConnection() async {
    if (!config.isConfigured) return false;
    try {
      final req = http.Request('PROPFIND', Uri.parse('$_baseUrl/'));
      req.headers.addAll({
        ..._auth,
        'Depth': '0',
        'Content-Type': 'application/xml; charset=utf-8',
      });
      req.body = '<?xml version="1.0" encoding="utf-8"?>'
          '<propfind xmlns="DAV:"><prop><displayname/></prop></propfind>';
      final client = http.Client();
      final res = await client.send(req);
      client.close();
      // 207 Multi-Status = 成功
      return res.statusCode == 207 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
