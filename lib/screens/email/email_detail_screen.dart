import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/email.dart';
import '../../services/api_service.dart';
import '../../utils/storage.dart';
import '../../utils/theme.dart';

class EmailDetailScreen extends StatefulWidget {
  final Email email;
  final CloudMailApi api;

  const EmailDetailScreen({
    super.key,
    required this.email,
    required this.api,
  });

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  late Email _email;
  bool _isStarred = false;
  bool _loading = false;

  double _contentScale = 1.0;
  late final TransformationController _transformController;
  static const double _minScale = 0.3;
  static const double _maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    _email = widget.email;
    _isStarred = _email.isStarred;
    _transformController = TransformationController();
    _markAsRead();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    if (_email.isRead) return;
    try {
      await widget.api.markAsRead([_email.emailId]);
    } catch (_) {}
  }

  void _zoomBy(double factor) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(_minScale, _maxScale);
    if (newScale == currentScale) return;
    setState(() => _contentScale = newScale);
    _transformController.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
  }

  void _zoomReset() {
    setState(() => _contentScale = 1.0);
    _transformController.value = Matrix4.identity();
  }

  Future<void> _copyEmailContent() async {
    final plain = _email.text.isNotEmpty
        ? _email.text
        : _email.content.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final header = '主题: ${_email.subject}\n'
        '发件人: ${_email.sendName} <${_email.sendEmail}>\n'
        '收件人: ${_email.toName} <${_email.toEmail}>\n'
        '时间: ${_email.createTime}\n\n';
    await Clipboard.setData(ClipboardData(text: '$header$plain'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('邮件内容已复制')),
      );
    }
  }

  String _formatFullTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (e) {
      return timeStr;
    }
  }

  Future<void> _toggleStar() async {
    setState(() => _loading = true);
    try {
      final response = _isStarred
          ? await widget.api.cancelStar(_email.emailId)
          : await widget.api.addStar(_email.emailId);
      if (response.isSuccess) {
        setState(() => _isStarred = !_isStarred);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('星标操作失败: ${response.message}')),
          );
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

  Future<void> _deleteEmail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除邮件'),
        content: const Text('确定要删除这封邮件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await widget.api.deleteEmails(_email.emailId.toString());
      if (response.isSuccess) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已移到垃圾箱')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: ${response.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorMessages.fromException(e))),
        );
      }
    }
  }

  void _reply() {
    Navigator.pushNamed(
      context,
      '/compose',
      arguments: {
        'api': widget.api,
        'replyEmail': _email,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGoogle = themeProvider.isGoogle;
    final senderName = _email.isSent ? _email.toName : _email.sendName;
    final senderEmail = _email.isSent ? _email.toEmail : _email.sendEmail;
    final displayName =
        senderName.isNotEmpty ? senderName : senderEmail.split('@').first;
    final accountColor = AppTheme.accountColor(senderEmail);

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ===== 固定顶部操作栏 =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      _folderLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                      color: _isStarred ? cs.tertiary : null,
                      size: 24,
                    ),
                    onPressed: _loading ? null : _toggleStar,
                    tooltip: _isStarred ? '取消星标' : '星标',
                  ),
                  IconButton(
                    icon: const Icon(Icons.reply_rounded, size: 22),
                    onPressed: _reply,
                    tooltip: '回复',
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'delete':
                          _deleteEmail();
                          break;
                        case 'copy':
                          _copyEmailContent();
                          break;
                        case 'zoom_in':
                          _zoomBy(1.25);
                          break;
                        case 'zoom_out':
                          _zoomBy(1 / 1.25);
                          break;
                        case 'zoom_reset':
                          _zoomReset();
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(children: [
                          Icon(Icons.copy_all_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('复制邮件内容'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'zoom_in',
                        child: Row(children: [
                          Icon(Icons.zoom_in_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('放大'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'zoom_out',
                        child: Row(children: [
                          Icon(Icons.zoom_out_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('缩小'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'zoom_reset',
                        child: Row(children: [
                          Icon(Icons.restart_alt_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('恢复默认大小'),
                        ]),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 20),
                          SizedBox(width: 8),
                          Text('删除'),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ===== InteractiveViewer 包裹整个内容（邮件头部 + 邮件正文，一起缩放）=====
            Expanded(
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: _minScale,
                maxScale: _maxScale,
                panEnabled: true,
                scaleEnabled: true,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                alignment: Alignment.topCenter,
                onInteractionEnd: (details) {
                  final scale =
                      _transformController.value.getMaxScaleOnAxis();
                  if ((scale - _contentScale).abs() > 0.01) {
                    setState(() => _contentScale = scale);
                  }
                },
                child: SingleChildScrollView(
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    color: cs.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEmailHeader(
                          cs: cs,
                          isGoogle: isGoogle,
                          isDark: isDark,
                          senderEmail: senderEmail,
                          displayName: displayName,
                          accountColor: accountColor,
                        ),
                        Container(
                          height: 0.5,
                          color: cs.outlineVariant,
                        ),
                        _buildEmailBody(isDark),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ===== 底部缩放指示器 =====
            if (_contentScale != 1.0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.5),
                  border: Border(
                    top: BorderSide(color: cs.outlineVariant, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(_contentScale * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _zoomReset,
                      child: Text(
                        '重置',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _folderLabel {
    if (_email.isSent) return '已发送';
    return '邮件详情';
  }

  Widget _buildAttachmentsMini(bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.attach_file, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_email.attList!.length} 个附件',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: cs.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailHeader({
    required ColorScheme cs,
    required bool isGoogle,
    required bool isDark,
    required String senderEmail,
    required String displayName,
    required Color accountColor,
  }) {
    final recipientName = _email.toName;
    final recipientEmail = _email.toEmail;
    final recipientDisplay = recipientName.isNotEmpty
        ? (recipientEmail.isNotEmpty
            ? '$recipientName <$recipientEmail>'
            : recipientName)
        : (recipientEmail.isNotEmpty ? recipientEmail : '（无）');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _email.subject,
            style: TextStyle(
              fontSize: isGoogle ? 20 : 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isGoogle
                  ? Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accountColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    )
                  : CircleAvatar(
                      radius: 20,
                      backgroundColor: accountColor,
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      senderEmail,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFullTime(_email.createTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '收件人: $recipientDisplay',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_email.attList != null && _email.attList!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildAttachmentsMini(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailBody(bool isDark) {
    final cs = Theme.of(context).colorScheme;
    final content = _email.content;
    final hasHtml = content.contains('<') && content.contains('>');

    if (!hasHtml && content.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.drafts_outlined,
                size: 48, color: cs.onSurfaceVariant.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              '这封邮件是空的',
              style: TextStyle(
                color: cs.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: hasHtml
          ? SelectionArea(
              child: HtmlWidget(
                content,
                onTapUrl: (url) async {
                  final uri = Uri.parse(url);
                  try {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  } catch (_) {}
                  return true;
                },
                textStyle: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: cs.onSurface,
                ),
              ),
            )
          : SelectableText(
              content,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: cs.onSurface,
              ),
            ),
    );
  }
}
