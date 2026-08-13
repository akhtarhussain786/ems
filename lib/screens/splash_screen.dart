import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_manager.dart';
import '../utils/constants.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // ✅ Animation Controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // ✅ Scale Animation (Pulse effect)
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // ✅ Fade Animation for loading dots
    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // ✅ Navigate after delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(AppConstants.rememberKey) ?? false;

    // A stored token is not the same as a valid one — check the expiry before
    // trusting it, and tear the session down if it has already lapsed.
    final validSession = await SessionManager.instance.hasValidSession();
    if (!validSession && SessionManager.instance.hasToken) {
      await SessionManager.instance.clear();
      await prefs.setBool(AppConstants.autoLogoutFlagKey, true);
      await prefs.setString(
        AppConstants.autoLogoutReasonKey,
        'Session expired. Please login again.',
      );
    }

    // "Remember me" off means the session must not outlive the app. Without
    // this the token stayed on disk, still valid, until it expired on its own.
    if (!remember && SessionManager.instance.hasToken) {
      await SessionManager.instance.clear();
    }

    if (!mounted) return;

    if (validSession && remember) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
          const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
          const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ Animated Logo with Pulse Effect
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 5,
                          blurRadius: 15,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 180,
                      width: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            Text(
              'Yatharth Connect',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Employee Attendance System',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 14,
                color: Colors.black54,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 40),
            // ✅ Custom Loading Animation
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLoadingDot(0),
                const SizedBox(width: 12),
                _buildLoadingDot(1),
                const SizedBox(width: 12),
                _buildLoadingDot(2),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              'v1.0.0',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 12,
                color: Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDot(int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        double delay = index * 0.3;
        double value = (_animationController.value - delay) % 1.0;
        if (value < 0) value += 1.0;

        double opacity = (value < 0.5) ? value * 2 : (1 - value) * 2;
        double size = 12 + (opacity * 8);

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade700.withOpacity(0.6 + (opacity * 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(opacity * 0.3),
                spreadRadius: 2,
                blurRadius: 8,
              ),
            ],
          ),
        );
      },
    );
  }
}