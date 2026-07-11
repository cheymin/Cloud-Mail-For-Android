import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/email.dart';
import '../services/api_service.dart';
import '../utils/storage.dart';

class AiService {
  String? _apiKey;
  String? _baseUrl;

  AiService({String? apiKey, String? baseUrl}) {
    _apiKey = apiKey ?? StorageService.openaiApiKey;
    _baseUrl = (baseUrl ?? StorageService.openaiBaseUrl)?.trim() ??
        'https://api.openai.com/v1';
    if (!_baseUrl!.endsWith('/')) {
      _baseUrl = '$_baseUrl/';
    }
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  Future<String> analyzeEmail(Email email) async {
    final prompt = '''分析以下邮件内容，提供摘要、重要信息提取和回复建议：

发件人: ${email.sendName} <${email.sendEmail}>
收件人: ${email.toName} <${email.toEmail}>
主题: ${email.subject}
时间: ${email.createTime}

内容:
${email.text.isNotEmpty ? email.text : email.content.replaceAll(RegExp(r'<[^>]*>'), '')}

请以中文回复，包括：
1. 邮件摘要
2. 关键点
3. 建议回复方向''';

    return await _callChatCompletion([
      {'role': 'system', 'content': '你是一个专业的邮件助手，擅长分析和回复邮件。'},
      {'role': 'user', 'content': prompt},
    ]);
  }

  Future<String> chatWithMailbox(
    List<Email> emails,
    String userMessage, {
    CloudMailApi? api,
  }) async {
    final emailListStr = emails.take(10).map((e) {
      final content = e.text.isNotEmpty
          ? e.text.substring(0, e.text.length > 200 ? 200 : e.text.length)
          : e.content.replaceAll(RegExp(r'<[^>]*>'), '').substring(
              0, e.content.length > 200 ? 200 : e.content.length);
      return '''邮件ID: ${e.emailId}
发件人: ${e.sendName} <${e.sendEmail}>
主题: ${e.subject}
时间: ${e.createTime}
内容预览: ${content}...''';
    }).join('\n\n---\n\n');

    final systemPrompt = '''你是一个智能邮件助手。你可以查看邮件并执行以下操作：

可用工具:
1. reply_email - 回复邮件
2. forward_email - 转发邮件
3. delete_email - 删除邮件
4. star_email - 标星/取消标星邮件
5. send_email - 发送新邮件

当前邮件列表（最多10封）:
$emailListStr

用户指令会直接给出，你可以：
- 直接回答问题（如"总结最近的邮件"）
- 需要执行操作时，使用工具调用格式

工具调用格式（JSON）:
{"action":"工具名","params":{"参数":值}}

示例:
{"action":"reply_email","params":{"emailId":123,"content":"好的，我明白了。"}}
{"action":"delete_email","params":{"emailId":123}}
{"action":"star_email","params":{"emailId":123,"star":true}}

请直接给出工具调用或回答，不需要额外解释。''';

    final response = await _callChatCompletion([
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ]);

    if (api != null) {
      try {
        final jsonStart = response.indexOf('{');
        final jsonEnd = response.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1 && jsonStart < jsonEnd) {
          final jsonStr = response.substring(jsonStart, jsonEnd + 1);
          final action = jsonDecode(jsonStr);
          final actionName = action['action'];
          final params = action['params'];

          if (actionName != null && params != null) {
            final result = await _executeAction(actionName, params, api);
            return '已执行操作: $actionName\n结果: $result';
          }
        }
      } catch (_) {}
    }

    return response;
  }

  Future<String> _executeAction(
    String action,
    Map<String, dynamic> params,
    CloudMailApi api,
  ) async {
    final emailId = params['emailId'] as int?;
    final content = params['content'] as String?;
    final toEmail = params['toEmail'] as String?;
    final star = params['star'] as bool?;
    final subject = params['subject'] as String?;

    try {
      switch (action) {
        case 'reply_email':
          if (emailId == null || content == null) {
            return '参数不足：需要 emailId 和 content';
          }
          final response = await api.sendEmail(
            accountId: StorageService.currentAccountId ?? 0,
            receiveEmail: [''],
            subject: '',
            content: content,
            text: content,
            sendType: 'reply',
            emailId: emailId,
          );
          return response.isSuccess ? '回复成功' : '回复失败: ${response.message}';

        case 'forward_email':
          if (emailId == null || toEmail == null) {
            return '参数不足：需要 emailId 和 toEmail';
          }
          final response = await api.sendEmail(
            accountId: StorageService.currentAccountId ?? 0,
            receiveEmail: [toEmail],
            subject: subject ?? 'Fwd:',
            content: content ?? '',
            text: content ?? '',
            sendType: 'new',
          );
          return response.isSuccess ? '转发成功' : '转发失败: ${response.message}';

        case 'delete_email':
          if (emailId == null) {
            return '参数不足：需要 emailId';
          }
          final response = await api.deleteEmails(emailId.toString());
          return response.isSuccess ? '删除成功' : '删除失败: ${response.message}';

        case 'star_email':
          if (emailId == null) {
            return '参数不足：需要 emailId';
          }
          if (star == true) {
            await api.addStar(emailId);
          } else {
            await api.cancelStar(emailId);
          }
          return star == true ? '已标星' : '已取消标星';

        case 'send_email':
          if (toEmail == null || subject == null || content == null) {
            return '参数不足：需要 toEmail、subject 和 content';
          }
          final response = await api.sendEmail(
            accountId: StorageService.currentAccountId ?? 0,
            receiveEmail: [toEmail],
            subject: subject,
            content: content,
            text: content,
          );
          return response.isSuccess ? '发送成功' : '发送失败: ${response.message}';

        default:
          return '未知操作: $action';
      }
    } catch (e) {
      return '操作失败: ${e.toString()}';
    }
  }

  Future<String> _callChatCompletion(List<Map<String, String>> messages) async {
    if (!isConfigured) {
      return '请先在设置中配置 OpenAI API Key';
    }

    final url = '${_baseUrl}chat/completions';
    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': messages,
      'max_tokens': 2000,
      'temperature': 0.7,
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return json['choices'][0]['message']['content'] as String;
      } else {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return 'API 错误: ${json['error']['message'] ?? response.statusCode}';
      }
    } catch (e) {
      return '请求失败: ${e.toString()}';
    }
  }
}