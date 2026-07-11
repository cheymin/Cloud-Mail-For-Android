import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String? get token => _prefs?.getString('token');
  static set token(String? value) {
    if (value != null) {
      _prefs?.setString('token', value);
    } else {
      _prefs?.remove('token');
    }
  }

  static String? get email => _prefs?.getString('email');
  static set email(String? value) {
    if (value != null) {
      _prefs?.setString('email', value);
    } else {
      _prefs?.remove('email');
    }
  }

  static String? get baseUrl => _prefs?.getString('baseUrl');
  static set baseUrl(String? value) {
    if (value != null) {
      _prefs?.setString('baseUrl', value);
    } else {
      _prefs?.remove('baseUrl');
    }
  }

  static int? get currentAccountId => _prefs?.getInt('currentAccountId');
  static set currentAccountId(int? value) {
    if (value != null) {
      _prefs?.setInt('currentAccountId', value);
    } else {
      _prefs?.remove('currentAccountId');
    }
  }

  static String get themeMode => _prefs?.getString('themeMode') ?? 'system';
  static set themeMode(String value) {
    _prefs?.setString('themeMode', value);
  }

  /// UI 风格：'google' | 'apple'，默认 'google'
  static String get uiStyle => _prefs?.getString('uiStyle') ?? 'google';
  static set uiStyle(String value) {
    _prefs?.setString('uiStyle', value);
  }

  /// 记住登录状态
  static bool get rememberLogin => _prefs?.getBool('rememberLogin') ?? true;
  static set rememberLogin(bool value) {
    _prefs?.setBool('rememberLogin', value);
  }

  static bool get showSenderAvatar => _prefs?.getBool('showSenderAvatar') ?? true;
  static set showSenderAvatar(bool value) {
    _prefs?.setBool('showSenderAvatar', value);
  }

  static bool get autoLoadImages => _prefs?.getBool('autoLoadImages') ?? true;
  static set autoLoadImages(bool value) {
    _prefs?.setBool('autoLoadImages', value);
  }

  static String? get openaiApiKey => _prefs?.getString('openaiApiKey');
  static set openaiApiKey(String? value) {
    if (value != null) {
      _prefs?.setString('openaiApiKey', value);
    } else {
      _prefs?.remove('openaiApiKey');
    }
  }

  static String? get openaiBaseUrl => _prefs?.getString('openaiBaseUrl');
  static set openaiBaseUrl(String? value) {
    if (value != null) {
      _prefs?.setString('openaiBaseUrl', value);
    } else {
      _prefs?.remove('openaiBaseUrl');
    }
  }

  static String? get openaiModel => _prefs?.getString('openaiModel');
  static set openaiModel(String? value) {
    if (value != null) {
      _prefs?.setString('openaiModel', value);
    } else {
      _prefs?.remove('openaiModel');
    }
  }

  static String? get lastCheckUpdateTime => _prefs?.getString('lastCheckUpdateTime');
  static set lastCheckUpdateTime(String? value) {
    if (value != null) {
      _prefs?.setString('lastCheckUpdateTime', value);
    } else {
      _prefs?.remove('lastCheckUpdateTime');
    }
  }

  // AI 对话历史（JSON 字符串）
  static String? get chatHistory => _prefs?.getString('chatHistory');
  static set chatHistory(String? value) {
    if (value != null) {
      _prefs?.setString('chatHistory', value);
    } else {
      _prefs?.remove('chatHistory');
    }
  }

  static void clear() {
    _prefs?.remove('token');
    _prefs?.remove('email');
    _prefs?.remove('currentAccountId');
  }
}

class ErrorMessages {
  static const List<String> connectionErrors = [
    '网络连接失败，请检查网络设置',
    '无法连接到服务器，请稍后重试',
    '网络不可用，请检查你的连接',
  ];

  static const List<String> timeoutErrors = [
    '请求超时，请稍后重试',
    '服务器响应超时',
  ];

  static const List<String> authErrors = [
    '认证失败，请重新登录',
    '登录已过期，请重新登录',
    '邮箱或密码错误',
  ];

  static const List<String> serverErrors = [
    '服务器错误，请稍后重试',
    '服务器内部错误',
  ];

  static const List<String> unknownErrors = [
    '发生未知错误',
    '操作失败，请稍后重试',
  ];

  static String getConnection() => connectionErrors.first;

  static String getTimeout() => timeoutErrors.first;

  static String getAuth() => authErrors.first;

  static String getServer() => serverErrors.first;

  static String getUnknown() => unknownErrors.first;

  static String fromException(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('connection') ||
        msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('connection refused') ||
        msg.contains('connection closed')) {
      return getConnection();
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return getTimeout();
    }
    if (msg.contains('401') ||
        msg.contains('unauthorized') ||
        msg.contains('forbidden') ||
        msg.contains('403')) {
      return getAuth();
    }
    if (msg.contains('500') || msg.contains('internal server')) {
      return getServer();
    }
    return '${getUnknown()}\n\n${e.toString()}';
  }
}
