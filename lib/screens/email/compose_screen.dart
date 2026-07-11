import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/email.dart';
import '../../services/api_service.dart';
import '../../utils/storage.dart';

class ComposeScreen extends StatefulWidget {
  final CloudMailApi api;
  final Email? replyEmail;
  final Email? forwardEmail;

  const ComposeScreen({
    super.key,
    required this.api,
    this.replyEmail,
    this.forwardEmail,
  });

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  final _picker = ImagePicker();

  bool _sending = false;
  List<Map<String, dynamic>> _attachments = [];
  int? _selectedAccountId;
  List<Account> _accounts = [];
  bool _loadingAccounts = true;

  @override
  void initState() {
    super.initState();
    if (widget.replyEmail != null) {
      final reply = widget.replyEmail!;
      _toController.text = reply.isSent ? reply.toEmail : reply.sendEmail;
      _subjectController.text = reply.subject.startsWith('Re:')
          ? reply.subject
          : 'Re: ${reply.subject}';
      _contentController.text = '\n\n-------- 原始邮件 --------\n'
          '发件人: ${reply.sendName} <${reply.sendEmail}>\n'
          '时间: ${reply.createTime}\n'
          '主题: ${reply.subject}\n\n'
          '${reply.text}';
    } else if (widget.forwardEmail != null) {
      final fwd = widget.forwardEmail!;
      _subjectController.text = fwd.subject.startsWith('Fwd:')
          ? fwd.subject
          : 'Fwd: ${fwd.subject}';
      _contentController.text = '\n\n-------- 转发邮件 --------\n'
          '发件人: ${fwd.sendName} <${fwd.sendEmail}>\n'
          '时间: ${fwd.createTime}\n'
          '主题: ${fwd.subject}\n\n'
          '${fwd.text}';
    }
    _selectedAccountId = StorageService.currentAccountId;
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final response = await widget.api.getAccountList();
      if (response.isSuccess && response.data != null) {
        setState(() {
          _accounts = response.data!;
          // 检查当前选中的账户是否还在列表中
          final exists = _accounts.any((a) => a.accountId == _selectedAccountId);
          if (!exists || _selectedAccountId == null) {
            if (_accounts.isNotEmpty) {
              _selectedAccountId = _accounts.first.accountId;
              StorageService.currentAccountId = _selectedAccountId;
            } else {
              _selectedAccountId = null;
            }
          }
        });
      } else {
        // 显示具体错误，方便诊断
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('加载账户失败: ${response.message.isEmpty ? "服务器未返回数据" : response.message}'),
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
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final base64 = base64Encode(bytes);
      setState(() {
        _attachments.add({
          'filename': picked.name,
          'content': base64,
          'contentType': 'image/${picked.name.split('.').last}',
        });
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      final base64 = base64Encode(file.bytes!);
      setState(() {
        _attachments.add({
          'filename': file.name,
          'content': base64,
          'contentType': file.extension != null
              ? 'application/${file.extension}'
              : 'application/octet-stream',
        });
      });
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _send() async {
    if (_toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('收件人不能为空呀，不然发给谁呢~')),
      );
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('没有主题？'),
          content: const Text('这封邮件没有主题，确定要发送吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('再想想'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('就这么发'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择发件账户')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final toEmails = _toController.text
          .split(RegExp(r'[,;，；\s]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final text = _contentController.text;
      final content = '<div style="white-space: pre-wrap;">'
          '${text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')}'
          '</div>';

      final response = await widget.api.sendEmail(
        accountId: _selectedAccountId!,
        receiveEmail: toEmails,
        subject: _subjectController.text.trim(),
        content: content,
        text: text,
        sendType: widget.replyEmail != null ? 'reply' : 'new',
        emailId: widget.replyEmail?.emailId,
        attachments: _attachments,
      );

      if (response.isSuccess) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('发送成功！邮件已经飞走啦~ 🚀')),
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
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.replyEmail != null
            ? '回复邮件'
            : widget.forwardEmail != null
                ? '转发邮件'
                : '写邮件'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_sending)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _send,
              tooltip: '发送',
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 发件人选择
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('发件人', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _loadingAccounts
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : _accounts.isEmpty
                                  ? const Text('暂无可用账户', style: TextStyle(color: Colors.red))
                                  : DropdownButton<int>(
                                      value: _selectedAccountId,
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      items: _accounts.map((acc) {
                                        return DropdownMenuItem<int>(
                                          value: acc.accountId,
                                          child: Text(
                                            acc.name.isNotEmpty
                                                ? '${acc.name} <${acc.email}>'
                                                : acc.email,
                                            style: const TextStyle(fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedAccountId = val;
                                          if (val != null) {
                                            StorageService.currentAccountId = val;
                                          }
                                        });
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _toController,
                      decoration: const InputDecoration(
                        labelText: '收件人',
                        hintText: '输入邮箱地址，多个用逗号分隔',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: '主题',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_attachments.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < _attachments.length; i++)
                            Chip(
                              label: Text(
                                _attachments[i]['filename'],
                                style: const TextStyle(fontSize: 12),
                              ),
                              avatar: const Icon(Icons.attach_file, size: 16),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () => _removeAttachment(i),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      minLines: 15,
                      decoration: const InputDecoration(
                        hintText: '开始写邮件吧...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
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
                  IconButton(
                    icon: const Icon(Icons.image_outlined),
                    onPressed: _pickImage,
                    tooltip: '添加图片',
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _pickFile,
                    tooltip: '添加附件',
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(_sending ? '发送中...' : '发送'),
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
