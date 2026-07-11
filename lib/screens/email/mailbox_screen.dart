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
    // 确保账户列表已加载，currentAccountId 有值
    try {
      final accResp = await widget.api.getAccountList();
      if (accResp.isSuccess && accResp.data != null) {
        final accounts = accResp.data!;
        final currentId = StorageService.currentAccountId;
        final exists = accounts.any((a) => a.accountId == currentId);
        if (!exists && accounts.isNotEmpty) {
          StorageService.currentAccountId = accounts.first.accountId;
        }
      }
    } catch (_) {}
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

  MailFolder get currentFolder => _currentFolder;

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

  Color _avatarColor(String name) {
    final hash = name.hashCode;
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFFFF6584),
      const Color(0xFF00D4AA),
      const Color(0xFFFFB800),
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
    ];
    return colors[hash.abs() % colors.length];
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
        final isDel = _currentFolder == MailFolder.trash ? 2 : null;
        final response = await widget.api.getEmailList(
          accountId: StorageService.currentAccountId,
          type: _emailType,
          size: 20,
          timeSort: 0,
          isDel: isDel,
          subject:
              _searching && _searchController.text.isNotEmpty
                  ? '%${_searchController.text}%'
                  : null,
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
        final isDel = _currentFolder == MailFolder.trash ? 2 : null;
        final response = await widget.api.getEmailList(
          accountId: StorageService.currentAccountId,
          type: _emailType,
          size: 20,
          emailId: _lastEmailId,
          timeSort: 0,
          isDel: isDel,
          subject:
              _searching && _searchController.text.isNotEmpty
                  ? '%${_searchController.text}%'
                  : null,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _emails.length + (_loadingMore ? 1 : 0),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCompose,
        icon: const Icon(Icons.edit),
        label: const Text('写邮件'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 44,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索邮件...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searching
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searching = false);
                            _loadEmails();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) {
                  setState(() => _searching = true);
                  _loadEmails();
                },
                onChanged: (val) {
                  if (val.isEmpty && _searching) {
                    setState(() => _searching = false);
                    _loadEmails();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mail_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud Mail',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
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
                  const Divider(height: 24),
                  ListTile(
                    leading: const Icon(Icons.bot_outlined),
                    title: const Text('AI 助手'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/ai', arguments: {'api': widget.api});
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_circle_outlined),
                    title: const Text('邮箱账户'),
                    onTap: _openAccounts,
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('设置'),
                    onTap: _openSettings,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
              ),
              title: Text(isDark ? '深色模式' : '浅色模式'),
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
          ],
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
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? AppTheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? AppTheme.primary : null,
        ),
      ),
      selected: selected,
      onTap: () => _navigateTo(folder),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 8,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String emoji;
    String text;
    switch (_currentFolder) {
      case MailFolder.inbox:
        emoji = '📭';
        text = '收件箱空空如也\n邮件们还在路上呢~';
        break;
      case MailFolder.sent:
        emoji = '✉️';
        text = '还没有发送过邮件\n点右下角写一封吧~';
        break;
      case MailFolder.starred:
        emoji = '⭐';
        text = '还没有星标邮件\n看到重要的邮件点个星星吧';
        break;
      case MailFolder.trash:
        emoji = '🗑️';
        text = '垃圾箱是空的\n保持得不错！';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 24),
          if (_currentFolder != MailFolder.trash)
            FilledButton(
              onPressed: _loadEmails,
              child: const Text('刷新一下'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmailItem(Email email, bool isDark) {
    final senderName = email.isSent
        ? email.toName.isNotEmpty
            ? email.toName
            : email.toEmail.split('@').first
        : email.sendName.isNotEmpty
            ? email.sendName
            : email.sendEmail.split('@').first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openEmail(email),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _avatarColor(senderName),
                  child: Text(
                    senderName.isNotEmpty
                        ? senderName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              senderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(email.createTime),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email.subject,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _getPreview(email),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: email.isSent
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              email.isSent ? '已发' : '收件',
                              style: TextStyle(
                                fontSize: 10,
                                color: email.isSent
                                    ? Colors.blue
                                    : Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (email.isStarred) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.star,
                                size: 14, color: Colors.amber),
                          ],
                          if (email.attList != null &&
                              email.attList!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.attach_file,
                                size: 14, color: Colors.grey),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
