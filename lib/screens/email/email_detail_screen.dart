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

  // 邮件正文缩放倍率（InteractiveViewer），双指自由缩放整个内容
  double _contentScale = 1.0;
  // InteractiveViewer 的变换控制器，用于菜单按钮缩放
  late final TransformationController _transformController;
  static const double _minScale = 0.5;
  static const double _maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    _email = widget.email;
    _isStarred = _email.isStarred;
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  /// 菜单按钮缩放
  void _zoomBy(double factor) {
    final newScale = (_contentScale * factor).clamp(_minScale, _maxScale);
    if (newScale == _contentScale) return;
    setState(() => _contentScale = newScale);
    _transformController.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
  }

  void _zoomReset() {
    setState(() => _contentScale = 1.0);
    _transformController.value = Matrix4.identity();
  }

  /// 把邮件正文（含纯文本）拷贝到剪贴板
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

  String _formatFullTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr);
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
            // 顶部导航栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                      color: _isStarred ? cs.tertiary : null,
                      size: 24,
                    ),
                    onPressed: _loading ? null : _toggleStar,
                  ),
                  IconButton(
                    icon: const Icon(Icons.reply_rounded, size: 22),
                    onPressed: _reply,
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
                          _zoomBy(1.2);
                          break;
                        case 'zoom_out':
                          _zoomBy(1 / 1.2);
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
                          Text('放大正文'),
                        ]),
                      ),
                      const PopupMenuItem(
                        value: 'zoom_out',
                        child: Row(children: [
                          Icon(Icons.zoom_out_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('缩小正文'),
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
            // 邮件内容
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                children: [
                  // 主题（大标题）
                  Text(
                    _email.subject,
                    style: TextStyle(
                      fontSize: isGoogle ? 22 : 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 发件人信息
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 头像：Google 方形圆角，Apple 圆形
                      isGoogle
                          ? Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: accountColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 22,
                              backgroundColor: accountColor,
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              senderEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatFullTime(_email.createTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 收件人标签
                      if (_email.isSent)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '发给 $displayName',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  // 附件
                  if (_email.attList != null && _email.attList!.isNotEmpty) ...[
                    _buildAttachments(isDark),
                    const SizedBox(height: 16),
                  ],
                  // 邮件正文
                  _buildEmailContent(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      // 底部操作栏
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                icon: Icons.reply_rounded,
                label: '回复',
                onTap: _reply,
              ),
              _buildActionButton(
                icon: Icons.forward_rounded,
                label: '转发',
                onTap: () => Navigator.pushNamed(
                  context,
                  '/compose',
                  arguments: {
                    'api': widget.api,
                    'forwardEmail': _email,
                  },
                ),
              ),
              _buildActionButton(
                icon: _isStarred
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                label: _isStarred ? '已星标' : '星标',
                color: _isStarred ? cs.tertiary : null,
                onTap: _loading ? null : _toggleStar,
              ),
              _buildActionButton(
                icon: Icons.delete_outline_rounded,
                label: '删除',
                color: cs.error,
                onTap: _deleteEmail,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color ?? cs.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color ?? cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachments(bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                '${_email.attList!.length} 个附件',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: cs.onSurface,
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
                      color: cs.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            att.fileName,
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatFileSize(att.fileSize),
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant.withOpacity(0.6),
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
    final cs = Theme.of(context).colorScheme;
    final content = _email.content;
    final hasHtml = content.contains('<') && content.contains('>');

    if (!hasHtml && content.trim().isEmpty) {
      return Center(
        child: Padding(
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
        ),
      );
    }

    // 缩放提示条（仅当用户调整过时显示）
    final scaleIndicator = _contentScale != 1.0
        ? Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '缩放 ${(_contentScale * 100).round()}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _contentScale = 1.0),
                  icon: const Icon(Icons.restart_alt, size: 14),
                  label: const Text('恢复', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    // InteractiveViewer：双指自由缩放整个内容（像浏览器看 HTML 一样）
    // SelectionArea：长按文字弹出系统级 复制/分享/全选 菜单
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        scaleIndicator,
        Container(
          width: double.infinity,
          // ClipRect 防止缩放后内容溢出到其他区域
          child: ClipRect(
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: _minScale,
              maxScale: _maxScale,
              // 默认 constrained=true，保持内容宽度适配屏幕
              boundaryMargin: const EdgeInsets.all(double.infinity),
              onInteractionEnd: (details) {
                final scale = _transformController.value.getMaxScaleOnAxis();
                if ((scale - _contentScale).abs() > 0.01) {
                  setState(() => _contentScale = scale);
                }
              },
              child: hasHtml
                  ? SelectionArea(
                      child: HtmlWidget(
                        content,
                        onTapUrl: (url) async {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
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
            ),
          ),
        ),
      ],
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
