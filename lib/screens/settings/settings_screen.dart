import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/ai_service.dart';
import '../../services/update_service.dart';
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
  bool _checkingUpdate = false;
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  List<String> _models = [];
  String? _selectedModel;
  bool _loadingModels = false;

  @override
  void initState() {
    super.initState();
    _showAvatar = StorageService.showSenderAvatar;
    _autoLoadImages = StorageService.autoLoadImages;
    _apiKeyController.text = StorageService.openaiApiKey ?? '';
    _baseUrlController.text = StorageService.openaiBaseUrl ?? '';
    _selectedModel = StorageService.openaiModel;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    // 先保存当前配置，再用最新配置请求
    StorageService.openaiApiKey = _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim();
    StorageService.openaiBaseUrl = _baseUrlController.text.trim().isEmpty ? null : _baseUrlController.text.trim();

    setState(() => _loadingModels = true);
    try {
      final service = AiService();
      final models = await service.fetchModels();
      setState(() {
        _models = models;
        // 如果当前选中的模型不在列表里，清空选择
        if (_selectedModel != null && !models.contains(_selectedModel)) {
          _selectedModel = null;
        }
      });
      if (models.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('上游没有返回可用模型')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取模型失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  void _showModelPicker() async {
    if (_models.isEmpty) {
      await _fetchModels();
    }
    if (!mounted || _models.isEmpty) return;

    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择模型'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _models.length,
            itemBuilder: (c, i) {
              final m = _models[i];
              return ListTile(
                title: Text(m),
                trailing: _selectedModel == m
                    ? const Icon(Icons.check, color: Color(0xFF6C63FF))
                    : null,
                onTap: () => Navigator.pop(ctx, m),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (picked != null) {
      setState(() => _selectedModel = picked);
      StorageService.openaiModel = picked;
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      final updateInfo = await UpdateService.checkUpdate('2.3.2');
      setState(() => _checkingUpdate = false);

      if (updateInfo?.hasUpdate == true) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('发现新版本 v${updateInfo!.version}'),
            content: Text(updateInfo.releaseNotes.isNotEmpty
                ? updateInfo.releaseNotes
                : '有新版本可用，建议更新'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('稍后'),
              ),
              if (updateInfo.downloadUrl != null)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (await canLaunchUrl(Uri.parse(updateInfo.downloadUrl!))) {
                      await launchUrl(Uri.parse(updateInfo.downloadUrl!));
                    }
                  },
                  child: const Text('立即下载'),
                ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本 ✨')),
        );
      }
    } catch (e) {
      setState(() => _checkingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('检查更新失败: ${e.toString()}')),
      );
    }
  }

  void _saveOpenAIConfig() {
    StorageService.openaiApiKey = _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim();
    StorageService.openaiBaseUrl = _baseUrlController.text.trim().isEmpty ? null : _baseUrlController.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OpenAI 配置已保存')),
    );
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
          _buildSectionTitle('更新'),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTile(
                  icon: Icons.update_outlined,
                  title: '检查更新',
                  subtitle: '当前版本: 2.3.2',
                  onTap: _checkingUpdate ? null : _checkUpdate,
                  trailing: _checkingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('AI 助手'),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('OpenAI API Key', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _apiKeyController,
                        decoration: InputDecoration(
                          hintText: 'sk-xxxxxxxxxxxxxxxxxx',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        obscureText: true,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('API 地址', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _baseUrlController,
                        decoration: InputDecoration(
                          hintText: 'https://api.openai.com/v1',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _saveOpenAIConfig,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                          child: const Text('保存配置'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _loadingModels ? null : _fetchModels,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        icon: _loadingModels
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_download_outlined),
                        label: const Text('拉取模型'),
                      ),
                    ],
                  ),
                ),
                // 模型选择
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: InkWell(
                    onTap: _showModelPicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.model_training_outlined, size: 20),
                          const SizedBox(width: 12),
                          const Text('模型', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedModel ?? '点击选择模型',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedModel == null ? Colors.grey : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
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
                  subtitle: '2.3.1',
                ),
                const Divider(height: 1, indent: 56),
                _buildTile(
                  icon: Icons.cleaning_services_outlined,
                  title: '清空 AI 对话历史',
                  subtitle: '删除所有 AI 助手的对话记录',
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('清空对话历史？'),
                        content: const Text('确定要删除所有 AI 对话记录吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      AiService.clearAllConversations();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('AI 对话历史已清空')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                _buildTile(
                  icon: Icons.code_outlined,
                  title: '项目地址',
                  subtitle: 'github.com/cheymin/vpn',
                  onTap: () async {
                    const url = 'https://github.com/cheymin/vpn';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url));
                    }
                  },
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
      trailing: trailing ??
          (onTap != null ? const Icon(Icons.chevron_right, size: 20) : null),
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
