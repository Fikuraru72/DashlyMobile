import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'theme/dashly_theme.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/main_navigation.dart';
import 'providers/event_provider.dart';
import 'providers/event_list_provider.dart';
import 'providers/tracking_provider.dart';
import 'providers/theme_provider.dart';

import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await GoogleSignIn.instance.initialize(
      serverClientId: '745065676377-v07ifm34ht64l2l0r9ga9if51pnj6i6u.apps.googleusercontent.com',
    );
  } catch (e) {
    debugPrint('GoogleSignIn initialization failed: $e');
  }

  runApp(const DashlyApp());
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class DashlyApp extends StatelessWidget {
  const DashlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => EventListProvider()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Eco Race Maps',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            theme: DashlyTheme.lightTheme,
            darkTheme: DashlyTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/home': (_) => const MainNavigation(),
            },
          );
        },
      ),
    );
  }
}
