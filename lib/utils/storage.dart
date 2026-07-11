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

  static bool get showSenderAvatar => _prefs?.getBool('showSenderAvatar') ?? true;
  static set showSenderAvatar(bool value) {
    _prefs?.setBool('showSenderAvatar', value);
  }

  static bool get autoLoadImages => _prefs?.getBool('autoLoadImages') ?? true;
  static set autoLoadImages(bool value) {
    _prefs?.setBool('autoLoadImages', value);
  }

  static void clear() {
    _prefs?.remove('token');
    _prefs?.remove('email');
    _prefs?.remove('currentAccountId');
  }
}

class ErrorMessages {
  static const List<String> connectionErrors = [
    '哎呀妈呀！网络它离家出走了！',
    '啪！网线断了，就像我的心一样碎了',
    '网络：我不干了！',
    '连接失败？大概是服务器在摸鱼吧',
    '啊哦，连不上了，要不你重启一下路由器试试？',
    '网络它有自己的想法，它不想连接',
  ];

  static const List<String> timeoutErrors = [
    '等得花儿都谢了，服务器还在化妆...',
    '服务器：等我再睡五分钟',
    '超时了！服务器是不是去喝咖啡了？',
    '等了好久好久，结果啥也没等来',
    '服务器在思考人生，没空理你',
    '加载中...加载中...加载了个寂寞',
  ];

  static const List<String> authErrors = [
    '密码就像你的初恋，总是记不住的那个才最难忘',
    '身份验证失败，你是机器人吗？',
    '登不进去？想想是不是密码大小写搞反了',
    'Token 已过期，就像牛奶一样，过期了就得换',
    '权限不足？是不是管理员把你拉黑了',
    '登录失败，可能是因为你长得太帅了系统不敢认',
  ];

  static const List<String> serverErrors = [
    '服务器：我裂开了。',
    '后端小哥：这不是我写的 bug！',
    '500 错误，服务器它疯了',
    '服务器内部错误，建议给它放个假',
    '出了点问题，具体啥问题服务器也说不清楚',
    '服务器：今天不想干活，别烦我',
  ];

  static const List<String> unknownErrors = [
    '出了点问题，具体啥问题我也不知道...',
    'Bug 它来了，它带着错误走来了',
    '发生了一件不可思议的事情',
    '未知错误，可能是玄学问题',
    '程序它有自己的想法',
    '这个错误太神秘了，我都看不懂',
  ];

  static String getConnection() {
    return (connectionErrors..shuffle()).first;
  }

  static String getTimeout() {
    return (timeoutErrors..shuffle()).first;
  }

  static String getAuth() {
    return (authErrors..shuffle()).first;
  }

  static String getServer() {
    return (serverErrors..shuffle()).first;
  }

  static String getUnknown() {
    return (unknownErrors..shuffle()).first;
  }

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
    return '${getUnknown()}\n\n原始错误：${e.toString()}';
  }
}
