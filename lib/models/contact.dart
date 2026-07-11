import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 联系人模型
class Contact {
  final String id;
  String name;
  String email;
  String phone;
  String note;
  String company;
  int createdAt;
  int updatedAt;

  Contact({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.note = '',
    this.company = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'note': note,
        'company': company,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      note: json['note'] as String? ?? '',
      company: json['company'] as String? ?? '',
      createdAt: json['createdAt'] as int? ?? 0,
      updatedAt: json['updatedAt'] as int? ?? 0,
    );
  }

  /// 用于排序的首字母（取 name 第一个字符）
  String get sortKey => name.isNotEmpty ? name[0].toUpperCase() : '#';
}

/// 联系人本地存储 + WebDAV 同步数据源
class ContactStore {
  static const _key = 'contacts';

  static List<Contact> _cached = [];

  /// 从 SharedPreferences 加载到内存缓存
  static Future<List<Contact>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _cached = [];
      return _cached;
    }
    try {
      final list = jsonDecode(raw) as List;
      _cached = list
          .map((e) => Contact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      _cached = [];
    }
    return _cached;
  }

  /// 内存缓存（load 后可用）
  static List<Contact> get cached => _cached;

  /// 写回存储
  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_cached.map((c) => c.toJson()).toList()),
    );
  }

  /// 新增联系人，返回新增的 contact
  static Future<Contact> add({
    required String name,
    required String email,
    String phone = '',
    String note = '',
    String company = '',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final c = Contact(
      id: now.toString(),
      name: name,
      email: email,
      phone: phone,
      note: note,
      company: company,
      createdAt: now,
      updatedAt: now,
    );
    _cached.add(c);
    await _persist();
    return c;
  }

  /// 更新联系人
  static Future<void> update(Contact c) async {
    final idx = _cached.indexWhere((e) => e.id == c.id);
    if (idx >= 0) {
      c.updatedAt = DateTime.now().millisecondsSinceEpoch;
      _cached[idx] = c;
      await _persist();
    }
  }

  /// 删除联系人
  static Future<void> delete(String id) async {
    _cached.removeWhere((e) => e.id == id);
    await _persist();
  }

  /// 按名字/邮箱/电话搜索
  static List<Contact> search(String keyword) {
    if (keyword.isEmpty) return _cached;
    final k = keyword.toLowerCase();
    return _cached.where((c) {
      return c.name.toLowerCase().contains(k) ||
          c.email.toLowerCase().contains(k) ||
          c.phone.toLowerCase().contains(k) ||
          c.company.toLowerCase().contains(k);
    }).toList();
  }

  /// 按首字母分组排序
  static Map<String, List<Contact>> grouped() {
    final sorted = List<Contact>.from(_cached)
      ..sort((a, b) => a.sortKey.compareTo(b.sortKey));
    final map = <String, List<Contact>>{};
    for (final c in sorted) {
      final key = RegExp(r'[A-Z]').hasMatch(c.sortKey) ? c.sortKey : '#';
      map.putIfAbsent(key, () => []).add(c);
    }
    return map;
  }

  /// 导出为 JSON 字符串（用于 WebDAV 同步）
  static String exportJson() =>
      jsonEncode(_cached.map((c) => c.toJson()).toList());

  /// 从 JSON 字符串导入（合并：以 id 去重，较新的 updatedAt 覆盖）
  static Future<int> importJson(String raw, {bool merge = true}) async {
    try {
      final list = jsonDecode(raw) as List;
      final incoming = list
          .map((e) => Contact.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!merge) {
        _cached = incoming;
        await _persist();
        return incoming.length;
      }
      int changed = 0;
      for (final c in incoming) {
        final idx = _cached.indexWhere((e) => e.id == c.id);
        if (idx < 0) {
          _cached.add(c);
          changed++;
        } else if (c.updatedAt > _cached[idx].updatedAt) {
          _cached[idx] = c;
          changed++;
        }
      }
      if (changed > 0) await _persist();
      return changed;
    } catch (_) {
      return 0;
    }
  }
}
