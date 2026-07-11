import 'package:flutter/material.dart';
import '../../models/email.dart';
import '../../services/api_service.dart';
import '../../utils/storage.dart';

class AccountScreen extends StatefulWidget {
  final CloudMailApi api;

  const AccountScreen({super.key, required this.api});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<Account> _accounts = [];
  bool _loading = true;
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = StorageService.currentAccountId;
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final response = await widget.api.getAccountList();
      if (response.isSuccess && response.data != null) {
        setState(() {
          _accounts = response.data!;
          if (_selectedId == null && _accounts.isNotEmpty) {
            _selectedId = _accounts.first.accountId;
            StorageService.currentAccountId = _selectedId;
          }
        });
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

  Future<void> _addAccount() async {
    final emailController = TextEditingController();
    final pwdController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加邮箱账户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: '邮箱地址',
                hintText: 'example@yourdomain.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdController,
              decoration: const InputDecoration(
                labelText: '密码（选填）',
                hintText: '不填则自动生成',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (emailController.text.trim().isEmpty) return;

    try {
      final response = await widget.api.addAccount(
        emailController.text.trim(),
        password: pwdController.text.isNotEmpty ? pwdController.text : null,
      );
      if (response.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('账户添加成功！🎉')),
          );
          _loadAccounts();
        }
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessages.fromException(e))),
        );
      }
    }
  }

  Future<void> _selectAccount(Account account) async {
    setState(() => _selectedId = account.accountId);
    StorageService.currentAccountId = account.accountId;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已切换到 ${account.email}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('邮箱账户'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addAccount,
            tooltip: '添加账户',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _accounts.length,
                  itemBuilder: (ctx, i) {
                    final acc = _accounts[i];
                    final selected = _selectedId == acc.accountId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: selected
                              ? Border.all(
                                  color: const Color(0xFF6C63FF),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFF6C63FF).withOpacity(0.1),
                            child: const Icon(
                              Icons.email,
                              color: Color(0xFF6C63FF),
                            ),
                          ),
                          title: Text(
                            acc.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            acc.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF6C63FF),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () => _selectAccount(acc),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📭', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            '还没有邮箱账户',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '点右上角 + 号添加一个吧',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _addAccount,
            icon: const Icon(Icons.add),
            label: const Text('添加账户'),
          ),
        ],
      ),
    );
  }
}
