import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/email.dart';
import '../../services/api_service.dart';
import '../../utils/storage.dart';

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

  @override
  void initState() {
    super.initState();
    _email = widget.email;
    _isStarred = _email.isStarred;
  }

  String _formatTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0 && now.day == dt.day) {
        return DateFormat('HH:mm').format(dt);
      } else if (diff.inDays < 7) {
        return '${diff.inDays}天前';
      } else {
        return DateFormat('MM-dd HH:mm').format(dt);
      }
    } catch (e) {
      return timeStr;
    }
  }

  Color _avatarColor(String name) {
    final hash = name.hashCode;
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFFFF6584),
      const Color(0xFF00D4AA),
      const Color(0xFFFFB800),
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
    ];
    return colors[hash.abs() % colors.length];
  }

  Future<void> _toggleStar() async {
    setState(() => _loading = true);
    try {
      if (_isStarred) {
        await widget.api.cancelStar(_email.emailId);
      } else {
        await widget.api.addStar(_email.emailId);
      }
      setState(() => _isStarred = !_isStarred);
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
      await widget.api.deleteEmails(_email.emailId.toString());
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('邮件已删除，回收站见~')),
        );
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
    final senderName =
        _email.isSent ? _email.toName : _email.sendName;
    final senderEmail =
        _email.isSent ? _email.toEmail : _email.sendEmail;
    final displayName = senderName.isNotEmpty ? senderName : senderEmail.split('@').first;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 80,
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _isStarred ? Icons.star : Icons.star_border,
                  color: _isStarred ? Colors.amber : null,
                ),
                onPressed: _loading ? null : _toggleStar,
              ),
              IconButton(
                icon: const Icon(Icons.reply),
                onPressed: _reply,
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _deleteEmail();
                },
                itemBuilder: (ctx) => [
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _email.subject,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: _avatarColor(displayName),
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _formatTime(_email.createTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_email.isSent ? '发给 ' : '来自 '}$senderEmail',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _email.isSent
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _email.isSent ? '已发送' : '收件箱',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _email.isSent
                                      ? Colors.blue
                                      : Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  if (_email.attList != null && _email.attList!.isNotEmpty) ...[
                    _buildAttachments(isDark),
                    const SizedBox(height: 16),
                  ],
                  _buildEmailContent(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              onPressed: _reply,
              icon: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.reply),
                  SizedBox(height: 2),
                  Text('回复', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pushNamed(
                context,
                '/compose',
                arguments: {
                  'api': widget.api,
                  'forwardEmail': _email,
                },
              ),
              icon: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forward),
                  SizedBox(height: 2),
                  Text('转发', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _toggleStar,
              icon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isStarred ? Icons.star : Icons.star_border,
                    color: _isStarred ? Colors.amber : null,
                  ),
                  const SizedBox(height: 2),
                  Text(_isStarred ? '已星标' : '星标',
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              onPressed: _deleteEmail,
              icon: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline),
                  SizedBox(height: 2),
                  Text('删除', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 18),
              const SizedBox(width: 8),
              Text(
                '${_email.attList!.length} 个附件',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._email.attList!.map((att) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _getIconForFile(att.fileName),
                      size: 20,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            att.fileName,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatFileSize(att.fileSize),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download, size: 20),
                      onPressed: () async {
                        if (att.url != null && att.url!.isNotEmpty) {
                          if (await canLaunchUrl(Uri.parse(att.url!))) {
                            await launchUrl(Uri.parse(att.url!));
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('附件地址暂不可用')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEmailContent(bool isDark) {
    final content = _email.content;
    final hasHtml = content.contains('<') && content.contains('>');

    if (!hasHtml && content.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.drafts, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('这封邮件是空的', style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    if (hasHtml) {
      return HtmlWidget(
        content,
        onTapUrl: (url) async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return true;
        },
        textStyle: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: isDark ? Colors.white : Colors.black87,
        ),
      );
    }

    return SelectableText(
      content,
      style: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  IconData _getIconForFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'].contains(ext)) {
      return Icons.image;
    }
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart;
    if (['zip', 'rar', '7z'].contains(ext)) return Icons.folder_zip;
    if (['mp3', 'wav', 'flac'].contains(ext)) return Icons.audio_file;
    if (['mp4', 'mov', 'avi'].contains(ext)) return Icons.video_file;
    return Icons.attach_file;
  }

  String _formatFileSize(String sizeStr) {
    try {
      final bytes = int.parse(sizeStr);
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return sizeStr;
    }
  }
}
