import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/contact.dart';
import '../../services/api_service.dart';
import '../../utils/storage.dart';
import '../../utils/glass.dart';

/// 联系人管理页面
///
/// 功能：
/// - 按首字母分组展示联系人列表
/// - 搜索联系人（按姓名 / 邮箱 / 电话 / 公司）
/// - 新增 / 编辑 / 删除联系人
/// - 查看联系人详情并发起写信
class ContactsScreen extends StatefulWidget {
  final CloudMailApi api;

  const ContactsScreen({required this.api, super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // 头像背景色板（根据邮箱哈希取色，保证同一联系人颜色稳定）
  static const List<Color> _avatarColors = [
    Color(0xFFEF5350),
    Color(0xFFEC407A),
    Color(0xFFAB47BC),
    Color(0xFF7E57C2),
    Color(0xFF5C6BC0),
    Color(0xFF42A5F5),
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
    Color(0xFFFFA726),
    Color(0xFFFF7043),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];

  bool _loading = true; // 首次加载标记
  bool _searching = false; // 是否处于搜索态
  String _query = ''; // 当前搜索关键词
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 加载联系人到内存缓存
  Future<void> _loadContacts() async {
    await ContactStore.load();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // 新增 / 编辑 / 删除后刷新视图
  void _refresh() {
    if (mounted) setState(() {});
  }

  // 根据邮箱哈希计算头像背景色
  Color _avatarColor(String email) {
    int hash = 0;
    for (final ch in email.codeUnits) {
      hash = (hash * 31 + ch) & 0x7fffffff;
    }
    final key = email.isEmpty ? 0 : hash;
    return _avatarColors[key % _avatarColors.length];
  }

  // 切换搜索态
  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  // 打开新增 / 编辑表单（复用同一表单，contact 为空即新增）
  Future<void> _showContactForm({Contact? contact}) async {
    final isEdit = contact != null;
    final cs = Theme.of(context).colorScheme;

    final nameCtrl = TextEditingController(text: contact?.name ?? '');
    final emailCtrl = TextEditingController(text: contact?.email ?? '');
    final phoneCtrl = TextEditingController(text: contact?.phone ?? '');
    final companyCtrl = TextEditingController(text: contact?.company ?? '');
    final noteCtrl = TextEditingController(text: contact?.note ?? '');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部拖拽指示条
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  isEdit ? '编辑联系人' : '新增联系人',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: '姓名 *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '请输入姓名' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '邮箱 *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return '请输入邮箱';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                      return '邮箱格式不正确';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '电话',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: companyCtrl,
                  decoration: const InputDecoration(
                    labelText: '公司',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    if (isEdit) {
                      // 直接在原对象上更新字段后调用 update
                      contact!.name = nameCtrl.text.trim();
                      contact.email = emailCtrl.text.trim();
                      contact.phone = phoneCtrl.text.trim();
                      contact.company = companyCtrl.text.trim();
                      contact.note = noteCtrl.text.trim();
                      await ContactStore.update(contact);
                    } else {
                      await ContactStore.add(
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        company: companyCtrl.text.trim(),
                        note: noteCtrl.text.trim(),
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _refresh();
                  },
                  icon: const Icon(Icons.check),
                  label: Text(isEdit ? '保存' : '添加'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 打开联系人详情（底部毛玻璃弹层）
  void _showContactDetail(Contact contact) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarColor = _avatarColor(contact.email);
    final initial =
        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return GlassBox(
          isDark: isDark,
          blur: 30,
          opacity: 0.9,
          radius: 24,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部头像 + 姓名
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: avatarColor,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: Theme.of(ctx)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (contact.company.isNotEmpty)
                          Text(
                            contact.company,
                            style: Theme.of(ctx)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _DetailRow(
                icon: Icons.alternate_email,
                label: '邮箱',
                value: contact.email,
                iconColor: cs.primary,
              ),
              if (contact.phone.isNotEmpty)
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: '电话',
                  value: contact.phone,
                  iconColor: cs.primary,
                ),
              if (contact.company.isNotEmpty)
                _DetailRow(
                  icon: Icons.business_outlined,
                  label: '公司',
                  value: contact.company,
                  iconColor: cs.primary,
                ),
              if (contact.note.isNotEmpty)
                _DetailRow(
                  icon: Icons.note_outlined,
                  label: '备注',
                  value: contact.note,
                  iconColor: cs.primary,
                ),
              const SizedBox(height: 20),
              // 操作区：发邮件 / 编辑 / 删除
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _compose(contact);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('发邮件'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showContactForm(contact: contact);
                      },
                      icon: const Icon(Icons.tune),
                      label: const Text('编辑'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '删除',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmDelete(contact);
                    },
                    icon: const Icon(Icons.delete_outline),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.errorContainer,
                      foregroundColor: cs.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 跳转到写信页（预填收件人）
  void _compose(Contact contact) {
    Navigator.pushNamed(
      context,
      '/compose',
      arguments: {
        'api': widget.api,
        'prefillEmail': contact.email,
        'prefillName': contact.name,
      },
    );
  }

  // 删除确认弹窗
  Future<void> _confirmDelete(Contact contact) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定要删除「${contact.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: cs.errorContainer,
              foregroundColor: cs.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ContactStore.delete(contact.id);
      _refresh();
    }
  }

  // ===== 快速导入 =====

  /// 解析一行文本为 (姓名, 邮箱)
  /// 支持格式：
  ///   "姓名 <email@example.com>"
  ///   "姓名,email@example.com"
  ///   "姓名;email@example.com"
  ///   "姓名 email@example.com"（最后一个 token 是邮箱）
  ///   "email@example.com"（姓名取 @ 前部分）
  (String, String)? _parseLine(String line) {
    line = line.trim();
    if (line.isEmpty) return null;

    // 格式1：姓名 <email>
    final angleMatch = RegExp(r'^(.+?)\s*<([^>]+)>\s*$').firstMatch(line);
    if (angleMatch != null) {
      return (angleMatch.group(1)!.trim(), angleMatch.group(2)!.trim());
    }

    // 格式2：用逗号/分号分隔
    if (line.contains(',') || line.contains(';')) {
      final parts = line.split(RegExp(r'[,;]'));
      if (parts.length >= 2) {
        final email = parts.last.trim();
        final name = parts.take(parts.length - 1).join(' ').trim();
        if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
          return (name.isEmpty ? email.split('@').first : name, email);
        }
      }
    }

    // 格式3：用空格分隔，最后一个 token 是邮箱
    final tokens = line.split(RegExp(r'\s+'));
    if (tokens.length >= 2) {
      final last = tokens.last;
      if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(last)) {
        final name = tokens.take(tokens.length - 1).join(' ').trim();
        return (name.isEmpty ? last.split('@').first : name, last);
      }
    }

    // 格式4：纯邮箱
    if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(line)) {
      return (line.split('@').first, line);
    }

    return null;
  }

  /// 批量粘贴文本导入
  Future<void> _importFromText() async {
    final cs = Theme.of(context).colorScheme;
    final textCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量粘贴导入'),
        content: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每行一个联系人，支持以下格式：',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '张三 <zhangsan@example.com>\n张三,zhangsan@example.com\nzhangsan@example.com',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: textCtrl,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: '粘贴联系人列表...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final text = textCtrl.text;
    textCtrl.dispose();

    final lines = text.split('\n');
    int imported = 0;
    int skipped = 0;
    for (final line in lines) {
      final parsed = _parseLine(line);
      if (parsed == null) {
        if (line.trim().isNotEmpty) skipped++;
        continue;
      }
      final (name, email) = parsed;
      // 去重：邮箱已存在则跳过
      final exists = ContactStore.cached.any((c) => c.email == email);
      if (exists) {
        skipped++;
        continue;
      }
      await ContactStore.add(name: name, email: email);
      imported++;
    }

    if (mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入完成：成功 $imported 个'
              '${skipped > 0 ? '，跳过 $skipped 个（格式无效或重复）' : ''}'),
        ),
      );
    }
  }

  /// 从文件导入（vCard .vcf 或 CSV .csv）
  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vcf', 'csv'],
        withData: true,
      );
      if (result == null || result.files.single.bytes == null) return;

      final file = result.files.single;
      final content = String.fromCharCodes(file.bytes!);
      int imported = 0;

      if (file.extension?.toLowerCase() == 'vcf') {
        imported = _parseVCard(content);
      } else if (file.extension?.toLowerCase() == 'csv') {
        imported = _parseCsv(content);
      }

      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('从文件导入完成：成功 $imported 个联系人')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  /// 解析 vCard 内容，返回导入数量
  int _parseVCard(String content) {
    final cards = RegExp(r'BEGIN:VCARD[\s\S]*?END:VCARD', caseSensitive: false)
        .allMatches(content);
    int count = 0;
    for (final cardMatch in cards) {
      final card = cardMatch.group(0)!;
      String? name, email;
      // FN:全名
      final fnMatch = RegExp(r'^FN:(.+)$', multiLine: true).firstMatch(card);
      if (fnMatch != null) name = fnMatch.group(1)!.trim();
      // EMAIL
      final emailMatch =
          RegExp(r'^EMAIL[^:]*:(.+)$', multiLine: true).firstMatch(card);
      if (emailMatch != null) email = emailMatch.group(1)!.trim();
      // 如果没有 FN，尝试 N:姓;名
      if (name == null || name.isEmpty) {
        final nMatch = RegExp(r'^N:([^;]*);([^\r\n]*)', multiLine: true)
            .firstMatch(card);
        if (nMatch != null) {
          final last = nMatch.group(1)?.trim() ?? '';
          final first = nMatch.group(2)?.trim() ?? '';
          name = '$last$first'.trim();
        }
      }
      if (email == null || email.isEmpty) continue;
      if (name == null || name.isEmpty) name = email.split('@').first;
      // 去重
      final exists = ContactStore.cached.any((c) => c.email == email);
      if (exists) continue;
      ContactStore.add(name: name, email: email);
      count++;
    }
    return count;
  }

  /// 解析 CSV 内容，返回导入数量
  int _parseCsv(String content) {
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return 0;
    final separator = content.contains(';') && !content.contains(',')
        ? ';'
        : ',';
    // 解析表头，找 name 和 email 列
    final header = lines.first.split(separator).map((s) => s.trim().toLowerCase()).toList();
    int nameIdx = header.indexWhere((h) =>
        h.contains('name') || h.contains('姓名') || h.contains('display'));
    int emailIdx = header.indexWhere((h) =>
        h.contains('email') || h.contains('邮箱') || h.contains('mail'));

    int count = 0;
    // 如果有表头，从第二行开始；否则尝试每行解析
    final dataLines = (nameIdx >= 0 && emailIdx >= 0) ? lines.sublist(1) : lines;
    for (final line in dataLines) {
      String? name;
      String? email;
      if (nameIdx >= 0 && emailIdx >= 0) {
        final cols = line.split(separator);
        if (emailIdx < cols.length) email = cols[emailIdx].trim();
        if (nameIdx < cols.length) name = cols[nameIdx].trim();
      } else {
        // 无表头，尝试直接解析
        final parsed = _parseLine(line);
        if (parsed != null) {
          name = parsed.$1;
          email = parsed.$2;
        }
      }
      if (email == null || email.isEmpty) continue;
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) continue;
      if (name == null || name.isEmpty) name = email.split('@').first;
      final exists = ContactStore.cached.any((c) => c.email == email);
      if (exists) continue;
      ContactStore.add(name: name, email: email);
      count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索联系人...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                ),
                style: TextStyle(color: cs.onSurface),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('联系人'),
        actions: [
          // 快速导入菜单
          PopupMenuButton<String>(
            icon: const Icon(Icons.import_contacts_outlined),
            tooltip: '快速导入',
            onSelected: (value) {
              if (value == 'text') {
                _importFromText();
              } else if (value == 'file') {
                _importFromFile();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'text',
                child: Row(children: [
                  Icon(Icons.edit_note, size: 20),
                  SizedBox(width: 8),
                  Text('批量粘贴导入'),
                ]),
              ),
              const PopupMenuItem(
                value: 'file',
                child: Row(children: [
                  Icon(Icons.file_upload_outlined, size: 20),
                  SizedBox(width: 8),
                  Text('从文件导入 (vCard/CSV)'),
                ]),
              ),
            ],
          ),
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: _searching ? '取消搜索' : '搜索',
          ),
        ],
      ),
      body: _buildBody(cs, isDark),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactForm(),
        tooltip: '添加联系人',
        child: const Icon(Icons.add),
      ),
    );
  }

  // 构建主体内容
  Widget _buildBody(ColorScheme cs, bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final cached = ContactStore.cached;
    if (cached.isEmpty) {
      return _buildEmpty(cs, isDark);
    }

    // 搜索态：展示扁平搜索结果
    if (_searching && _query.isNotEmpty) {
      final results = ContactStore.search(_query);
      if (results.isEmpty) {
        return Center(
          child: Text(
            '没有匹配的联系人',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: results.length,
        itemBuilder: (ctx, i) => _ContactTile(
          contact: results[i],
          avatarColor: _avatarColor(results[i].email),
          onTap: () => _showContactDetail(results[i]),
        ),
      );
    }

    // 默认：按首字母分组展示
    final grouped = ContactStore.grouped();
    final keys = grouped.keys.toList(); // 已按首字母排序
    final totalItems = grouped.values.fold<int>(0, (s, l) => s + l.length) +
        keys.length; // 联系人 + 分组头

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: totalItems,
      itemBuilder: (ctx, index) {
        int cursor = 0;
        for (final key in keys) {
          final list = grouped[key]!;
          // 当前 index 命中分组头
          if (index == cursor) {
            return _SectionHeader(letter: key, cs: cs);
          }
          cursor++;
          final tileIndex = index - cursor;
          if (tileIndex < list.length) {
            final c = list[tileIndex];
            return _ContactTile(
              contact: c,
              avatarColor: _avatarColor(c.email),
              onTap: () => _showContactDetail(c),
            );
          }
          cursor += list.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  // 空状态
  Widget _buildEmpty(ColorScheme cs, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: cs.onSurfaceVariant.withOpacity(isDark ? 0.3 : 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有联系人，点右下角添加吧',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// 分组头（首字母）
class _SectionHeader extends StatelessWidget {
  final String letter;
  final ColorScheme cs;
  const _SectionHeader({required this.letter, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: cs.onPrimaryContainer,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 联系人列表项
class _ContactTile extends StatelessWidget {
  final Contact contact;
  final Color avatarColor;
  final VoidCallback onTap;
  const _ContactTile({
    required this.contact,
    required this.avatarColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial =
        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: avatarColor,
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        contact.name,
        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        contact.email,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// 详情页中的属性行
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: cs.onSurface, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
