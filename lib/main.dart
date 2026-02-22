import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const TitanCastApp());
}

class TitanCastApp extends StatelessWidget {
  const TitanCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF8B5CF6);
    const Color deepBackground = Color(0xFF0A0A0E);
    const Color panelColor = Color(0xFF15151A);

    return MaterialApp(
      title: 'TitanCast',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: deepBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryPurple,
          brightness: Brightness.dark,
          surface: deepBackground,
          primary: primaryPurple,
        ),
        textTheme: Typography.material2021().white.copyWith(
          headlineMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
          titleLarge: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
          titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.15),
          bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
          labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        ),
        // Alt Navigasyon Barı Tasarımı
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: panelColor,
          indicatorColor: primaryPurple.withValues(alpha: 0.2),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8A8A93)),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: primaryPurple);
            }
            return const IconThemeData(color: Color(0xFF8A8A93));
          }),
        ),
      ),
      home: const AppShell(),
    );
  }
}