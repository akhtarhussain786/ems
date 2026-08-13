import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize FCM Push Notification Service
  try {
    await FCMService().initialize();
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const EAMSApp());
}

class EAMSApp extends StatelessWidget {
  const EAMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yatharth Connect',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E3A5F),
        useMaterial3: true,

        // ✅ Scaffold background color
        scaffoldBackgroundColor: const Color(0xFF1E3A5F),

        // Custom Font Full App Me Apply
        textTheme: GoogleFonts.bricolageGrotesqueTextTheme(),

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),

        cardTheme: const CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),

        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}