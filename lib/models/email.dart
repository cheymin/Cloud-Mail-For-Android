class Email {
  final int emailId;
  final String? sendEmail;
  final String? sendName;
  final String? subject;
  final String? toEmail;
  final String? toName;
  final String? createTime;
  final int type;
  final String? content;
  final String? text;
  final int isDel;

  Email({
    required this.emailId,
    this.sendEmail,
    this.sendName,
    this.subject,
    this.toEmail,
    this.toName,
    this.createTime,
    required this.type,
    this.content,
    this.text,
    required this.isDel,
  });

  factory Email.fromJson(Map<String, dynamic> json) {
    return Email(
      emailId: json['emailId'] ?? 0,
      sendEmail: json['sendEmail'],
      sendName: json['sendName'],
      subject: json['subject'],
      toEmail: json['toEmail'],
      toName: json['toName'],
      createTime: json['createTime'],
      type: json['type'] ?? 0,
      content: json['content'],
      text: json['text'],
      isDel: json['isDel'] ?? 0,
    );
  }
}

class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(
      Map<String, dynamic> json, T Function(dynamic)? dataParser) {
    return ApiResponse<T>(
      code: json['code'] ?? 0,
      message: json['message'] ?? '',
      data: json['data'] != null && dataParser != null
          ? dataParser(json['data'])
          : json['data'],
    );
  }
}

class UserInfo {
  final String email;
  final String? password;
  final String? roleName;

  UserInfo({
    required this.email,
    this.password,
    this.roleName,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'email': email};
    if (password != null) map['password'] = password;
    if (roleName != null) map['roleName'] = roleName;
    return map;
  }
}