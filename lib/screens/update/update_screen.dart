import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';
import '../../utils/storage.dart';

/// 应用更新页面（Google Material 3 风格）
///
/// 设计目标：
/// - 顶部：应用图标 + 当前版本
/// - 状态卡片：是否最新 / 发现新版本
/// - 最新版本详情卡片（版本号、发布日期、APK大小、完整更新说明、下载按钮）
/// - 点击下载后弹出镜像选择（自动测速）→ 确认 → 应用内下载（进度条）→ 自动打开安装
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

  // ===== 镜像源 =====
  // 内置默认镜像源列表（解决国内直连 GitHub 下载慢 / 打不开的问题）
  // 规则：{prefix} + 原始 github.com 下载链接
  static const _mirrors = <String>[
    'direct', // 直连（原始 GitHub）
    'https://ghproxy.com/', // ghproxy
    'https://mirror.ghproxy.com/', // ghproxy 镜像
    'https://github.moeyy.xyz/', // moeyy
    'https://kkgithub.com/', // kkgithub（替换域名）
    'https://gh.api.99988866.xyz/', // 99988866
    'https://hub.gitmirror.com/', // gitmirror
  ];

  /// 运行时镜像列表：默认用内置列表，用户添加自定义镜像后从本地存储加载覆盖
  List<String> _activeMirrors = _mirrors;

  // ===== 下载状态 =====
  /// 正在下载（或已下载完成 / 下载失败）的 release，null 表示无下载任务
  ReleaseInfo? _downloadingRelease;
  /// 当前下载使用的镜像（用于失败后重试）
  String? _downloadingMirror;
  double _downloadProgress = 0.0; // 0.0 ~ 1.0
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _downloadDone = false;
  String? _downloadError;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _check();
    _loadMirrors();
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

  /// 从本地存储加载自定义镜像源；为空则保留默认列表
  void _loadMirrors() {
    final stored = StorageService.getUpdateMirrors();
    if (stored.isNotEmpty) {
      // 确保 direct 始终存在
      final list = stored.contains('direct') ? stored : ['direct', ...stored];
      setState(() => _activeMirrors = list);
    }
  }

  /// 拼接镜像 URL
  /// - direct：原样返回
  /// - kkgithub.com：把 github.com 替换为 kkgithub.com（域名替换型）
  /// - 其他：前缀 + 原始 URL（代理型）
  String _wrapWithMirror(String url, String mirror) {
    if (mirror == 'direct') return url;
    if (mirror.contains('kkgithub.com')) {
      return url.replaceFirst('github.com', 'kkgithub.com');
    }
    return '$mirror$url';
  }

  /// 点击「下载安装包」：弹出镜像选择 BottomSheet（自动测速）→ 确认 → 应用内下载
  Future<void> _pickMirrorAndDownload(ReleaseInfo r) async {
    if (r.apkUrl == null || r.apkUrl!.isEmpty) {
      // 没有 APK 资源，回退到浏览器打开发布页
      await _openReleasePage(r);
      return;
    }

    final mirror = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MirrorPickerSheet(
        release: r,
        initialMirrors: _activeMirrors,
        wrapWithMirror: _wrapWithMirror,
        onMirrorsChanged: (list) {
          setState(() => _activeMirrors = list);
          StorageService.setUpdateMirrors(list);
        },
      ),
    );

    if (!mounted || mirror == null) return;
    await _confirmAndDownload(r, mirror);
  }

  Future<void> _openReleasePage(ReleaseInfo r) async {
    final url = r.htmlUrl.isNotEmpty
        ? r.htmlUrl
        : '${UpdateService.repoUrl}/releases';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// 选择镜像后弹出确认对话框
  Future<void> _confirmAndDownload(ReleaseInfo r, String mirror) async {
    final apkSize = r.assets.isNotEmpty ? r.assets.first.size : 0;
    final sizeText = apkSize > 0 ? '\n约 ${_formatSize(apkSize)}' : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认下载'),
        content: Text(
          '确认使用 ${_mirrorLabel(mirror)} 镜像下载 v${r.version} 更新包？$sizeText',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认下载'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _startDownload(r, mirror);
  }

  /// 应用内下载 APK 到临时目录，完成后调用 OpenFile 打开触发系统安装
  Future<void> _startDownload(ReleaseInfo r, String mirror) async {
    final rawUrl = r.apkUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该版本没有可下载的 APK 文件')),
      );
      return;
    }
    final url = _wrapWithMirror(rawUrl, mirror);

    setState(() {
      _downloadingRelease = r;
      _downloadingMirror = mirror;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _downloadDone = false;
      _downloadError = null;
      _cancelToken = CancelToken();
    });

    String? savePath;
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'cloud_mail_v${r.version}.apk';
      savePath = '${dir.path}/$fileName';
      // 删除旧文件，避免残留导致安装旧包
      final oldFile = File(savePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          if (total > 0) {
            setState(() {
              _receivedBytes = received;
              _totalBytes = total;
              _downloadProgress = (received / total).clamp(0.0, 1.0);
            });
          } else {
            setState(() => _receivedBytes = received);
          }
        },
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 30),
        ),
      );

      if (!mounted) return;
      setState(() {
        _downloadDone = true;
        _downloadProgress = 1.0;
      });

      // 打开 APK 触发系统安装
      final result = await OpenFile.open(savePath);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开安装包失败: ${result.message}')),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      if (CancelToken.isCancel(e)) {
        // 用户主动取消，重置下载状态
        _resetDownloadState();
      } else {
        setState(() {
          _downloadError = e.message?.isNotEmpty == true
              ? e.message!
              : '网络错误，下载失败';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloadError = e.toString());
    }
  }

  /// 取消下载
  Future<void> _cancelDownload() async {
    _cancelToken?.cancel('用户取消下载');
    _resetDownloadState();
  }

  /// 重置下载状态回到初始
  void _resetDownloadState() {
    if (!mounted) return;
    setState(() {
      _downloadingRelease = null;
      _downloadingMirror = null;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _downloadDone = false;
      _downloadError = null;
      _cancelToken = null;
    });
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

      // ===== 最新版本详情卡片（仅显示最新版本） =====
      if (latest != null) ...[
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '最新版本',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 8),
        _buildReleaseItem(cs, latest, isLatest: true),
        const SizedBox(height: 16),
      ],

      // ===== 项目链接 =====
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: OutlinedButton.icon(
          onPressed: () async {
            final uri = Uri.parse('${UpdateService.repoUrl}/releases');
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
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

  /// 单个发布版本卡片，含下载按钮 / 下载进度区域
  Widget _buildReleaseItem(ColorScheme cs, ReleaseInfo r,
      {required bool isLatest}) {
    final isThisDownloading = _downloadingRelease?.tagName == r.tagName;
    final anyDownloading = _downloadingRelease != null;
    final apkSize = r.assets.isNotEmpty ? r.assets.first.size : 0;
    final hasApk = r.apkUrl != null && r.apkUrl!.isNotEmpty;

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
                maxLines: null,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // 下载按钮 / 下载进度区域
            if (isThisDownloading)
              _buildDownloadArea(cs, r)
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: anyDownloading
                          ? null
                          : () => _pickMirrorAndDownload(r),
                      icon: Icon(
                        hasApk
                            ? Icons.download_rounded
                            : Icons.open_in_new,
                        size: 18,
                      ),
                      label: Text(hasApk ? '下载安装包' : '查看发布页'),
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

  /// 下载进度 / 完成 / 失败 区域
  Widget _buildDownloadArea(ColorScheme cs, ReleaseInfo r) {
    // 失败：显示错误信息 + 重试 / 取消
    if (_downloadError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.errorContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: cs.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '下载失败：$_downloadError',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onErrorContainer,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    final mirror = _downloadingMirror;
                    if (mirror != null) {
                      _startDownload(r, mirror);
                    }
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('重试'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _resetDownloadState,
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 完成：绿色进度条 + 提示
    if (_downloadDone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '下载完成，正在打开安装…',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1.0,
              minHeight: 8,
              backgroundColor: cs.surfaceVariant,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
          ),
        ],
      );
    }

    // 下载中：标题 + 取消按钮 + 进度条 + 百分比 / 大小
    final percent = (_downloadProgress * 100).clamp(0, 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.download_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '正在下载 v${r.version}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: '取消下载',
              onPressed: _cancelDownload,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _downloadProgress,
            minHeight: 8,
            backgroundColor: cs.surfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _totalBytes > 0
              ? '$percent% · ${_formatSize(_receivedBytes)} / ${_formatSize(_totalBytes)}'
              : '$percent%',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
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
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
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

/// 单个镜像测速结果
class _MirrorTest {
  bool testing = true;
  int? latencyMs; // null 表示失败 / 超时
}

/// 镜像源选择 BottomSheet：并发测速，标记推荐（延迟最低），支持添加自定义镜像
class _MirrorPickerSheet extends StatefulWidget {
  final ReleaseInfo release;
  final List<String> initialMirrors;
  final String Function(String url, String mirror) wrapWithMirror;
  final void Function(List<String> mirrors) onMirrorsChanged;

  const _MirrorPickerSheet({
    required this.release,
    required this.initialMirrors,
    required this.wrapWithMirror,
    required this.onMirrorsChanged,
  });

  @override
  State<_MirrorPickerSheet> createState() => _MirrorPickerSheetState();
}

class _MirrorPickerSheetState extends State<_MirrorPickerSheet> {
  late List<String> _mirrors;
  final Map<String, _MirrorTest> _tests = {};

  @override
  void initState() {
    super.initState();
    _mirrors = List.of(widget.initialMirrors);
    _runSpeedTests();
  }

  /// 并发测速所有镜像
  Future<void> _runSpeedTests() async {
    final apkUrl = widget.release.apkUrl;
    if (apkUrl == null || apkUrl.isEmpty) return;

    // 初始化为测速中
    for (final m in _mirrors) {
      _tests[m] = _MirrorTest()..testing = true;
    }
    if (mounted) setState(() {});

    await Future.wait(_mirrors.map((m) async {
      final ms = await _testSpeed(m, apkUrl);
      if (mounted) {
        setState(() {
          _tests[m] = _MirrorTest()
            ..testing = false
            ..latencyMs = ms;
        });
      }
    }));
  }

  /// 对单个镜像发 HEAD 请求测速，5 秒超时；返回延迟毫秒数，失败返回 null
  Future<int?> _testSpeed(String mirror, String apkUrl) async {
    final url = widget.wrapWithMirror(apkUrl, mirror);
    final dio = Dio();
    final sw = Stopwatch()..start();
    try {
      await dio.head(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          followRedirects: true,
          maxRedirects: 5,
        ),
      );
      sw.stop();
      return sw.elapsedMilliseconds;
    } on DioException catch (e) {
      sw.stop();
      // 收到任何 HTTP 响应（如 405 Method Not Allowed）都说明镜像可达
      if (e.response != null) {
        return sw.elapsedMilliseconds;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      dio.close(force: true);
    }
  }

  /// 延迟最低的有效镜像标记为推荐
  String? get _recommendedMirror {
    String? best;
    int? bestMs;
    for (final entry in _tests.entries) {
      final t = entry.value;
      if (!t.testing && t.latencyMs != null) {
        if (bestMs == null || t.latencyMs! < bestMs) {
          bestMs = t.latencyMs;
          best = entry.key;
        }
      }
    }
    return best;
  }

  /// 添加自定义镜像源
  Future<void> _addMirror() async {
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('添加镜像源'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '输入镜像源 URL 前缀，例如 https://ghproxy.com/',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (input == null || input.isEmpty) return;
    if (_mirrors.contains(input)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该镜像源已存在')),
        );
      }
      return;
    }

    setState(() {
      _mirrors = [..._mirrors, input];
      _tests[input] = _MirrorTest()..testing = true;
    });
    widget.onMirrorsChanged(_mirrors);

    // 对新添加的镜像单独测速
    final apkUrl = widget.release.apkUrl;
    if (apkUrl != null && apkUrl.isNotEmpty) {
      final ms = await _testSpeed(input, apkUrl);
      if (mounted) {
        setState(() {
          _tests[input] = _MirrorTest()
            ..testing = false
            ..latencyMs = ms;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recommended = _recommendedMirror;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部拖拽指示条
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.speed_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择下载源',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '已自动测速，推荐选择延迟最低的镜像',
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
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _mirrors.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (ctx, i) {
                  final m = _mirrors[i];
                  return _buildMirrorItem(cs, m, _tests[m], recommended);
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: OutlinedButton.icon(
                onPressed: _addMirror,
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('添加镜像源'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMirrorItem(
    ColorScheme cs,
    String m,
    _MirrorTest? test,
    String? recommended,
  ) {
    final isDirect = m == 'direct';
    final isRecommended = recommended == m;
    final label = _mirrorLabel(m);

    return ListTile(
      onTap: () => Navigator.of(context).pop(m),
      leading: Icon(
        isDirect ? Icons.cloud_download_outlined : Icons.bolt_outlined,
        color: cs.primary,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isRecommended) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '推荐',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        isDirect ? '原始 GitHub 直连' : '加速镜像',
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
      ),
      trailing: _buildLatency(cs, test),
    );
  }

  Widget _buildLatency(ColorScheme cs, _MirrorTest? test) {
    if (test == null || test.testing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text(
            '测速中',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      );
    }
    final ms = test.latencyMs;
    if (ms == null) {
      return Text(
        '超时',
        style: TextStyle(
          fontSize: 12,
          color: cs.error,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    Color color;
    if (ms < 500) {
      color = Colors.green;
    } else if (ms < 1500) {
      color = Colors.orange;
    } else {
      color = cs.error;
    }
    return Text(
      '$ms ms',
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// 镜像源显示名称：direct → 'GitHub 直连'，其余去掉协议头与斜杠
String _mirrorLabel(String m) {
  if (m == 'direct') return 'GitHub 直连';
  return m
      .replaceFirst('https://', '')
      .replaceFirst('http://', '')
      .replaceAll('/', '');
}
