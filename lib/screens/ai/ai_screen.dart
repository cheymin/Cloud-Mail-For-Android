import 'package:flutter/material.dart';
import '../../models/email.dart';
import '../../services/api_service.dart';
import '../../services/ai_service.dart';

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

  ChatConversation? _currentConversation;

  static const _welcomeMessage =
      '👋 你好！我是你的智能邮件助手。\n\n我可以帮你：\n• 分析邮件内容\n• 总结最近的邮件\n• 回复、转发、删除邮件\n• 标星重要邮件\n\n请输入你的问题或指令吧！';

  @override
  void initState() {
    super.initState();
    _loadEmails();
    _loadOrCreateConversation();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载最近的对话，没有则新建
  void _loadOrCreateConversation() {
    final conversations = AiService.loadAllConversations();
    if (conversations.isNotEmpty) {
      _currentConversation = conversations.first;
      _messages = List.from(_currentConversation!.messages);
      // 如果对话为空，加欢迎语
      if (_messages.isEmpty) {
        _messages.add({'role': 'assistant', 'content': _welcomeMessage});
      }
    } else {
      _startNewConversation();
    }
  }

  /// 开始新对话
  void _startNewConversation() {
    _currentConversation = ChatConversation.createNew();
    _messages = [
      {'role': 'assistant', 'content': _welcomeMessage}
    ];
    setState(() {});
  }

  /// 保存当前对话到本地
  void _saveCurrentConversation() {
    if (_currentConversation == null) return;

    // 过滤掉欢迎语，不保存
    final messagesToSave = _messages
        .where((m) => !(m['role'] == 'assistant' &&
            m['content']!.startsWith('👋')))
        .toList();

    if (messagesToSave.isEmpty) return;

    // 如果标题还是"新对话"，用第一条用户消息作为标题
    if (_currentConversation!.title == '新对话') {
      final firstUserMsg = messagesToSave.firstWhere(
        (m) => m['role'] == 'user',
        orElse: () => {'content': '新对话'},
      );
      String title = firstUserMsg['content'] ?? '新对话';
      if (title.length > 30) title = '${title.substring(0, 30)}...';
      _currentConversation!.title = title;
    }

    _currentConversation!.messages = messagesToSave;
    _currentConversation!.updatedAt = DateTime.now().millisecondsSinceEpoch;
    AiService.saveConversation(_currentConversation!);
  }

  Future<void> _loadEmails() async {
    setState(() => _loadingEmails = true);
    try {
      final response = await widget.api.getEmailList(
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
      // 保存对话到本地
      _saveCurrentConversation();
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

  /// 打开历史对话列表
  void _showHistory() {
    final conversations = AiService.loadAllConversations();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '历史对话',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          if (conversations.isNotEmpty)
                            TextButton.icon(
                              icon: const Icon(Icons.delete_sweep, size: 18),
                              label: const Text('清空'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: ctx,
                                  builder: (d) => AlertDialog(
                                    title: const Text('清空所有对话？'),
                                    content: const Text('确定要删除所有历史对话吗？此操作不可撤销。'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(d, false),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(d, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('清空'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  AiService.clearAllConversations();
                                  setSheetState(() => conversations.clear());
                                  if (mounted) {
                                    _startNewConversation();
                                  }
                                }
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: '新对话',
                            onPressed: () {
                              Navigator.pop(ctx);
                              _startNewConversation();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  if (conversations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          '还没有历史对话',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: conversations.length,
                        itemBuilder: (c, i) {
                          final conv = conversations[i];
                          final isSelected =
                              _currentConversation?.id == conv.id;
                          final dt = DateTime.fromMillisecondsSinceEpoch(
              conv.updatedAt);
                          final timeStr =
                              '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                          final msgCount =
                              conv.messages.where((m) => m['role'] == 'user').length;

                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF6C63FF)
                                    : const Color(0xFF6C63FF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF6C63FF),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              conv.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF6C63FF)
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              '$timeStr · $msgCount 条消息',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: Colors.grey),
                              onPressed: () {
                                AiService.deleteConversation(conv.id);
                                setSheetState(() {
                                  conversations.removeAt(i);
                                });
                                if (isSelected) {
                                  Navigator.pop(ctx);
                                  _loadOrCreateConversation();
                                  setState(() {});
                                }
                              },
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              _currentConversation = conv;
                              _messages = [
                                {'role': 'assistant', 'content': _welcomeMessage},
                                ...conv.messages,
                              ];
                              setState(() {});
                              _scrollToBottom();
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
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
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 邮件助手'),
            Text(
              '模型: ${_aiService.model}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '历史对话',
            onPressed: _showHistory,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: '新对话',
            onPressed: _startNewConversation,
          ),
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
