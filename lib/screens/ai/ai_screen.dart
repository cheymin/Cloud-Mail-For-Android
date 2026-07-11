import 'package:flutter/material.dart';
import '../../models/email.dart';
import '../../services/api_service.dart';
import '../../services/ai_service.dart';
import '../../utils/storage.dart';

class AiScreen extends StatefulWidget {
  final CloudMailApi api;

  const AiScreen({super.key, required this.api});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiService _aiService = AiService();

  List<Map<String, String>> _messages = [];
  bool _loading = false;
  List<Email> _emails = [];
  bool _loadingEmails = false;

  @override
  void initState() {
    super.initState();
    _loadEmails();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add({
      'role': 'assistant',
      'content': '👋 你好！我是你的智能邮件助手。\n\n我可以帮你：\n• 分析邮件内容\n• 总结最近的邮件\n• 回复、转发、删除邮件\n• 标星重要邮件\n\n请输入你的问题或指令吧！',
    });
  }

  Future<void> _loadEmails() async {
    setState(() => _loadingEmails = true);
    try {
      final response = await widget.api.getEmailList(
        accountId: StorageService.currentAccountId,
        type: 0,
        size: 10,
      );
      if (response.isSuccess && response.data != null) {
        setState(() => _emails = response.data!.list);
      }
    } catch (_) {}
    setState(() => _loadingEmails = false);
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _inputController.clear();
      _loading = true;
    });
    _scrollToBottom();

    try {
      if (!_aiService.isConfigured) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': '⚠️ 请先在设置中配置 OpenAI API Key 和 API 地址',
          });
        });
        return;
      }

      if (_emails.isEmpty) {
        await _loadEmails();
      }

      final response = await _aiService.chatWithMailbox(
        _emails,
        text,
        api: widget.api,
      );

      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '❌ 出错了: ${e.toString()}',
        });
      });
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    final isAssistant = message['role'] == 'assistant';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAssistant)
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF6C63FF),
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
              child: const Icon(Icons.bot, color: Colors.white, size: 20),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF6C63FF)
                    : Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.only(
                  topLeft: isUser ? const Radius.circular(12) : const Radius.circular(0),
                  topRight: const Radius.circular(12),
                  bottomLeft: const Radius.circular(12),
                  bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(12),
                ),
              ),
              child: Text(
                message['content'] ?? '',
                style: TextStyle(
                  color: isUser ? Colors.white : null,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI 邮件助手'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_loadingEmails)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadEmails,
              tooltip: '刷新邮件',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _buildMessage(_messages[i]),
            ),
          ),
          if (!_aiService.isConfigured)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.amber.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_outlined, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '未配置 OpenAI API，请在设置中配置',
                      style: TextStyle(color: Colors.amber[700]),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                    child: const Text('去配置'),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: '输入你的指令...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _loading
                      ? const SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
                            borderRadius: BorderRadius.all(Radius.circular(22)),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _sendMessage,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}