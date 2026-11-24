import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'features/auth/login_page.dart';
import 'features/connection/home_page.dart';

/// App root: Material 3 with the phase-3 design tokens, routed by auth
/// state (login page when logged out, home shell when logged in).
class ZgltApp extends ConsumerStatefulWidget {
  const ZgltApp({super.key});

  @override
  ConsumerState<ZgltApp> createState() => _ZgltAppState();
}

class _ZgltAppState extends ConsumerState<ZgltApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final themeMode = ref.watch(
      settingsControllerProvider.select((s) => s.themeMode),
    );
    final textTheme = Theme.of(context).textTheme;
    final Widget home;
    if (auth.isLoggedIn) {
      home = const HomePage();
    } else if (auth.isLoading) {
      home = Scaffold(
        body: Center(child: Text('加载中…', style: textTheme.bodySmall)),
      );
    } else {
      home = const LoginPage();
    }
    return MaterialApp(
      title: 'ZGLTVPN',
      theme: ZgltTheme.light,
      darkTheme: ZgltTheme.dark,
      themeMode: themeMode.materialThemeMode,
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}
