import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/storage.dart';
import 'email/mailbox_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pageController = PageController();
  final _urlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlFormKey = GlobalKey<FormState>();
  final _accountFormKey = GlobalKey<FormState>();

  int _currentStep = 0;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberLogin = true;

  @override
  void initState() {
    super.initState();
    if (StorageService.baseUrl != null && StorageService.baseUrl!.isNotEmpty) {
      _urlController.text = StorageService.baseUrl!;
      // 老用户直接跳到账户登录步骤
      _currentStep = 2;
    }
    if (StorageService.email != null) {
      _emailController.text = StorageService.email!;
    }
    _rememberLogin = StorageService.rememberLogin;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (ctx) => MailboxScreen(api: api),
            ),
          );
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 进度指示器
            if (_currentStep > 0 && _currentStep < 3) _buildProgress(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildWelcome(),
                  _buildServerSetup(),
                  _buildAccountLogin(),
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
        ],
      ),
    );
  }

  Widget _buildProgressDot(int step, ColorScheme cs) {
    final active = _currentStep >= step;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? cs.primary : cs.surfaceVariant,
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

  // ==================== 步骤 1: 欢迎页 ====================
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

  // ==================== 步骤 2: 服务器配置 ====================
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

  // ==================== 步骤 3: 账户登录 ====================
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
}
