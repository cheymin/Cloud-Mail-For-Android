import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/email.dart';
import '../../services/api_service.dart';
import '../../utils/storage.dart';
import '../../utils/theme.dart';
import '../settings/settings_screen.dart';
import '../accounts/account_screen.dart';
import 'email_detail_screen.dart';
import 'compose_screen.dart';

class MailboxScreen extends StatefulWidget {
  final CloudMailApi api;

  const MailboxScreen({super.key, required this.api});

  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

enum MailFolder { inbox, sent, starred, trash }

class _MailboxScreenState extends State<MailboxScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  MailFolder _currentFolder = MailFolder.inbox;
  List<Email> _emails = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int? _lastEmailId;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _initData();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _initData() async {
    try {
      final accResp = await widget.api.getAccountList();
      if (accResp.isSuccess && accResp.data != null) {
        final accounts = accResp.data!;
        if (accounts.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('暂无邮箱账户，请先添加账户')),
            );
          }
        } else {
          final currentId = StorageService.currentAccountId;
          final exists = accounts.any((a) => a.accountId == currentId);
          if (!exists) {
            StorageService.currentAccountId = accounts.first.accountId;
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('加载账户失败: ${accResp.message.isEmpty ? "未知错误" : accResp.message}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载账户失败: ${ErrorMessages.fromException(e)}')),
        );
      }
    }
    _loadEmails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  int get _emailType {
    switch (_currentFolder) {
      case MailFolder.inbox:
        return 0;
      case MailFolder.sent:
        return 1;
      case MailFolder.starred:
        return 0;
      case MailFolder.trash:
        return 0;
    }
  }

  String get _folderTitle {
    switch (_currentFolder) {
      case MailFolder.inbox:
        return '收件箱';
      case MailFolder.sent:
        return '已发送';
      case MailFolder.starred:
        return '星标邮件';
      case MailFolder.trash:
        return '垃圾箱';
    }
  }

  String _formatTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0 && now.day == dt.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}天前';
      } else {
        return '${dt.month}/${dt.day}';
      }
    } catch (e) {
      return timeStr;
    }
  }

  String _getPreview(Email email) {
    final text = email.text.isNotEmpty
        ? email.text
        : email.content.replaceAll(RegExp(r'<[^>]*>'), '');
    return text.length > 80 ? '${text.substring(0, 80)}...' : text;
  }

  Future<void> _loadEmails() async {
    setState(() {
      _loading = true;
      _emails = [];
      _lastEmailId = null;
      _hasMore = true;
    });

    try {
      if (_currentFolder == MailFolder.starred) {
        final response = await widget.api.getStarList(size: 20);
        if (response.isSuccess && response.data != null) {
          setState(() {
            _emails = response.data!;
            _hasMore = response.data!.length >= 20;
            if (response.data!.isNotEmpty) {
              _lastEmailId = response.data!.last.emailId;
            }
          });
        }
      } else {
        final isDel = _currentFolder == MailFolder.trash ? 1 : null;
        final response = await widget.api.getEmailList(
          accountId: StorageService.currentAccountId,
          type: _emailType,
          size: 20,
          timeSort: 0,
          isDel: isDel,
        );
        if (response.isSuccess && response.data != null) {
          setState(() {
            _emails = response.data!.list;
            _hasMore = _emails.length >= 20;
            if (_emails.isNotEmpty) {
              _lastEmailId = _emails.last.emailId;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessages.fromException(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      if (_currentFolder == MailFolder.starred) {
        final response = await widget.api.getStarList(
          size: 20,
          emailId: _lastEmailId,
        );
        if (response.isSuccess && response.data != null) {
          setState(() {
            _emails.addAll(response.data!);
            _hasMore = response.data!.length >= 20;
            if (response.data!.isNotEmpty) {
              _lastEmailId = response.data!.last.emailId;
            }
          });
        }
      } else {
        final isDel = _currentFolder == MailFolder.trash ? 1 : null;
        final response = await widget.api.getEmailList(
          accountId: StorageService.currentAccountId,
          type: _emailType,
          size: 20,
          emailId: _lastEmailId,
          timeSort: 0,
          isDel: isDel,
        );
        if (response.isSuccess && response.data != null) {
          setState(() {
            _emails.addAll(response.data!.list);
            _hasMore = response.data!.list.length >= 20;
            if (response.data!.list.isNotEmpty) {
              _lastEmailId = response.data!.list.last.emailId;
            }
          });
        }
      }
    } catch (e) {
      // silently ignore
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    await _loadEmails();
  }

  void _openEmail(Email email) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => EmailDetailScreen(email: email, api: widget.api),
      ),
    );
    if (result == true) {
      _loadEmails();
    }
  }

  void _navigateTo(MailFolder folder) {
    setState(() {
      _currentFolder = folder;
    });
    Navigator.pop(context);
    _loadEmails();
  }

  void _openCompose() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ComposeScreen(api: widget.api),
      ),
    ).then((result) {
      if (result == true) {
        _loadEmails();
      }
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => SettingsScreen(api: widget.api),
      ),
    );
  }

  void _openAccounts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => AccountScreen(api: widget.api),
      ),
    ).then((_) {
      _loadEmails();
    });
  }

  Future<void> _toggleStar(Email email) async {
    try {
      final response = email.isStarred
          ? await widget.api.cancelStar(email.emailId)
          : await widget.api.addStar(email.emailId);
      if (response.isSuccess) {
        setState(() {
          final idx = _emails.indexWhere((e) => e.emailId == email.emailId);
          if (idx >= 0) {
            _emails[idx] = Email(
              emailId: email.emailId,
              sendEmail: email.sendEmail,
              sendName: email.sendName,
              subject: email.subject,
              toEmail: email.toEmail,
              toName: email.toName,
              createTime: email.createTime,
              type: email.type,
              content: email.content,
              text: email.text,
              isDel: email.isDel,
              isStar: email.isStarred ? 0 : 1,
              status: email.status,
              messageId: email.messageId,
              attList: email.attList,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessages.fromException(e))),
        );
      }
    }
  }

  Future<void> _deleteEmail(Email email) async {
    try {
      final response = await widget.api.deleteEmails(email.emailId.toString());
      if (response.isSuccess) {
        setState(() {
          _emails.removeWhere((e) => e.emailId == email.emailId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已移到垃圾箱')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessages.fromException(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: cs.surface,
      drawer: _buildDrawer(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(isDark),
            Expanded(
              child: _loading
                  ? _buildLoadingList()
                  : _emails.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: cs.primary,
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: _emails.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => const Divider(
                                height: 1, indent: 72, endIndent: 16),
                            itemBuilder: (ctx, i) {
                              if (i == _emails.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                );
                              }
                              return _buildEmailItem(_emails[i], isDark);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCompose,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    final cs = Theme.of(context).colorScheme;
    final email = StorageService.email ?? '';
    final accountColor = AppTheme.accountColor(email);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 大标题行：菜单 + 标题 + 账户色标
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu, size: 24),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              Expanded(
                child: Text(
                  _folderTitle,
                  style: Theme.of(context).appBarTheme.titleTextStyle,
                ),
              ),
              // 账户色标圆点
              if (email.isNotEmpty)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: accountColor,
                    shape: BoxShape.circle,
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.search, size: 22),
                onPressed: () {
                  setState(() => _searching = !_searching);
                  if (!_searching) {
                    _searchController.clear();
                    _loadEmails();
                  }
                },
              ),
            ],
          ),
          // 搜索框（可展开）
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _searching
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(height: 0, width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: TextField(
                controller: _searchController,
                autofocus: _searching,
                decoration: InputDecoration(
                  hintText: '搜索邮件...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searching = false);
                            _loadEmails();
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (_) {
                  setState(() => _searching = true);
                  _loadEmails();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    final cs = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final email = StorageService.email ?? '';
    final accountColor = AppTheme.accountColor(email);

    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          children: [
            // 账户头部（Mimestream 风格：大头像 + 邮箱 + 色标）
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: cs.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accountColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            email.isNotEmpty
                                ? email[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email.isNotEmpty
                                  ? email.split('@').first
                                  : '未登录',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant.withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(indent: 20, endIndent: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _buildSectionLabel('邮箱'),
                  _buildDrawerItem(
                    icon: Icons.inbox_outlined,
                    title: '收件箱',
                    folder: MailFolder.inbox,
                  ),
                  _buildDrawerItem(
                    icon: Icons.send_outlined,
                    title: '已发送',
                    folder: MailFolder.sent,
                  ),
                  _buildDrawerItem(
                    icon: Icons.star_border,
                    title: '星标邮件',
                    folder: MailFolder.starred,
                  ),
                  _buildDrawerItem(
                    icon: Icons.delete_outline,
                    title: '垃圾箱',
                    folder: MailFolder.trash,
                  ),
                  const Divider(indent: 20, endIndent: 20),
                  _buildSectionLabel('工具'),
                  _buildPlainItem(
                    icon: Icons.auto_awesome_outlined,
                    title: 'AI 助手',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/ai',
                          arguments: {'api': widget.api});
                    },
                  ),
                  _buildPlainItem(
                    icon: Icons.account_circle_outlined,
                    title: '邮箱账户',
                    onTap: _openAccounts,
                  ),
                  _buildPlainItem(
                    icon: Icons.settings_outlined,
                    title: '设置',
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),
            const Divider(indent: 20, endIndent: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: ListTile(
                leading: Icon(
                  isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  size: 22,
                ),
                title: const Text('深色模式'),
                trailing: Switch(
                  value: isDark,
                  onChanged: (val) {
                    themeProvider.setThemeMode(
                      val ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
                onTap: () {
                  themeProvider.setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant.withOpacity(0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required MailFolder folder,
  }) {
    final selected = _currentFolder == folder;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: selected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: selected ? cs.primary : cs.onSurfaceVariant,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? cs.primary : cs.onSurface,
          ),
        ),
        onTap: () => _navigateTo(folder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildPlainItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        leading: Icon(icon, color: cs.onSurfaceVariant, size: 22),
        title: Text(title),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildLoadingList() {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: 10,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 120,
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    IconData icon;
    String text;
    switch (_currentFolder) {
      case MailFolder.inbox:
        icon = Icons.inbox_outlined;
        text = '收件箱空空如也';
        break;
      case MailFolder.sent:
        icon = Icons.send_outlined;
        text = '还没有发送过邮件';
        break;
      case MailFolder.starred:
        icon = Icons.star_border;
        text = '还没有星标邮件';
        break;
      case MailFolder.trash:
        icon = Icons.delete_outline;
        text = '垃圾箱是空的';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: cs.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: cs.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          if (_currentFolder != MailFolder.trash)
            TextButton.icon(
              onPressed: _loadEmails,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmailItem(Email email, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    final senderName = email.isSent
        ? email.toName.isNotEmpty
            ? email.toName
            : email.toEmail.split('@').first
        : email.sendName.isNotEmpty
            ? email.sendName
            : email.sendEmail.split('@').first;

    final accountColor =
        AppTheme.accountColor(email.isSent ? email.toEmail : email.sendEmail);

    return Dismissible(
      key: ValueKey('email-${email.emailId}'),
      background: Container(
        color: cs.primary,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: Icon(
          email.isStarred ? Icons.star : Icons.star_border,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        color: cs.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _toggleStar(email);
          return false;
        } else {
          return true;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          _deleteEmail(email);
        }
      },
      child: InkWell(
        onTap: () => _openEmail(email),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头像 + 账户色标（Mimestream 风格）
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accountColor,
                    child: Text(
                      senderName.isNotEmpty
                          ? senderName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  // 未读小蓝点（用 isStar 占位示意，实际未读状态需 API）
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 发件人 + 时间
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            senderName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(email.createTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // 主题
                    Text(
                      email.subject,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // 预览
                    Text(
                      _getPreview(email),
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant.withOpacity(0.7),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 标记行：星标 + 附件
                    if (email.isStarred ||
                        (email.attList != null &&
                            email.attList!.isNotEmpty)) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (email.isStarred)
                            Icon(Icons.star, size: 14, color: Colors.amber[600]),
                          if (email.isStarred &&
                              email.attList != null &&
                              email.attList!.isNotEmpty)
                            const SizedBox(width: 6),
                          if (email.attList != null &&
                              email.attList!.isNotEmpty)
                            Icon(Icons.attach_file,
                                size: 14,
                                color: cs.onSurfaceVariant.withOpacity(0.5)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
