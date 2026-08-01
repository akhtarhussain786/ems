import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/dept_nav_helper.dart';
import 'login_screen.dart';
import 'attendance_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'leave_management_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _userData;
  bool _loading = true;
  String? _profileImagePath;
  List<DeptFeature> _features = [];
  int _unreadCount = 0;
  String _currentTime = '';
  Timer? _timer;
  Timer? _attendanceTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late PageController _pageController;

  // Value Notifiers for real-time updates
  final ValueNotifier<String> _attendanceDurationNotifier = ValueNotifier<String>('00:00:00');
  final ValueNotifier<bool> _isTrackingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _currentTimeNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> _greetingNotifier = ValueNotifier<String>('');

  DateTime? _checkInTime;
  String _checkInStatus = 'Not Checked In';
  Map<String, dynamic>? _todayAttendance;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: 0);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Initialize notifiers with current values
    final now = DateTime.now();
    final hour = now.hour;
    String initialGreeting;
    if (hour < 12) initialGreeting = 'Good Morning';
    else if (hour < 17) initialGreeting = 'Good Afternoon';
    else initialGreeting = 'Good Evening';
    _greetingNotifier.value = initialGreeting;

    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    _currentTimeNotifier.value = '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} $amPm';

    _initializeData();
    _loadProfileImage();
    _startTimeUpdate();
    _animationController.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAttendanceStatus();
    }
  }

  void _refreshAttendanceStatus() {
    if (_checkInTime != null && _isTrackingNotifier.value) {
      _updateAttendanceDuration();
      _startAttendanceTimer();
    }
  }

  void _startTimeUpdate() {
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
      if (_isTrackingNotifier.value && _checkInTime != null) {
        _updateAttendanceDuration();
      }
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final newTime = '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} $amPm';

    final hour = now.hour;
    String newGreeting;
    if (hour < 12) newGreeting = 'Good Morning';
    else if (hour < 17) newGreeting = 'Good Afternoon';
    else newGreeting = 'Good Evening';

    if (_currentTimeNotifier.value != newTime) {
      _currentTimeNotifier.value = newTime;
    }
    if (_greetingNotifier.value != newGreeting) {
      _greetingNotifier.value = newGreeting;
    }

    if (mounted) {
      setState(() {
        _currentTime = newTime;
      });
    }
  }

  void _updateAttendanceDuration() {
    if (_checkInTime != null && _isTrackingNotifier.value) {
      final duration = DateTime.now().difference(_checkInTime!);
      final hours = duration.inHours.toString().padLeft(2, '0');
      final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      final newDuration = '$hours:$minutes:$seconds';

      if (_attendanceDurationNotifier.value != newDuration) {
        _attendanceDurationNotifier.value = newDuration;
      }
    }
  }

  void _checkAttendanceStatus() {
    if (_dashboardData == null) return;

    _todayAttendance = _dashboardData?['today_attendance'];
    final checkIn = _todayAttendance?['check_in'];
    final checkOut = _todayAttendance?['check_out'];

    if (checkOut != null && checkOut.toString().isNotEmpty) {
      _isTrackingNotifier.value = false;
      _checkInTime = null;
      _checkInStatus = 'Checked Out';
      _attendanceDurationNotifier.value = '00:00:00';
      _attendanceTimer?.cancel();
      return;
    }

    if (checkIn != null && checkIn.toString().isNotEmpty) {
      try {
        _checkInTime = DateTime.parse(checkIn);
        _isTrackingNotifier.value = true;
        _checkInStatus = 'Working';
        _updateAttendanceDuration();
        _startAttendanceTimer();
      } catch (e) {
        _isTrackingNotifier.value = false;
        _attendanceDurationNotifier.value = '00:00:00';
        _checkInStatus = 'Not Checked In';
      }
    } else {
      _isTrackingNotifier.value = false;
      _attendanceDurationNotifier.value = '00:00:00';
      _checkInStatus = 'Not Checked In';
    }
  }

  void _startAttendanceTimer() {
    _attendanceTimer?.cancel();
    _attendanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_checkInTime != null && _isTrackingNotifier.value) {
        _updateAttendanceDuration();
      } else {
        _attendanceTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _attendanceTimer?.cancel();
    _attendanceDurationNotifier.dispose();
    _isTrackingNotifier.dispose();
    _currentTimeNotifier.dispose();
    _greetingNotifier.dispose();
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    await _fetchDashboard();
    await _fetchUnreadCount();
    if (mounted) {
      setState(() {
        _loading = false;
      });
      _checkAttendanceStatus();
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_path');
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _profileImagePath = imagePath;
          });
        }
      }
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.userKey);
    if (userJson != null) {
      final data = jsonDecode(userJson);
      if (mounted) {
        setState(() {
          _userData = data;
          final roleName = data['role_name'] ?? data['role'] ?? '';
          final deptName = data['department_name'] ?? '';
          _features = DeptNavHelper.getFeaturesForRole(roleName, deptName);
        });
      }
    }
  }

  Future<void> _fetchDashboard() async {
    try {
      final response = await ApiService().getEmployeeDashboard();
      if (mounted && response['success'] == true) {
        setState(() {
          _dashboardData = response['data'];
        });
      }
    } catch (e) {
      // Silently handle error
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await ApiService().getUnreadCount();
      if (mounted && res['success'] == true) {
        setState(() => _unreadCount = res['count'] ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.grey[50],
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF1E3A5F),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text('Logout'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );

    if (shouldLogout == true) {
      await ApiService().clearToken();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _navigateToAttendance(bool checkIn) async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScreen(checkIn: checkIn),
      ),
    );
    if (result == true && mounted) {
      await _fetchDashboard();
      _checkAttendanceStatus();
      if (!_isTrackingNotifier.value) {
        _attendanceDurationNotifier.value = '00:00:00';
      }
    }
  }

  void _openFeature(DeptFeature feature) {
    HapticFeedback.selectionClick();
    final screen = DeptNavHelper.buildFeatureScreen(feature);
    if (screen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    } else {
      _showFeatureNotAvailable(feature);
    }
  }

  void _showFeatureNotAvailable(DeptFeature feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              DeptNavHelper.getFeatureIcon(feature),
              color: const Color(0xFF1E3A5F),
            ),
            const SizedBox(width: 12),
            Text(
              DeptNavHelper.getFeatureLabel(feature),
              style: const TextStyle(color: Color(0xFF1E3A5F)),
            ),
          ],
        ),
        content: const Text(
          'This feature is coming soon. We are working on it!',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF1E3A5F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulesGrid() {
    if (_features.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: const Text(
            'Modules',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.apps_rounded,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 12),
              Text(
                'No modules available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact admin for access',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'Modules',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: _features.length,
        itemBuilder: (_, i) => _buildPremiumModuleCard(_features[i]),
      ),
    );
  }

  Widget _buildPremiumModuleCard(DeptFeature feature) {
    return GestureDetector(
      onTap: () => _openFeature(feature),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFF1E3A5F).withOpacity(0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                DeptNavHelper.getFeatureIcon(feature),
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                DeptNavHelper.getFeatureLabel(feature),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleChips() {
    if (_features.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text(
            'No modules available',
            style: TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.apps_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Quick Modules',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _features.map((f) {
              return GestureDetector(
                onTap: () => _openFeature(f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E3A5F).withOpacity(0.08),
                        const Color(0xFF1E3A5F).withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF1E3A5F).withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        DeptNavHelper.getFeatureIcon(f),
                        size: 14,
                        color: const Color(0xFF1E3A5F),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DeptNavHelper.getFeatureLabel(f),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.5,
              strokeCap: StrokeCap.round,
            ),
          ),
        ),
      );
    }

    _pages.clear();
    _pages.add(_buildDashboard());
    _pages.add(const AttendanceScreen());
    _pages.add(_buildModulesGrid());
    _pages.add(ProfileScreen(
      userData: _userData,
      profileImagePath: _profileImagePath,
      onImageUpdated: (newPath) {
        setState(() {
          _profileImagePath = newPath;
        });
      },
    ));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        children: _pages,
      ),
      bottomNavigationBar: _buildPremiumBottomNav(),
    );
  }

  Widget _buildPremiumBottomNav() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.4),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPremiumNavItem(Icons.dashboard_rounded, 'Home', 0),
              _buildPremiumNavItem(Icons.fingerprint, 'Attendance', 1),
              _buildPremiumNavItem(Icons.apps_rounded, 'Modules', 2),
              _buildPremiumNavItem(Icons.person_rounded, 'Profile', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
        _animationController.reset();
        _animationController.forward();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
              : null,
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
              size: isSelected ? 24 : 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: child,
                  );
                },
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final today = _dashboardData?['today_attendance'];
    final stats = _dashboardData?['monthly_stats'];
    final employee = _dashboardData?['employee'];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(),
      body: RefreshIndicator(
        onRefresh: _fetchDashboard,
        color: const Color(0xFF1E3A5F),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const SizedBox(height: 4),
                _buildReactiveGreetingCard(),
                const SizedBox(height: 12),
                _buildGlassEmployeeCard(employee),
                const SizedBox(height: 12),
                _buildAttendanceCardWithNotifier(today),
                const SizedBox(height: 12),
                if (stats != null) _buildAnimatedStatsCard(stats),
                const SizedBox(height: 12),
                if (_dashboardData?['leave_pending'] != null)
                  _buildLeaveStatusCard(_dashboardData!),
                const SizedBox(height: 12),
                if (_dashboardData?['total_leads'] != null)
                  _buildRoleStats(_dashboardData!, ['total_leads', 'today_leads', 'monthly_leads', 'converted_leads'], ['Total', 'Today', 'Monthly', 'Won'], [Colors.blue, Colors.orange, Colors.purple, Colors.green]),
                const SizedBox(height: 12),
                if (_dashboardData?['assigned_leads'] != null)
                  _buildRoleStats(_dashboardData!, ['assigned_leads', 'today_calls', 'pending_followups', 'converted_leads'], ['Assigned', "Today's Calls", 'Pending', 'Converted'], [Colors.blue, Colors.orange, Colors.red, Colors.green]),
                const SizedBox(height: 12),
                if (_dashboardData?['pending_leaves'] != null)
                  _buildLeavePendingCard(_dashboardData!['pending_leaves']),
                const SizedBox(height: 12),
                _buildModuleChips(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlassAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A5F),
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 70,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/logo25.png',
            height: 200,
            width: 200,
            fit: BoxFit.contain,
          ),
        ],
      ),
      actions: [
        Stack(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationScreen())
                  ).then((_) => _fetchUnreadCount());
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(),
              ),
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red, Colors.redAccent],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _logout();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.white, Colors.white70],
                    ),
                    image: _profileImagePath != null
                        ? DecorationImage(
                      image: FileImage(File(_profileImagePath!)),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: _profileImagePath == null
                      ? Center(
                    child: Text(
                      _userData?['name']?.isNotEmpty == true
                          ? _userData!['name'][0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.logout_rounded,
                  color: Colors.white.withOpacity(0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      centerTitle: true,
    );
  }

  // REACTIVE GREETING CARD
  Widget _buildReactiveGreetingCard() {
    final name = _userData?['name'] ?? 'Employee';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder(
                  valueListenable: _greetingNotifier,
                  builder: (context, greeting, child) {
                    return Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder(
                  valueListenable: _currentTimeNotifier,
                  builder: (context, time, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: Colors.white70,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  // ATTENDANCE CARD WITH NOTIFIERS
  Widget _buildAttendanceCardWithNotifier(Map<String, dynamic>? today) {
    final checkIn = today?['check_in'];
    final checkOut = today?['check_out'];
    final isCheckedIn = checkIn != null && checkIn.toString().isNotEmpty;
    final isCheckedOut = checkOut != null && checkOut.toString().isNotEmpty;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isCheckedOut) {
      statusText = 'Checked Out';
      statusColor = Colors.grey;
      statusIcon = Icons.check_circle_rounded;
    } else if (isCheckedIn) {
      statusText = 'Working';
      statusColor = Colors.green;
      statusIcon = Icons.timer_rounded;
    } else {
      statusText = 'Not Marked';
      statusColor = Colors.grey;
      statusIcon = Icons.circle_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Today's Attendance",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      statusIcon,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // LIVE TIMER
          ValueListenableBuilder(
            valueListenable: _attendanceDurationNotifier,
            builder: (context, duration, child) {
              return ValueListenableBuilder(
                valueListenable: _isTrackingNotifier,
                builder: (context, isTracking, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          isTracking ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          isTracking ? Colors.green.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isTracking ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isTracking ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.timer_rounded,
                            color: isTracking ? Colors.green : Colors.grey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTracking ? '🟢 Working Hours' : '⏹️ Not Checked In',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isTracking ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              duration,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isTracking ? const Color(0xFF1E3A5F) : Colors.grey,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildAttendButton(
                  'Check In',
                  Helpers.formatTime(checkIn),
                  Icons.login_rounded,
                  Colors.blue,
                  isCheckedIn && !isCheckedOut,
                  onTap: () => _navigateToAttendance(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAttendButton(
                  'Check Out',
                  Helpers.formatTime(checkOut),
                  Icons.logout_rounded,
                  Colors.orange,
                  isCheckedOut,
                  onTap: () => _navigateToAttendance(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendButton(
      String label,
      String? time,
      IconData icon,
      Color color,
      bool isCompleted, {
        required VoidCallback onTap,
      }) {
    bool isDisabled = false;
    if (label == 'Check In' && isCompleted) {
      isDisabled = true;
    }
    if (label == 'Check Out' && isCompleted) {
      isDisabled = true;
    }
    if (label == 'Check Out' && !_isTrackingNotifier.value && !isCompleted) {
      isDisabled = true;
    }

    return GestureDetector(
      onTap: isDisabled ? null : () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isCompleted
                ? LinearGradient(
              colors: [color, color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCompleted ? color : color.withOpacity(0.3),
              width: isCompleted ? 0 : 1.5,
            ),
            boxShadow: isCompleted
                ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
                : null,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isCompleted ? Colors.white : color,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? Colors.white : color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                time ?? (label == 'Check In' ? 'Tap to start' : 'Tap to end'),
                style: TextStyle(
                  fontSize: 10,
                  color: isCompleted ? Colors.white70 : color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassEmployeeCard(Map<String, dynamic>? emp) {
    final name = emp?['first_name'] ?? _userData?['name'] ?? 'Employee';
    final code = emp?['employee_code'] ?? _userData?['employee_code'] ?? '';
    final dept = emp?['department_name'] ?? _userData?['department_name'] ?? '';
    final desig = emp?['designation_name'] ?? '';

    File? profileImage;
    if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
      final file = File(_profileImagePath!);
      if (file.existsSync()) {
        profileImage = file;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
              ),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                shape: BoxShape.circle,
                image: profileImage != null
                    ? DecorationImage(
                  image: FileImage(profileImage!),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: profileImage == null
                  ? Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ID: $code',
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (dept.isNotEmpty)
                      _buildChip(dept, const Color(0xFF1E3A5F)),
                    if (desig.isNotEmpty)
                      _buildChip(desig, Colors.green),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAnimatedStatsCard(Map<String, dynamic> stats) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.purple, Colors.purpleAccent],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Monthly Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildAnimatedStatItem('Present', '${stats['present_days'] ?? 0}', Icons.check_circle_rounded, Colors.green),
                      _buildAnimatedStatItem('Late', '${stats['late_days'] ?? 0}', Icons.warning_rounded, Colors.orange),
                      _buildAnimatedStatItem('Half Day', '${stats['half_days'] ?? 0}', Icons.hourglass_bottom_rounded, Colors.purple),
                      _buildAnimatedStatItem('Absent', '${stats['absent_days'] ?? 0}', Icons.cancel_rounded, Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedStatItem(String label, String count, IconData icon, Color color) {
    final intValue = int.tryParse(count) ?? 0;
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: intValue.toDouble()),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.toInt().toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoleStats(Map<String, dynamic> data, List<String> keys, List<String> labels, List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.teal, Colors.tealAccent],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              keys.length,
                  (i) => _buildAnimatedStatItem(labels[i], '${data[keys[i]] ?? 0}', Icons.circle_rounded, colors[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveStatusCard(Map<String, dynamic> data) {
    final last = data['last_leave'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.deepOrange],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Leave Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text(
                  'View All',
                  style: TextStyle(fontSize: 11),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveManagementScreen())),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: const Size(0, 32),
                  backgroundColor: const Color(0xFF1E3A5F).withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAnimatedStatItem('Pending', '${data['leave_pending'] ?? 0}', Icons.hourglass_top_rounded, Colors.orange),
              _buildAnimatedStatItem('Approved', '${data['leave_approved'] ?? 0}', Icons.check_circle_rounded, Colors.green),
              _buildAnimatedStatItem('Rejected', '${data['leave_rejected'] ?? 0}', Icons.cancel_rounded, Colors.red),
            ],
          ),
          if (last != null) ...[
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last: ${last['leave_type']} (${last['status']})',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeavePendingCard(int count) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.orange, Colors.deepOrange],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.event_rounded, color: Colors.white, size: 18),
        ),
        title: Text(
          '$count Pending Leave Requests',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1E3A5F),
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveManagementScreen())),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A5F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            minimumSize: const Size(0, 32),
          ),
          child: const Text(
            'View',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}