import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyToken = 'token';
  static const String _keyEmail = 'email';
  static const String _keyBaseUrl = 'base_url';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? get token => _prefs.getString(_keyToken);
  static set token(String? value) {
    if (value == null) {
      _prefs.remove(_keyToken);
    } else {
      _prefs.setString(_keyToken, value);
    }
  }

  static String? get email => _prefs.getString(_keyEmail);
  static set email(String? value) {
    if (value == null) {
      _prefs.remove(_keyEmail);
    } else {
      _prefs.setString(_keyEmail, value);
    }
  }

  static String? get baseUrl => _prefs.getString(_keyBaseUrl);
  static set baseUrl(String? value) {
    if (value == null) {
      _prefs.remove(_keyBaseUrl);
    } else {
      _prefs.setString(_keyBaseUrl, value);
    }
  }

  static void clear() {
    _prefs.remove(_keyToken);
    _prefs.remove(_keyEmail);
  }
}

class ErrorMessages {
  static const List<String> networkErrors = [
    '哎呀妈呀！网络它离家出走了！（连接已断开）',
    '服务器：我不听我不听我不听！（连接关闭）',
    '啪！网线断了，就像我的心一样碎了。',
    '网络：今天不想上班，告辞！（连接关闭）',
    '服务器正在摸鱼中...（连接被关闭）',
    '信号说：我先撤了啊兄弟！',
    '啊这... 网络它突然有自己的想法了。',
    '服务器单方面宣布：连接结束！',
  ];

  static const List<String> timeoutErrors = [
    '等得花儿都谢了，服务器还在化妆...',
    '服务器：等我再睡五分钟...',
    '超时警告：服务器可能在刷短视频。',
    '你的请求在路上迷路了...',
    '服务器正在沉思人生的意义...',
  ];

  static const List<String> authErrors = [
    '密码就像你的初恋，总是记不住的那个才最难忘。',
    '邮箱或密码错误，建议用脚指头再想想。',
    '登录失败，是不是偷偷把密码改成生日了？',
    '认证失败：你可能是个假的管理员。',
    'Token 失效了，就像过期的零食一样。',
  ];

  static const List<String> serverErrors = [
    '服务器：我裂开了。（内部错误）',
    '500 错误：服务器今天心情不好。',
    '后端小哥：这不是我写的 bug！',
    '服务器已崩溃，正在墙角画圈圈。',
    '出大事了！服务器它... 它... 它累了。',
  ];

  static const List<String> unknownErrors = [
    '出了点问题，具体啥问题我也不知道...',
    '未知错误：可能是你的人品问题。',
    '发生了一些奇怪的事情...',
    '程序：我是谁？我在哪？我在干啥？',
    'Bug 它来了，它带着错误走来了。',
  ];

  static String getErrorMessage(Object error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('connection closed') ||
        msg.contains('connection reset') ||
        msg.contains('errno = -104') ||
        msg.contains('broken pipe') ||
        msg.contains('socket')) {
      return networkErrors[
          DateTime.now().millisecondsSinceEpoch % networkErrors.length];
    }

    if (msg.contains('timeout') || msg.contains('timed out')) {
      return timeoutErrors[
          DateTime.now().millisecondsSinceEpoch % timeoutErrors.length];
    }

    if (msg.contains('401') ||
        msg.contains('unauthorized') ||
        msg.contains('token')) {
      return authErrors[
          DateTime.now().millisecondsSinceEpoch % authErrors.length];
    }

    if (msg.contains('500') || msg.contains('502') || msg.contains('503')) {
      return serverErrors[
          DateTime.now().millisecondsSinceEpoch % serverErrors.length];
    }

    if (msg.contains('socketexception') || msg.contains('no internet')) {
      return networkErrors[
          DateTime.now().millisecondsSinceEpoch % networkErrors.length];
    }

    return unknownErrors[
        DateTime.now().millisecondsSinceEpoch % unknownErrors.length];
  }
}

Future<void> showFunDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.sentiment_dissatisfied,
  Color iconColor = Colors.orange,
  String actionText = '我知道了',
  VoidCallback? onAction,
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Icon(icon, size: 60, color: iconColor),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, height: 1.5),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onAction?.call();
          },
          style: TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(actionText),
        ),
      ],
    ),
  );
}