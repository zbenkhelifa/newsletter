import 'dart:convert';

class SmtpConfig {
  String host;
  int port;
  String username;
  String password;
  String senderName;
  bool useTls;

  SmtpConfig({
    this.host = '',
    this.port = 587,
    this.username = '',
    this.password = '',
    this.senderName = '',
    this.useTls = true,
  });

  factory SmtpConfig.fromJson(Map<String, dynamic> j) => SmtpConfig(
        host: j['host'] ?? '',
        port: j['port'] ?? 587,
        username: j['username'] ?? '',
        password: j['password'] ?? '',
        senderName: j['senderName'] ?? '',
        useTls: j['useTls'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'senderName': senderName,
        'useTls': useTls,
      };

  String toJsonString() => jsonEncode(toJson());

  bool get isConfigured =>
      host.isNotEmpty && username.isNotEmpty && password.isNotEmpty;
}
