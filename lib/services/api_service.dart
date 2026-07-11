import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_mail_app/models/email.dart';

class CloudMailApi {
  String baseUrl;
  String? _token;

  CloudMailApi(this.baseUrl);

  set token(String? t) => _token = t;
  String? get token => _token;

  Uri _buildUri(String path) {
    final url = baseUrl.endsWith('/') ? '${baseUrl}$path' : '$baseUrl/$path';
    return Uri.parse(url);
  }

  Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth && _token != null) {
      headers['Authorization'] = _token!;
    }
    return headers;
  }

  Future<ApiResponse<String>> generateToken(
      String email, String password) async {
    final uri = _buildUri('api/public/genToken');
    final body = jsonEncode({'email': email, 'password': password});

    final response = await http
        .post(uri, headers: _headers(), body: body)
        .timeout(const Duration(seconds: 30));

    final json = jsonDecode(response.body);
    return ApiResponse<String>(
      code: json['code'] ?? response.statusCode,
      message: json['message'] ?? response.reasonPhrase ?? 'Unknown error',
      data: json['data']?['token'],
    );
  }

  Future<ApiResponse<List<Email>>> getEmailList({
    String? toEmail,
    String? sendName,
    String? sendEmail,
    String? subject,
    String? content,
    String timeSort = 'desc',
    int? type,
    int? isDel,
    int num = 1,
    int size = 20,
  }) async {
    final uri = _buildUri('api/public/emailList');
    final body = <String, dynamic>{
      'num': num,
      'size': size,
      'timeSort': timeSort,
    };
    if (toEmail != null) body['toEmail'] = toEmail;
    if (sendName != null) body['sendName'] = sendName;
    if (sendEmail != null) body['sendEmail'] = sendEmail;
    if (subject != null) body['subject'] = subject;
    if (content != null) body['content'] = content;
    if (type != null) body['type'] = type;
    if (isDel != null) body['isDel'] = isDel;

    final response = await http
        .post(uri, headers: _headers(auth: true), body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));

    final json = jsonDecode(response.body);
    final dataList = (json['data'] as List?) ?? [];
    final emails = dataList.map((e) => Email.fromJson(e)).toList();

    return ApiResponse<List<Email>>(
      code: json['code'] ?? response.statusCode,
      message: json['message'] ?? response.reasonPhrase ?? '',
      data: emails,
    );
  }

  Future<ApiResponse<void>> addUser(List<UserInfo> users) async {
    final uri = _buildUri('api/public/addUser');
    final body = jsonEncode(
        {'list': users.map((u) => u.toJson()).toList()});

    final response = await http
        .post(uri, headers: _headers(auth: true), body: body)
        .timeout(const Duration(seconds: 30));

    final json = jsonDecode(response.body);
    return ApiResponse<void>(
      code: json['code'] ?? response.statusCode,
      message: json['message'] ?? response.reasonPhrase ?? '',
    );
  }
}