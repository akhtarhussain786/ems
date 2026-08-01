import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

        // ✅ ADD THIS - Extra safety for white flash
        scaffoldBackgroundColor: const Color(0xFF1E3A5F),

        // Custom Font Full App Me Apply
        textTheme: GoogleFonts.bricolageGrotesqueTextTheme(),

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),

        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
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