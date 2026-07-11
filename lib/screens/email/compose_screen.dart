import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/email.dart';
import '../../services/api_service.dart';
import '../../utils/storage.dart';
import '../../utils/theme.dart';

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
          final exists =
              _accounts.any((a) => a.accountId == _selectedAccountId);
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '加载账户失败: ${response.message.isEmpty ? "服务器未返回数据" : response.message}'),
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
        const SnackBar(content: Text('收件人不能为空')),
      );
      return;
    }
    if (_subjectController.text.trim().isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('没有主题'),
          content: const Text('这封邮件没有主题，确定要发送吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('发送'),
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
            const SnackBar(content: Text('发送成功')),
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
    final cs = Theme.of(context).colorScheme;
    final title = widget.replyEmail != null
        ? '回复'
        : widget.forwardEmail != null
            ? '转发'
            : '写邮件';

    // 全屏写邮件：标准 AppBar + 无边框字段区 + 正文直接铺满
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        title: Text(title),
        centerTitle: false,
        actions: [
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _send,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: const Text('发送'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 邮件字段区（无边框，用细分割线分隔，标准全屏邮件布局）
          _buildFieldRow(
            label: '发件人',
            child: _loadingAccounts
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _accounts.isEmpty
                    ? Text('暂无可用账户',
                        style: TextStyle(color: cs.error, fontSize: 14))
                    : DropdownButton<int>(
                        value: _selectedAccountId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style:
                            TextStyle(color: cs.onSurface, fontSize: 15),
                        items: _accounts.map((acc) {
                          final color = AppTheme.accountColor(acc.email);
                          return DropdownMenuItem<int>(
                            value: acc.accountId,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    acc.name.isNotEmpty
                                        ? '${acc.name} <${acc.email}>'
                                        : acc.email,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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
          _buildDivider(),
          _buildFieldRow(
            label: '收件人',
            child: TextField(
              controller: _toController,
              decoration: InputDecoration(
                hintText: '邮箱地址，多个用逗号分隔',
                hintStyle:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(color: cs.onSurface, fontSize: 15),
              keyboardType: TextInputType.emailAddress,
            ),
          ),
          _buildDivider(),
          _buildFieldRow(
            label: '主题',
            child: TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                hintText: '邮件主题',
                hintStyle:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(color: cs.onSurface, fontSize: 15),
            ),
          ),
          _buildDivider(),
          // 附件列表（无边框）
          if (_attachments.isNotEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          // 正文区：直接铺满，无边框，左对齐
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlign: TextAlign.left,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: '开始写邮件...',
                hintStyle:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.5),
            ),
          ),
          // 底部工具栏
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined, size: 22),
                  color: cs.primary,
                  onPressed: _pickImage,
                  tooltip: '添加图片',
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded, size: 22),
                  color: cs.primary,
                  onPressed: _pickFile,
                  tooltip: '添加附件',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow({required String label, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 84),
      child: Container(
        height: 0.5,
        color: cs.outlineVariant,
      ),
    );
  }
}
