import 'dart:convert';
import 'package:http/http.dart' as http;

/// 翻译服务
///
/// 优先使用 LibreTranslate 免费公共 API（无需配置），
/// 失败时由调用方回退到 AI 翻译。
class TranslateService {
  static const _endpoint = 'https://libretranslate.com/translate';

  /// 使用 LibreTranslate 翻译文本为中文
  ///
  /// 返回翻译结果字符串；失败时返回 null，由调用方决定回退策略。
  static Future<String?> translateToChinese(String text) async {
    if (text.trim().isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'q': text,
              'source': 'auto',
              'target': 'zh',
              'format': 'text',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final translated = data['translatedText'] as String?;
        if (translated != null && translated.isNotEmpty) {
          return translated;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
