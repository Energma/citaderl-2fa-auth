import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/lock_screen.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CitadelApp()));
}

class CitadelApp extends ConsumerStatefulWidget {
  const CitadelApp({super.key});

  @override
  ConsumerState<CitadelApp> createState() => _CitadelAppState();
}

class _CitadelAppState extends ConsumerState<CitadelApp> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(vaultProvider.notifier).checkStatus());
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Citadel Auth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: !_splashDone
          ? SplashScreen(onComplete: () => setState(() => _splashDone = true))
          : switch (vault.status) {
              VaultStatus.uninitialized => const SetupScreen(),
              VaultStatus.locked => const LockScreen(),
              VaultStatus.unlocked => const HomeScreen(),
            },
    );
  }
}
