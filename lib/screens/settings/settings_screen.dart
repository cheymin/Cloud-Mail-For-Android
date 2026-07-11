import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../utils/storage.dart';
import '../../utils/theme.dart';
import '../login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final CloudMailApi api;

  const SettingsScreen({super.key, required this.api});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showAvatar = true;
  bool _autoLoadImages = true;

  @override
  void initState() {
    super.initState();
    _showAvatar = StorageService.showSenderAvatar;
    _autoLoadImages = StorageService.autoLoadImages;
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('确定要退出当前账号吗？下次得重新登录哦~'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.logout();
    } catch (_) {}

    if (mounted) {
      StorageService.clear();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (ctx) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('外观'),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.dark_mode_outlined,
                  title: '深色模式',
                  subtitle: isDark ? '当前是深色模式' : '当前是浅色模式',
                  trailing: Switch(
                    value: isDark,
                    onChanged: (val) {
                      themeProvider.setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _buildTile(
                  icon: Icons.palette_outlined,
                  title: '主题模式',
                  subtitle: _themeModeText(themeProvider.themeMode),
                  onTap: () => _showThemeDialog(themeProvider),
                ),
                const Divider(height: 1, indent: 56),
                _buildTile(
                  icon: Icons.account_circle_outlined,
                  title: '显示发件人头像',
                  trailing: Switch(
                    value: _showAvatar,
                    onChanged: (val) {
                      setState(() => _showAvatar = val);
                      StorageService.showSenderAvatar = val;
                    },
                  ),
                ),
              ],
            ),
            ),
          const SizedBox(height: 24),
          _buildSectionTitle('邮件'),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.image_outlined,
                  title: '自动加载图片',
                  subtitle: '邮件中的图片是否自动显示',
                  trailing: Switch(
                    value: _autoLoadImages,
                    onChanged: (val) {
                      setState(() => _autoLoadImages = val);
                      StorageService.autoLoadImages = val;
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('账户'),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.email_outlined,
                  title: '当前登录',
                  subtitle: StorageService.email ?? '未知',
                ),
                const Divider(height: 1, indent: 56),
                _buildTile(
                  icon: Icons.language_outlined,
                  title: '服务器地址',
                  subtitle: StorageService.baseUrl ?? '未知',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('关于'),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.info_outline,
                  title: '版本',
                  subtitle: '2.0.0',
                ),
                const Divider(height: 1, indent: 56),
                _buildTile(
                  icon: Icons.favorite_outline,
                  title: '关于 Cloud Mail',
                  subtitle: '基于 Cloudflare 的简约邮箱服务',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56),
                _buildTile(
                  icon: Icons.code_outlined,
                  title: '开源项目',
                  subtitle: 'github.com/maillab/cloud-mail',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('退出登录'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 13))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  String _themeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  void _showThemeDialog(ThemeProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择主题'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              provider.setThemeMode(ThemeMode.system);
              Navigator.pop(ctx);
            },
            child: const Text('跟随系统'),
          ),
          SimpleDialogOption(
            onPressed: () {
              provider.setThemeMode(ThemeMode.light);
              Navigator.pop(ctx);
            },
            child: const Text('浅色模式'),
          ),
          SimpleDialogOption(
            onPressed: () {
              provider.setThemeMode(ThemeMode.dark);
              Navigator.pop(ctx);
            },
            child: const Text('深色模式'),
          ),
        ],
      ),
    );
  }
}
