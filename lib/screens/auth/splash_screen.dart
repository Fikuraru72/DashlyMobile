import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/dashly_theme.dart';
import 'login_screen.dart';
import '../main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final auth = context.read<AuthProvider>();

    // Give a small delay for UI effect
    await Future.delayed(const Duration(seconds: 2));

    try {
      final success = await auth.tryAutoLogin();
      if (success) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Session restore failed: $e');
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dashlyColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_run_rounded,
              size: 80,
              color: context.dashlyColors.accent,
            ),
            const SizedBox(height: 24),
            Text(
              "DASHLY",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: context.dashlyColors.textPrimary,
              ),
            ),
            const SizedBox(height: 40),
            CircularProgressIndicator(color: context.dashlyColors.accent),
          ],
        ),
      ),
    );
  }
}
