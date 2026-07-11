import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';

/// 应用更新页面（Google Material 3 风格）
///
/// - 顶部：应用图标 + 当前版本
/// - 状态卡片：是否最新 / 发现新版本 + 下载按钮
/// - 新版本特性（release notes）
/// - 历史版本列表
class UpdateScreen extends StatefulWidget {
  final String currentVersion;

  const UpdateScreen({super.key, required this.currentVersion});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _loading = true;
  bool _downloading = false;
  String? _error;
  UpdateInfo? _info;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await UpdateService.checkUpdate(widget.currentVersion);
      if (mounted) {
        setState(() {
          _info = info;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _download(String? url) async {
    if (url == null || url.isEmpty) {
      // 退回到 Releases 页
      final uri = Uri.parse('${UpdateService.repoUrl}/releases');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    setState(() => _downloading = true);
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开下载链接，请稍后重试')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('应用更新'),
            pinned: true,
            stretch: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '重新检查',
                onPressed: _loading ? null : _check,
              ),
            ],
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _buildErrorState(cs, _error!),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate(
                _buildContent(cs),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(ColorScheme cs) {
    final info = _info;
    if (info == null) return [];

    final latest = info.latestRelease;
    final hasUpdate = info.hasUpdate;

    return [
      // ===== 顶部：应用图标 + 版本信息 =====
      const SizedBox(height: 8),
      Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.mail_outline_rounded,
            size: 48,
            color: cs.primary,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: Text(
          'Cloud Mail',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          '当前版本 v${widget.currentVersion}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
      ),
      const SizedBox(height: 24),

      // ===== 状态卡片 =====
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildStatusCard(cs, hasUpdate, latest),
      ),
      const SizedBox(height: 24),

      // ===== 新版本特性 =====
      if (latest != null && latest.body.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            hasUpdate ? '新版本特性' : '最新版本说明',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SelectableText(
            latest.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],

      // ===== 历史版本 =====
      if (info.allReleases.length > 1) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '历史版本',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 8),
        ...info.allReleases.skip(1).map((r) => _buildHistoryItem(cs, r)),
        const SizedBox(height: 16),
      ],

      // ===== 项目链接 =====
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: OutlinedButton.icon(
          onPressed: () async {
            final uri = Uri.parse(UpdateService.repoUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('在 GitHub 上查看项目'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
      const SizedBox(height: 32),
    ];
  }

  Widget _buildStatusCard(ColorScheme cs, bool hasUpdate, ReleaseInfo? latest) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasUpdate
            ? cs.primaryContainer.withOpacity(0.5)
            : cs.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasUpdate ? cs.primary.withOpacity(0.3) : cs.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasUpdate ? cs.primary : cs.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasUpdate
                      ? Icons.system_update_alt_rounded
                      : Icons.check_circle_rounded,
                  color: hasUpdate ? cs.onPrimary : cs.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasUpdate ? '发现新版本' : '已是最新版本',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (latest != null)
                      Text(
                        hasUpdate
                            ? '最新版本 v${latest.version}'
                            : '当前已是 v${latest.version}',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (hasUpdate && latest != null) ...[
            const SizedBox(height: 12),
            Text(
              '发布于 ${_formatDate(latest.publishedAt)}'
              '${latest.assets.isNotEmpty && latest.assets.first.size > 0 ? ' · ${_formatSize(latest.assets.first.size)}' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _downloading
                        ? null
                        : () => _download(latest.apkUrl),
                    icon: _downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded, size: 20),
                    label: Text(_downloading ? '正在打开…' : '立即下载更新'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryItem(ColorScheme cs, ReleaseInfo r) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: r.htmlUrl.isNotEmpty
              ? () async {
                  final uri = Uri.parse(r.htmlUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.history, size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'v${r.version}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (r.prerelease)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '预发布',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.onTertiaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(r.publishedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(ColorScheme cs, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 64, color: cs.error.withOpacity(0.6)),
            const SizedBox(height: 16),
            const Text(
              '检查更新失败',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _check,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final uri =
                    Uri.parse('${UpdateService.repoUrl}/releases');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('在浏览器中查看'),
            ),
          ],
        ),
      ),
    );
  }
}
