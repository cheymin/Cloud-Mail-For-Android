import 'package:flutter/material.dart';
import 'package:cloud_mail_app/utils/storage.dart';
import 'package:cloud_mail_app/screens/login_screen.dart';
import 'package:cloud_mail_app/screens/email_list_screen.dart';
import 'package:cloud_mail_app/services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  runApp(const CloudMailApp());
}

class CloudMailApp extends StatelessWidget {
  const CloudMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    final hasToken = StorageService.token != null &&
        StorageService.token!.isNotEmpty;
    final hasBaseUrl = StorageService.baseUrl != null &&
        StorageService.baseUrl!.isNotEmpty;

    Widget home;
    if (hasToken && hasBaseUrl) {
      final api = CloudMailApi(StorageService.baseUrl!);
      api.token = StorageService.token;
      home = EmailListScreen(api: api);
    } else {
      home = const LoginScreen();
    }

    return MaterialApp(
      title: 'Cloud Mail',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.grey.shade50,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A2E),
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: home,
    );
  }
}