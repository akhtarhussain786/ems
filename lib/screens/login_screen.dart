import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _remember = false;
  bool _loading = false;
  bool _obscurePassword = true;

  // Auto-logout timer
  Timer? _autoLogoutTimer;
  static const Duration _autoLogoutDuration = Duration(hours: 12);

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkAndHandleAutoLogout();
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _passwordController.dispose();
    _autoLogoutTimer?.cancel();
    super.dispose();
  }

  // Check if user was auto-logged out and show message
  void _checkAndHandleAutoLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final wasAutoLogout = prefs.getBool('was_auto_logout') ?? false;

    if (wasAutoLogout) {
      await prefs.remove('was_auto_logout');
      if (mounted) {
        _showInfo('🔐 Session expired. Please login again for security.');
      }
    }
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    // Load saved employee ID
    final savedId = prefs.getString(AppConstants.savedEmployeeIdKey);
    if (savedId != null) {
      _employeeIdController.text = savedId;
    }

    // Load saved password if remember me was checked
    final savedPassword = prefs.getString('saved_password');
    if (savedPassword != null) {
      _passwordController.text = savedPassword;
    }

    // Load remember me status
    final remember = prefs.getBool(AppConstants.rememberKey) ?? false;
    setState(() {
      _remember = remember;
    });
  }

  Future<bool> _checkInternet() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _showError('⚠️ No Internet Connection');
        return false;
      }
      return true;
    } catch (e) {
      _showError('⚠️ Internet Check Failed');
      return false;
    }
  }

  Future<void> _login() async {
    final employeeId = _employeeIdController.text.trim();
    final password = _passwordController.text;

    if (employeeId.isEmpty || password.isEmpty) {
      _showError('Please enter Employee ID and Password');
      return;
    }

    bool hasInternet = await _checkInternet();
    if (!hasInternet) return;

    setState(() => _loading = true);

    try {
      final response = await ApiService().login(employeeId, password, remember: _remember);

      if (!mounted) return;

      if (response['success'] == true) {
        String token = '';
        Map<String, dynamic> userData = {};

        if (response['data'] is Map) {
          token = response['data']?['token'] ?? '';
          userData = (response['data']?['user'] is Map)
              ? Map<String, dynamic>.from(response['data']!['user'])
              : {};
        }

        if (token.isEmpty && response['token'] is String) {
          token = response['token'] ?? '';
        }
        if (userData.isEmpty && response['user'] is Map) {
          userData = Map<String, dynamic>.from(response['user']);
        }

        if (token.isEmpty) {
          _showError('⚠️ No token received. Please try again.');
          setState(() => _loading = false);
          return;
        }

        await ApiService().setToken(token);

        final prefs = await SharedPreferences.getInstance();

        // ✅ Save credentials if remember me is checked
        if (_remember) {
          await prefs.setString(AppConstants.savedEmployeeIdKey, employeeId);
          await prefs.setString('saved_password', password);
          await prefs.setBool(AppConstants.rememberKey, true);
        } else {
          await prefs.remove(AppConstants.savedEmployeeIdKey);
          await prefs.remove('saved_password');
          await prefs.setBool(AppConstants.rememberKey, false);
        }

        await prefs.setString(AppConstants.userKey, jsonEncode(userData));
        await prefs.setString('login_timestamp', DateTime.now().toIso8601String());
        await prefs.remove('was_auto_logout');

        // ✅ Start auto-logout timer
        _startAutoLogoutTimer();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        _showError(response['message'] ?? 'Invalid credentials');
      }
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        _showError('❌ Server not found!\nCheck if backend is running');
      } else if (e.toString().contains('TimeoutException')) {
        _showError('❌ Server timeout!\nCheck your connection');
      } else if (e.toString().contains('Connection refused')) {
        _showError('❌ Connection refused!\nServer not running');
      } else {
        _showError('❌ Error: ${e.toString().substring(0, 100)}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startAutoLogoutTimer() {
    _autoLogoutTimer?.cancel();
    _autoLogoutTimer = Timer(_autoLogoutDuration, () {
      _performAutoLogout();
    });
  }

  Future<void> _performAutoLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('was_auto_logout', true);
      await ApiService().clearToken();
      await prefs.remove(AppConstants.userKey);
      await prefs.remove('login_timestamp');

      if (mounted) {
        _showInfo('🔐 Auto-logged out after 12 hours for security.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      // Silent error handling
    }
  }

  void _refreshAutoLogoutTimer() {
    _autoLogoutTimer?.cancel();
    _startAutoLogoutTimer();
  }

  void _onUserInteraction() {
    _refreshAutoLogoutTimer();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        duration: const Duration(seconds: 3),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        duration: const Duration(seconds: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  void _showInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.blue.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        duration: const Duration(seconds: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: size.width > 400 ? 40 : 24,
              vertical: 20,
            ),
            child: GestureDetector(
              onTap: _onUserInteraction,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✨ Animated Logo/Brand Section
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 30,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.08),
                            Colors.white.withOpacity(0.02),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.1),
                            blurRadius: 50,
                            spreadRadius: 10,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Logo - Size Increased
                          Container(

                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(90), // Increased from 55
                              child: Image.asset(
                                'assets/images/logo25.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blueAccent.withOpacity(0.3),
                                          Colors.purpleAccent.withOpacity(0.3),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.business_center,
                                      color: Colors.white,
                                      size: 80, // Increased from 50
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Animated gradient bar
                          Container(
                            width: 120,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blueAccent,
                                  Colors.cyanAccent,
                                  Colors.purpleAccent,
                                  Colors.blueAccent,
                                ],
                                stops: const [0.0, 0.3, 0.7, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // 👋 Welcome Text
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          'Welcome Back! 👋',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 20,
                                color: Colors.black38,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sign in to continue to your dashboard',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 🎴 Login Card
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1000),
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.10),
                            Colors.white.withOpacity(0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 50,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Login Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.blueAccent, Colors.blue],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueAccent.withOpacity(0.3),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.login_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Login Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blueAccent.withOpacity(0.2),
                                      Colors.purpleAccent.withOpacity(0.2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.shield_rounded,
                                      color: Colors.greenAccent.withOpacity(0.6),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Secure',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 📝 Employee ID Field
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _employeeIdController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              onTap: _onUserInteraction,
                              decoration: InputDecoration(
                                labelText: 'Employee ID',
                                hintText: 'Enter your employee ID',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 14,
                                ),
                                labelStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: Icon(
                                  Icons.badge_rounded,
                                  color: Colors.white.withOpacity(0.5),
                                  size: 22,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.blueAccent,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.text,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 🔒 Password Field
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              onTap: _onUserInteraction,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Enter your password',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 14,
                                ),
                                labelStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_rounded,
                                  color: Colors.white.withOpacity(0.5),
                                  size: 22,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: Colors.white.withOpacity(0.4),
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    _onUserInteraction();
                                    setState(
                                          () => _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.white.withOpacity(0.12),
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.blueAccent,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              onSubmitted: (_) => _login(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ✅ Remember Me & Forgot Password
                          Row(
                            children: [
                              // Custom checkbox
                              GestureDetector(
                                onTap: () {
                                  _onUserInteraction();
                                  setState(() => _remember = !_remember);
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: _remember
                                            ? Colors.blueAccent
                                            : Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _remember
                                              ? Colors.blueAccent
                                              : Colors.white.withOpacity(0.2),
                                          width: 2,
                                        ),
                                      ),
                                      child: _remember
                                          ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Remember me',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Flexible(
                                child: GestureDetector(
                                  onTap: () {
                                    _onUserInteraction();
                                    _showInfo('📞 Please contact admin for password reset assistance.');
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.orange.withOpacity(0.15),
                                          Colors.orange.withOpacity(0.05),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Forgot Password? Ask Admin',
                                            style: TextStyle(
                                              color: Colors.orange.withOpacity(0.8),
                                              fontSize: 8,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 🚀 Sign In Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: _loading
                                    ? null
                                    : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF1A73E8),
                                    Color(0xFF0D47A1),
                                  ],
                                ),
                                boxShadow: _loading
                                    ? null
                                    : [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.4),
                                    blurRadius: 30,
                                    spreadRadius: 3,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.2),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  disabledBackgroundColor:
                                  Colors.blueAccent.withOpacity(0.3),
                                ),
                                child: _loading
                                    ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                        valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Signing In...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                )
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Sign In',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 📱 Version & Footer
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Version 2.0.0',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.15),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '© 2026 Yatharth Group of Institutions',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.06),
                          fontSize: 10,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}