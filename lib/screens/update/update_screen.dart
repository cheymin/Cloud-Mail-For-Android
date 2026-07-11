import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';

/// 应用更新页面（Google Material 3 风格）
///
/// 设计目标：
/// - 顶部：应用图标 + 当前版本
/// - 状态卡片：是否最新 / 发现新版本
/// - 全部已发布版本列表，每项带下载按钮，用户手动选择下载
/// - 无 release / 限流 / 网络错误 → 明确状态提示，不闪退
class UpdateScreen extends StatefulWidget {
  final String currentVersion;

  const UpdateScreen({super.key, required this.currentVersion});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _loading = true;
  String? _error;
  UpdateInfo? _info;
  // 正在下载的版本 tag，用于显示 loading 态
  String? _downloadingTag;

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
    } on UpdateException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
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

  /// 下载指定 release 的 APK；若没有 APK 资源，跳转到 release 页面
  Future<void> _download(ReleaseInfo r) async {
    setState(() => _downloadingTag = r.tagName);
    try {
      final url = r.apkUrl;
      Uri? uri;
      if (url != null && url.isNotEmpty) {
        uri = Uri.parse(url);
      } else {
        // 没有 APK 资源，退回到 release 页
        uri = Uri.parse(r.htmlUrl.isNotEmpty
            ? r.htmlUrl
            : '${UpdateService.repoUrl}/releases');
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开下载链接，请稍后重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingTag = null);
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
    final all = info.allReleases;

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
        child: _buildStatusCard(cs, hasUpdate, latest, all.isEmpty),
      ),

      // ===== 无任何发布版本时的提示 =====
      if (all.isEmpty) ...[
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              Icon(Icons.inbox_rounded,
                  size: 56, color: cs.onSurfaceVariant.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text(
                'GitHub 上暂无已发布版本',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '新版本发布后会在此处显示，可供下载。',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],

      // ===== 全部已发布版本（用户手动选择下载） =====
      if (all.isNotEmpty) ...[
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '全部版本',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                '共 ${all.length} 个',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text(
            '点击下方任意版本即可下载安装包',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...all.map((r) => _buildReleaseItem(cs, r, isLatest: r == latest)),
        const SizedBox(height: 16),
      ],

      // ===== 项目链接 =====
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: OutlinedButton.icon(
          onPressed: () async {
            final uri = Uri.parse('${UpdateService.repoUrl}/releases');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('在 GitHub 上查看全部发布'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
      const SizedBox(height: 32),
    ];
  }

  Widget _buildStatusCard(
    ColorScheme cs,
    bool hasUpdate,
    ReleaseInfo? latest,
    bool noReleases,
  ) {
    final isLatest = !hasUpdate && !noReleases;
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
      child: Row(
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
                  : (noReleases
                      ? Icons.inbox_rounded
                      : Icons.check_circle_rounded),
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
                  noReleases
                      ? '暂无可下载的版本'
                      : (hasUpdate ? '发现新版本' : '已是最新版本'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (latest != null)
                  Text(
                    hasUpdate
                        ? '最新版本 v${latest.version} · ${_formatDate(latest.publishedAt)}'
                        : '当前已是 v${latest.version}',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                else if (noReleases)
                  Text(
                    'GitHub 仓库尚未发布任何版本',
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
    );
  }

  /// 单个发布版本卡片，含下载按钮，用户手动选择下载
  Widget _buildReleaseItem(ColorScheme cs, ReleaseInfo r,
      {required bool isLatest}) {
    final downloading = _downloadingTag == r.tagName;
    final apkSize = r.assets.isNotEmpty ? r.assets.first.size : 0;
    final hasApk =
        r.apkUrl != null && r.apkUrl!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isLatest
            ? cs.primaryContainer.withOpacity(0.3)
            : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLatest ? cs.primary.withOpacity(0.3) : cs.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLatest ? Icons.new_releases_rounded : Icons.history,
                  size: 20,
                  color: isLatest ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'v${r.version}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (isLatest)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '最新',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (r.prerelease) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(6),
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
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatDate(r.publishedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (apkSize > 0) ...[
                  Text(
                    ' · ${_formatSize(apkSize)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            if (r.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                r.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // 下载 / 查看按钮：用户手动触发
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: downloading ? null : () => _download(r),
                    icon: downloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            hasApk
                                ? Icons.download_rounded
                                : Icons.open_in_new,
                            size: 18,
                          ),
                    label: Text(downloading
                        ? '正在打开…'
                        : (hasApk ? '下载安装包' : '查看发布页')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
