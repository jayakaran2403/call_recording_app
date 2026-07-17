import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await ref
          .read(authProvider.notifier)
          .restoreSession()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Fall through to login rather than hanging forever.
    }
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final loggedIn = ref.read(authProvider).isLoggedIn;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => loggedIn ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.mic, size: 48, color: AppTheme.primaryBlue),
            ),
            const SizedBox(height: 24),
            const Text(
              'Employee Call Recorder',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'HAB Business Solutions',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
