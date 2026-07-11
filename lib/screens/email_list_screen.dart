import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:cloud_mail_app/models/email.dart';
import 'package:cloud_mail_app/services/api_service.dart';
import 'package:cloud_mail_app/utils/storage.dart';
import 'package:cloud_mail_app/screens/login_screen.dart';
import 'package:cloud_mail_app/screens/add_user_screen.dart';

class EmailListScreen extends StatefulWidget {
  final CloudMailApi api;
  const EmailListScreen({super.key, required this.api});

  @override
  State<EmailListScreen> createState() => _EmailListScreenState();
}

class _EmailListScreenState extends State<EmailListScreen> {
  final RefreshController _refreshController = RefreshController();
  final List<Email> _emails = [];
  int _currentPage = 1;
  bool _isLoading = true;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadEmails();
  }

  Future<void> _loadEmails({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _emails.clear();
    }

    if (!_hasMore) {
      _refreshController.loadNoData();
      return;
    }

    try {
      final response = await widget.api.getEmailList(
        num: _currentPage,
        size: 20,
        timeSort: 'desc',
      );

      if (response.code == 200 && response.data != null) {
        setState(() {
          _emails.addAll(response.data!);
          _isLoading = false;
          _hasMore = response.data!.length == 20;
          _currentPage++;
        });
        if (refresh) {
          _refreshController.refreshCompleted();
        }
        _refreshController.loadComplete();
      } else if (response.code == 401) {
        if (mounted) {
          StorageService.clear();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          showFunDialog(
            context,
            title: '加载失败',
            message: response.message.isEmpty
                ? '邮件列表它害羞了，不肯出来...'
                : response.message,
            icon: Icons.error_outline,
            iconColor: Colors.orange,
          );
        }
        _refreshController.refreshFailed();
        _refreshController.loadFailed();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _refreshController.refreshFailed();
      _refreshController.loadFailed();
      if (mounted && _emails.isEmpty) {
        showFunDialog(
          context,
          title: '连接失败',
          message: ErrorMessages.getErrorMessage(e),
          icon: Icons.wifi_off,
          iconColor: Colors.orange,
          actionText: '重试',
          onAction: _loadEmails,
        );
      }
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('确定要走了吗？'),
        content: const Text('你的邮件们会想你的... 真的吗？不一定。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('再留会儿'),
          ),
          TextButton(
            onPressed: () {
              StorageService.clear();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('无情离开'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.email_outlined,
                color: Color(0xFF6C63FF),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '收件箱',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: '添加用户',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddUserScreen(api: widget.api),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey.shade200,
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildEmailList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddUserScreen(api: widget.api),
            ),
          );
        },
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          '添加用户',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmailList() {
    if (_emails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '空空如也~',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '一封邮件都没有，是寂寞的味道',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _loadEmails(refresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('刷新一下'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return SmartRefresher(
      controller: _refreshController,
      enablePullDown: true,
      enablePullUp: true,
      header: const WaterDropHeader(
        waterDropColor: Color(0xFF6C63FF),
      ),
      footer: CustomFooter(
        builder: (context, mode) {
          Widget body;
          if (mode == LoadStatus.idle) {
            body = const Text('上拉加载更多', style: TextStyle(color: Colors.grey));
          } else if (mode == LoadStatus.loading) {
            body = const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          } else if (mode == LoadStatus.failed) {
            body = const Text('加载失败，点击重试',
                style: TextStyle(color: Colors.grey));
          } else if (mode == LoadStatus.canLoading) {
            body = const Text('松手加载更多', style: TextStyle(color: Colors.grey));
          } else {
            body = const Text('已经到底啦~', style: TextStyle(color: Colors.grey));
          }
          return SizedBox(height: 55, child: Center(child: body));
        },
      ),
      onRefresh: () => _loadEmails(refresh: true),
      onLoading: _loadEmails,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _emails.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildEmailItem(_emails[index]),
      ),
    );
  }

  Widget _buildEmailItem(Email email) {
    final isInbox = email.type == 0;
    final senderDisplay =
        email.sendName?.isNotEmpty == true && email.sendEmail != null
            ? '${email.sendName!} <${email.sendEmail!}>'
            : email.sendEmail ?? '未知发件人';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => _buildEmailDetail(email),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isInbox
                            ? Colors.green.shade50
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isInbox ? '收件' : '发件',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isInbox
                              ? Colors.green.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (email.isDel == 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '已删除',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      email.createTime ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  email.subject ?? '(无主题)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  senderDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  email.text?.replaceAll('\n', ' ') ??
                      email.content?.replaceAll(RegExp(r'<[^>]*>'), '') ??
                      '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailDetail(Email email) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email.subject ?? '(无主题)',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF6C63FF),
                      child: Text(
                        (email.sendName ?? email.sendEmail ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email.sendName ?? email.sendEmail ?? '未知',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '发送至: ${email.toEmail ?? ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      email.createTime ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(
                email.text ??
                    email.content?.replaceAll(RegExp(r'<[^>]*>'), '') ??
                    '(无内容)',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}