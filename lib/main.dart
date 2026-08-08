import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/session_manager.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionManager.instance.load();
  runApp(const EAMSApp());
}

class EAMSApp extends StatelessWidget {
  const EAMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yatharth Connect',
      debugShowCheckedModeBanner: false,

      // Lets SessionManager route to login without a BuildContext
      navigatorKey: navigatorKey,
      routes: {
        AppConstants.loginRoute: (_) => const LoginScreen(),
      },

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