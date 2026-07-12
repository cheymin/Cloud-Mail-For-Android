import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/storage.dart';
import '../utils/theme.dart';
import 'email/mailbox_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final PageController _pageController;
  final _urlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlFormKey = GlobalKey<FormState>();
  final _accountFormKey = GlobalKey<FormState>();

  // 个性化设置：OpenAI
  final _openaiUrlController = TextEditingController();
  final _openaiKeyController = TextEditingController();
  final _openaiModelController = TextEditingController();
  // 个性化设置：WebDAV
  final _webdavUrlController = TextEditingController();
  final _webdavUsernameController = TextEditingController();
  final _webdavPasswordController = TextEditingController();

  int _currentStep = 0;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberLogin = true;

  // 个性化设置状态
  UiStyle _uiStyle = UiStyle.google;
  bool _darkMode = false;
  bool _openaiExpanded = false;
  bool _webdavExpanded = false;
  bool _obscureOpenaiKey = true;
  bool _obscureWebdavPassword = true;

  // 登录成功后的 api 实例，完成动画后用于跳转主界面
  CloudMailApi? _loggedInApi;

  @override
  void initState() {
    super.initState();
    if (StorageService.baseUrl != null && StorageService.baseUrl!.isNotEmpty) {
      _urlController.text = StorageService.baseUrl!;
      // 老用户直接跳到账户登录步骤
      _currentStep = 2;
    }
    _pageController = PageController(initialPage: _currentStep);
    if (StorageService.email != null) {
      _emailController.text = StorageService.email!;
    }
    _rememberLogin = StorageService.rememberLogin;

    // 个性化默认值（从已存储的读取）
    _uiStyle = UiStyleX.fromString(StorageService.uiStyle);
    _darkMode = StorageService.themeMode == 'dark';
    _openaiUrlController.text = StorageService.openaiBaseUrl ?? '';
    _openaiKeyController.text = StorageService.openaiApiKey ?? '';
    _openaiModelController.text = StorageService.openaiModel ?? 'gpt-4o-mini';
    final webdavRaw = StorageService.webdavConfig;
    if (webdavRaw != null && webdavRaw.isNotEmpty) {
      try {
        final cfg = jsonDecode(webdavRaw) as Map<String, dynamic>;
        _webdavUrlController.text = cfg['url'] as String? ?? '';
        _webdavUsernameController.text = cfg['username'] as String? ?? '';
        _webdavPasswordController.text = cfg['password'] as String? ?? '';
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _openaiUrlController.dispose();
    _openaiKeyController.dispose();
    _openaiModelController.dispose();
    _webdavUrlController.dispose();
    _webdavUsernameController.dispose();
    _webdavPasswordController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    if (step <= 3) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _login() async {
    if (!_accountFormKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final baseUrl = _urlController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final api = CloudMailApi(baseUrl);
      final response = await api.login(email, password);

      if (response.isSuccess && response.data != null) {
        final token = response.data!;
        StorageService.token = token;
        StorageService.email = email;
        StorageService.baseUrl = baseUrl;
        StorageService.rememberLogin = _rememberLogin;

        api.token = token;

        // 加载账户列表，获取默认账户
        try {
          final accResp = await api.getAccountList();
          if (accResp.isSuccess &&
              accResp.data != null &&
              accResp.data!.isNotEmpty) {
            StorageService.currentAccountId = accResp.data!.first.accountId;
          }
        } catch (_) {}

        if (mounted) {
          // 保存 api 实例，进入个性化设置步骤
          _loggedInApi = api;
          _goToStep(3);
        }
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ==================== 个性化设置持久化 ====================
  void _applyPersonalization() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setUiStyle(_uiStyle);
    themeProvider.setThemeMode(_darkMode ? ThemeMode.dark : ThemeMode.light);

    // OpenAI
    final key = _openaiKeyController.text.trim();
    StorageService.openaiApiKey = key.isEmpty ? null : key;
    final oUrl = _openaiUrlController.text.trim();
    StorageService.openaiBaseUrl = oUrl.isEmpty ? null : oUrl;
    final model = _openaiModelController.text.trim();
    StorageService.openaiModel = model.isEmpty ? null : model;

    // WebDAV
    final wUrl = _webdavUrlController.text.trim();
    if (wUrl.isEmpty) {
      StorageService.webdavConfig = null;
    } else {
      final cfg = {
        'url': wUrl,
        'username': _webdavUsernameController.text.trim(),
        'password': _webdavPasswordController.text,
      };
      StorageService.webdavConfig = jsonEncode(cfg);
    }
  }

  void _savePersonalizationAndComplete() {
    _applyPersonalization();
    _goToStep(4);
  }

  void _skipPersonalization() {
    // 跳过不保存个性化，直接到完成页
    _goToStep(4);
  }

  void _onFireworksCompleted() {
    final api = _loggedInApi;
    if (api == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ctx) => MailboxScreen(api: api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 进度指示器：步骤 1-4 显示
            if (_currentStep > 0 && _currentStep < 5) _buildProgress(),
            Expanded(
              child: _currentStep == 4
                  ? FireworksWidget(onCompleted: _onFireworksCompleted)
                  : PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildWelcome(),
                        _buildServerSetup(),
                        _buildAccountLogin(),
                        _buildPersonalization(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildProgressDot(1, cs),
          Expanded(child: Divider(color: cs.outline)),
          _buildProgressDot(2, cs),
          Expanded(child: Divider(color: cs.outline)),
          _buildProgressDot(3, cs),
          Expanded(child: Divider(color: cs.outline)),
          _buildProgressDot(4, cs),
        ],
      ),
    );
  }

  Widget _buildProgressDot(int step, ColorScheme cs) {
    final active = _currentStep >= step;
    final current = _currentStep == step;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? cs.primary : cs.surfaceVariant,
        border: current ? Border.all(color: cs.primary, width: 2) : null,
      ),
      child: Center(
        child: active
            ? Icon(Icons.check, size: 16, color: cs.onPrimary)
            : Text(
                '$step',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  // ==================== 步骤 0: 欢迎页 ====================
  Widget _buildWelcome() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(),
          // 应用图标
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, cs.tertiary],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.mail_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Cloud Mail',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '你的私人邮箱\n干净、快速、完全可控',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const Spacer(),
          // 开始按钮
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => _goToStep(1),
              child: const Text(
                '开始使用',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 已有账户快速登录
          if (StorageService.baseUrl != null &&
              StorageService.baseUrl!.isNotEmpty)
            TextButton(
              onPressed: () => _goToStep(2),
              child: const Text('直接登录已有账户'),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ==================== 步骤 1: 服务器配置 ====================
  Widget _buildServerSetup() {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _urlFormKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text(
              '连接服务器',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '输入你的 Cloud Mail 服务器地址',
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'https://your-mail.example.com',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return '请输入服务器地址';
                }
                if (!v.trim().startsWith('http://') &&
                    !v.trim().startsWith('https://')) {
                  return '请以 http:// 或 https:// 开头';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  if (_urlFormKey.currentState!.validate()) {
                    _goToStep(2);
                  }
                },
                child: const Text('下一步'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => _goToStep(0),
                  child: const Text('返回'),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ==================== 步骤 2: 账户登录 ====================
  Widget _buildAccountLogin() {
    final cs = Theme.of(context).colorScheme;
    return Form(
      key: _accountFormKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Text(
              '登录账户',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '使用你的邮箱账户登录',
              style: TextStyle(
                fontSize: 15,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '邮箱地址',
                hintText: 'admin@example.com',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return '请输入邮箱地址';
                }
                if (!v.contains('@')) {
                  return '邮箱格式不正确';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: '密码',
                hintText: '输入你的密码',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return '密码不能为空';
                }
                return null;
              },
              onFieldSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 16),
            // 记住登录状态
            Row(
              children: [
                Switch(
                  value: _rememberLogin,
                  onChanged: (v) {
                    setState(() => _rememberLogin = v);
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  '记住登录状态',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('登录中...'),
                        ],
                      )
                    : const Text(
                        '登录',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => _goToStep(1),
                  child: const Text('返回'),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ==================== 步骤 3: 个性化设置 ====================
  Widget _buildPersonalization() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            '个性化设置',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '可随时跳过，稍后能在设置中修改',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '界面风格',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStyleCard(
                            UiStyle.google, 'Google', 'Material You', cs),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStyleCard(
                            UiStyle.apple, 'Apple', 'Mimestream', cs),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: SwitchListTile(
                      secondary: Icon(Icons.dark_mode_outlined, color: cs.primary),
                      title: const Text('深色模式'),
                      subtitle: const Text('使用深色主题'),
                      value: _darkMode,
                      onChanged: (v) => setState(() => _darkMode = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildOpenAICard(cs),
                  const SizedBox(height: 12),
                  _buildWebDAVCard(cs),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _savePersonalizationAndComplete,
              child: const Text(
                '完成',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: _skipPersonalization,
              child: const Text('跳过'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildStyleCard(
      UiStyle style, String title, String subtitle, ColorScheme cs) {
    final selected = _uiStyle == style;
    return GestureDetector(
      onTap: () => setState(() => _uiStyle = style),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              style == UiStyle.google
                  ? Icons.phone_android
                  : Icons.phone_iphone,
              size: 32,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? cs.onPrimaryContainer : cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenAICard(ColorScheme cs) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.auto_awesome_rounded, color: cs.primary),
            title: const Text('OpenAI API 设置'),
            subtitle: const Text('AI 智能助手（可跳过）'),
            trailing: Icon(_openaiExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _openaiExpanded = !_openaiExpanded),
          ),
          if (_openaiExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _openaiUrlController,
                    decoration: const InputDecoration(
                      labelText: 'API 地址',
                      hintText: 'https://api.openai.com/v1',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _openaiKeyController,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureOpenaiKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(
                            () => _obscureOpenaiKey = !_obscureOpenaiKey),
                      ),
                    ),
                    obscureText: _obscureOpenaiKey,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _openaiModelController,
                    decoration: const InputDecoration(
                      labelText: '模型名',
                      hintText: 'gpt-4o-mini',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebDAVCard(ColorScheme cs) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.cloud_sync_rounded, color: cs.primary),
            title: const Text('WebDAV 同步设置'),
            subtitle: const Text('跨设备同步配置（可跳过）'),
            trailing: Icon(_webdavExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _webdavExpanded = !_webdavExpanded),
          ),
          if (_webdavExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _webdavUrlController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'https://dav.example.com',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _webdavUsernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _webdavPasswordController,
                    decoration: InputDecoration(
                      labelText: '密码',
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureWebdavPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () => setState(() =>
                            _obscureWebdavPassword = !_obscureWebdavPassword),
                      ),
                    ),
                    obscureText: _obscureWebdavPassword,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== 步骤 4: 烟花动画完成页 ====================
class FireworksWidget extends StatefulWidget {
  final VoidCallback onCompleted;
  const FireworksWidget({super.key, required this.onCompleted});

  @override
  State<FireworksWidget> createState() => _FireworksWidgetState();
}

class _FireworksWidgetState extends State<FireworksWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  static const _colors = [
    Color(0xFFEA4335),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF1A73E8),
    Color(0xFF5856D6),
    Color(0xFFAF52DE),
    Color(0xFFFF2D55),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _particles = _generateParticles();
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onCompleted();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Particle> _generateParticles() {
    final rand = math.Random();
    final List<_Particle> particles = [];
    // 三波烟花，从中心附近不同位置、不同时间绽放
    final bursts = [
      [0.0, -20.0, 0.0],
      [-70.0, 40.0, 0.3],
      [70.0, 40.0, 0.55],
    ];
    for (final b in bursts) {
      final cx = b[0], cy = b[1], delay = b[2];
      const count = 42;
      for (int i = 0; i < count; i++) {
        final angle = (i / count) * 2 * math.pi + rand.nextDouble() * 0.4;
        final speed = 90.0 + rand.nextDouble() * 110.0;
        particles.add(_Particle(
          cx: cx,
          cy: cy,
          angle: angle,
          speed: speed,
          color: _colors[rand.nextInt(_colors.length)],
          size: 2.5 + rand.nextDouble() * 3.0,
          delay: delay,
        ));
      }
    }
    return particles;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FireworksPainter(_particles, _controller.value),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withOpacity(0.35),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 56),
                ),
                const SizedBox(height: 24),
                Text(
                  '设置完成！',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '即将进入邮箱',
                  style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Particle {
  final double cx;
  final double cy;
  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double delay;

  _Particle({
    required this.cx,
    required this.cy,
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.delay,
  });
}

class _FireworksPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _FireworksPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const gravity = 130.0;

    for (final p in particles) {
      final span = 1.0 - p.delay;
      if (span <= 0) continue;
      final localT = (progress - p.delay) / span;
      if (localT <= 0 || localT > 1) continue;

      final distance = p.speed * localT;
      final dx = math.cos(p.angle) * distance;
      final dy = math.sin(p.angle) * distance + 0.5 * gravity * localT * localT;
      final pos = Offset(centerX + p.cx + dx, centerY + p.cy + dy);

      final opacity = (1 - localT).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withOpacity(opacity * 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, p.size * (1 - localT * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
