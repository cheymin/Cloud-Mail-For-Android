import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/email.dart';

class CloudMailApi {
  String baseUrl;
  String? token;

  CloudMailApi(this.baseUrl, {this.token});

  String _url(String path) {
    String url = baseUrl;
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    // 所有 API 都在 /api 下
    if (!path.startsWith('/api')) {
      path = '/api$path';
    }
    return '$url$path';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': token!,
      };

  ApiResponse<T> _parseResponse<T>(http.Response response, T Function(dynamic)? dataParser) {
    final Map<String, dynamic> json = jsonDecode(utf8.decode(response.bodyBytes));
    return ApiResponse<T>.fromJson(json, dataParser);
  }

  Future<ApiResponse<String>> genToken(String email, String password) async {
    final response = await http.post(
      Uri.parse(_url('/api/public/genToken')),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _parseResponse<String>(response, (data) => data['token'] as String);
  }

  /// 查询邮件列表 — 使用官方公开 API POST /api/public/emailList
  /// 官方参数: toEmail, sendName, sendEmail, subject, content, timeSort, type, isDel, num(页码), size
  Future<ApiResponse<EmailListResult>> getEmailList({
    int? accountId,
    int type = 0,
    int size = 20,
    int? emailId,
    int timeSort = 0,
    int? allReceive,
    String? toEmail,
    String? sendName,
    String? sendEmail,
    String? subject,
    String? content,
    int? isDel,
    int page = 1,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'size': size,
      'timeSort': timeSort,
      'num': page, // 官方 API 用 num 表示页码
    };
    if (toEmail != null && toEmail.isNotEmpty) body['toEmail'] = toEmail;
    if (sendName != null && sendName.isNotEmpty) body['sendName'] = sendName;
    if (sendEmail != null && sendEmail.isNotEmpty) body['sendEmail'] = sendEmail;
    if (subject != null && subject.isNotEmpty) body['subject'] = subject;
    if (content != null && content.isNotEmpty) body['content'] = content;
    if (isDel != null) body['isDel'] = isDel;

    final response = await http.post(
      Uri.parse(_url('/api/public/emailList')),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _parseResponse<EmailListResult>(response, (data) {
      // 官方 API 返回数组，兼容内部 API 返回对象
      List<Email> list;
      if (data is List) {
        list = data
            .map((e) => Email.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (data is Map<String, dynamic>) {
        final rawList = data['list'] as List? ?? [];
        list = rawList
            .map((e) => Email.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        list = [];
      }
      return EmailListResult(
        list: list,
        total: list.length,
        latestEmail: list.isNotEmpty ? list.first : null,
      );
    });
  }

  Future<ApiResponse<List<Email>>> getLatestEmail({
    int? accountId,
    int type = 0,
    int? allReceive,
  }) async {
    final params = <String, String>{};
    if (accountId != null) params['accountId'] = accountId.toString();
    params['type'] = type.toString();
    if (allReceive != null) params['allReceive'] = allReceive.toString();

    final uri = Uri.parse(_url('/email/latest')).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);

    return _parseResponse<List<Email>>(response, (data) {
      return (data as List).map((e) => Email.fromJson(e)).toList();
    });
  }

  Future<ApiResponse> deleteEmails(String emailIds) async {
    final uri = Uri.parse(_url('/email/delete'))
        .replace(queryParameters: {'emailIds': emailIds});
    final response = await http.delete(uri, headers: _headers);
    return _parseResponse(response, null);
  }

  Future<ApiResponse> markAsRead(List<int> emailIds) async {
    final response = await http.put(
      Uri.parse(_url('/email/read')),
      headers: _headers,
      body: jsonEncode({'emailIds': emailIds.join(',')}),
    );
    return _parseResponse(response, null);
  }

  Future<ApiResponse<List<Email>>> sendEmail({
    required int accountId,
    required List<String> receiveEmail,
    required String subject,
    required String content,
    String? text,
    String? name,
    String sendType = 'new',
    int? emailId,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final body = {
      'accountId': accountId,
      'receiveEmail': receiveEmail,
      'subject': subject,
      'content': content,
      if (text != null) 'text': text,
      if (name != null) 'name': name,
      'sendType': sendType,
      if (emailId != null) 'emailId': emailId,
      if (attachments != null) 'attachments': attachments,
    };

    final response = await http.post(
      Uri.parse(_url('/email/send')),
      headers: _headers,
      body: jsonEncode(body),
    );

    return _parseResponse<List<Email>>(response, (data) {
      return (data as List).map((e) => Email.fromJson(e)).toList();
    });
  }

  Future<ApiResponse<List<Attachment>>> getAttachmentList(int emailId) async {
    final uri = Uri.parse(_url('/email/attList'))
        .replace(queryParameters: {'emailId': emailId.toString()});
    final response = await http.get(uri, headers: _headers);

    return _parseResponse<List<Attachment>>(response, (data) {
      return (data as List).map((e) => Attachment.fromJson(e)).toList();
    });
  }

  Future<ApiResponse> addStar(int emailId) async {
    final response = await http.post(
      Uri.parse(_url('/star/add')),
      headers: _headers,
      body: jsonEncode({'emailId': emailId}),
    );
    return _parseResponse(response, null);
  }

  Future<ApiResponse> cancelStar(int emailId) async {
    final uri = Uri.parse(_url('/star/cancel'))
        .replace(queryParameters: {'emailId': emailId.toString()});
    final response = await http.delete(uri, headers: _headers);
    return _parseResponse(response, null);
  }

  Future<ApiResponse<List<Email>>> getStarList({
    int size = 20,
    int? emailId,
  }) async {
    final params = <String, String>{
      'size': size.toString(),
      if (emailId != null) 'emailId': emailId.toString(),
    };
    final uri = Uri.parse(_url('/star/list')).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);

    return _parseResponse<List<Email>>(response, (data) {
      return (data as List).map((e) => Email.fromJson(e)).toList();
    });
  }

  Future<ApiResponse<List<Account>>> getAccountList() async {
    final response = await http.get(
      Uri.parse(_url('/account/list')),
      headers: _headers,
    );

    return _parseResponse<List<Account>>(response, (data) {
      return (data as List).map((e) => Account.fromJson(e)).toList();
    });
  }

  Future<ApiResponse<Account>> addAccount(String email, {String? password}) async {
    final response = await http.post(
      Uri.parse(_url('/account/add')),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        if (password != null) 'password': password,
      }),
    );

    return _parseResponse<Account>(response, (data) => Account.fromJson(data));
  }

  Future<ApiResponse> deleteAccount(int accountId) async {
    final uri = Uri.parse(_url('/account/delete'))
        .replace(queryParameters: {'accountId': accountId.toString()});
    final response = await http.delete(uri, headers: _headers);
    return _parseResponse(response, null);
  }

  Future<ApiResponse> setAccountName(int accountId, String name) async {
    final response = await http.put(
      Uri.parse(_url('/account/setName')),
      headers: _headers,
      body: jsonEncode({'accountId': accountId, 'name': name}),
    );
    return _parseResponse(response, null);
  }

  Future<ApiResponse> setAccountAsTop(int accountId) async {
    final response = await http.put(
      Uri.parse(_url('/account/setAsTop')),
      headers: _headers,
      body: jsonEncode({'accountId': accountId}),
    );
    return _parseResponse(response, null);
  }

  Future<ApiResponse> logout() async {
    final response = await http.delete(
      Uri.parse(_url('/logout')),
      headers: _headers,
    );
    return _parseResponse(response, null);
  }
}
