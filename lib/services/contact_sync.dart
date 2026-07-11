import 'dart:convert';
import '../models/contact.dart';
import '../services/webdav_service.dart';
import '../utils/storage.dart';

/// 联系人 WebDAV 同步服务
/// 封装上传/下载联系人到 WebDAV 的完整流程
class ContactSync {
  static const _filename = 'contacts.json';

  /// 读取已保存的 WebDAV 配置
  static WebDavConfig? loadConfig() {
    final raw = StorageService.webdavConfig;
    if (raw == null || raw.isEmpty) return null;
    try {
      return WebDavConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 保存 WebDAV 配置
  static void saveConfig(WebDavConfig config) {
    StorageService.webdavConfig = jsonEncode(config.toJson());
  }

  /// 清除 WebDAV 配置
  static void clearConfig() {
    StorageService.webdavConfig = null;
  }

  /// 测试连接
  static Future<bool> testConnection(WebDavConfig config) async {
    final svc = WebDavService(config);
    return svc.testConnection();
  }

  /// 上传联系人到云端
  static Future<SyncResult> upload() async {
    final config = loadConfig();
    if (config == null || !config.isConfigured) {
      return const SyncResult(success: false, message: '请先配置 WebDAV');
    }
    final svc = WebDavService(config);
    final json = ContactStore.exportJson();
    final ok = await svc.uploadString(_filename, json);
    return SyncResult(
      success: ok,
      message: ok ? '已上传 ${ContactStore.cached.length} 个联系人' : '上传失败，请检查配置',
      changed: ContactStore.cached.length,
    );
  }

  /// 从云端下载并合并联系人
  static Future<SyncResult> download() async {
    final config = loadConfig();
    if (config == null || !config.isConfigured) {
      return const SyncResult(success: false, message: '请先配置 WebDAV');
    }
    final svc = WebDavService(config);
    final raw = await svc.downloadString(_filename);
    if (raw == null) {
      return const SyncResult(success: false, message: '云端暂无联系人数据');
    }
    final changed = await ContactStore.importJson(raw, merge: true);
    return SyncResult(
      success: true,
      message: changed > 0 ? '已同步 $changed 条更新' : '云端无新数据',
      changed: changed,
    );
  }

  /// 双向同步：先下载合并，再上传完整数据
  static Future<SyncResult> sync() async {
    final dl = await download();
    if (!dl.success) return dl;
    final ul = await upload();
    if (!ul.success) {
      return SyncResult(
        success: false,
        message: '下载成功但上传失败：${ul.message}',
        changed: dl.changed,
      );
    }
    return SyncResult(
      success: true,
      message: dl.changed > 0
          ? '同步完成，更新了 ${dl.changed} 条'
          : '同步完成，已是最新',
      changed: dl.changed,
    );
  }
}
