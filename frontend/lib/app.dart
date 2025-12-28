import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/home_shell.dart';
import 'pages/login_page.dart';
import 'state/session.dart';
import 'theme.dart';

class OrderKioskApp extends ConsumerWidget {
  const OrderKioskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoApp(
      title: 'OrderKiosk',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      builder: (context, child) {
        final brightness = MediaQuery.platformBrightnessOf(context);
        return CupertinoTheme(data: buildTheme(brightness), child: child!);
      },
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends ConsumerWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (session.loading) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('OrderKiosk')),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (session.user == null) {
      return const LoginPage();
    }
    return const HomeShell();
  }
}
