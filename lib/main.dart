import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utils/storage.dart';
import 'utils/theme.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/email/mailbox_screen.dart';
import 'screens/email/email_detail_screen.dart';
import 'screens/email/compose_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/accounts/account_screen.dart';
import 'screens/ai/ai_screen.dart';
import 'screens/contacts/contacts_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider()..init(),
      child: const CloudMailApp(),
    ),
  );
}

class CloudMailApp extends StatelessWidget {
  const CloudMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Cloud Mail',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.resolve(
        themeProvider.uiStyle,
        Brightness.light,
        customPrimary: themeProvider.customPrimaryColor,
        fontFamily: themeProvider.customFontFamily,
      ),
      darkTheme: AppTheme.resolve(
        themeProvider.uiStyle,
        Brightness.dark,
        customPrimary: themeProvider.customPrimaryColor,
        fontFamily: themeProvider.customFontFamily,
      ),
      themeMode: themeProvider.themeMode,
      home: const _AuthChecker(),
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/compose':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (ctx) => ComposeScreen(
                api: args?['api'] as CloudMailApi,
                replyEmail: args?['replyEmail'],
                forwardEmail: args?['forwardEmail'],
              ),
            );
          case '/detail':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (ctx) => EmailDetailScreen(
                email: args?['email'],
                api: args?['api'] as CloudMailApi,
              ),
            );
          case '/ai':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (ctx) => AiScreen(
                api: args?['api'] as CloudMailApi,
              ),
            );
          case '/contacts':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (ctx) => ContactsScreen(
                api: args?['api'] as CloudMailApi,
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}

class _AuthChecker extends StatelessWidget {
  const _AuthChecker();

  @override
  Widget build(BuildContext context) {
    final token = StorageService.token;
    final baseUrl = StorageService.baseUrl;

    if (token != null && baseUrl != null && token.isNotEmpty && baseUrl.isNotEmpty) {
      final api = CloudMailApi(baseUrl, token: token);
      return MailboxScreen(api: api);
    }

    return const LoginScreen();
  }
}
