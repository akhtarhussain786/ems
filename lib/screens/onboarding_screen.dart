import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/onboarding_service.dart';
import 'home_screen.dart';

/// Premium First-Time Login Onboarding Flow for SaaS CRM & Attendance
///
/// Provides 4 interactive walkthrough screens with role-awareness,
/// smooth PageView navigation, animated pill progress indicators,
/// top-right Skip button, and seamless transition to HomeScreen.
class OnboardingScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const OnboardingScreen({super.key, this.userData});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _navigating = false;

  String get _userName {
    final name = widget.userData?['name']?.toString() ?? '';
    if (name.isNotEmpty) {
      return name.split(' ').first;
    }
    return '';
  }

  String get _userRole {
    final role = widget.userData?['role']?.toString().toLowerCase() ?? '';
    final dept = widget.userData?['department_name']?.toString().toLowerCase() ?? '';

    if (role.contains('admin') || role.contains('super_admin')) return 'Admin';
    if (role.contains('sales') || dept.contains('sales')) return 'Sales';
    if (role.contains('telecaller') || dept.contains('telecaller')) return 'Telecaller';
    if (role.contains('hr') || dept.contains('hr')) return 'HR';
    if (role.contains('manager') || dept.contains('manager')) return 'Manager';
    return 'Employee';
  }

  String? get _userId {
    final data = widget.userData;
    if (data == null) return null;
    return (data['id'] ?? data['user_id'] ?? data['employee_code'])?.toString();
  }

  List<_OnboardingData> _getPages() {
    final role = _userRole;
    final name = _userName;
    final welcomeGreeting = name.isNotEmpty ? 'Welcome, $name 👋' : 'Welcome 👋';

    return [
      _OnboardingData(
        badge: 'YATHARTH CONNECT',
        headline: welcomeGreeting,
        description: 'Manage your leads, follow-ups, attendance, and daily work from one powerful, synchronized workspace.',
        icon: Icons.dashboard_customize_rounded,
        accentColor: const Color(0xFF1E3A5F),
        gradientColors: const [Color(0xFF1E3A5F), Color(0xFF2A5298)],
        features: [
          'Unified CRM & Employee Workspace',
          'Instant Real-Time Synchronization',
          'Tailored for ${_getRoleBadgeText(role)}',
        ],
        illustrationWidget: _buildWelcomeIllustration(),
      ),
      _OnboardingData(
        badge: 'LEAD MANAGEMENT',
        headline: 'Never Lose a Lead',
        description: 'Create, assign, and track every lead from first contact to successful conversion with actionable insights.',
        icon: Icons.group_work_rounded,
        accentColor: const Color(0xFF0284C7),
        gradientColors: const [Color(0xFF0369A1), Color(0xFF38BDF8)],
        features: [
          'Full pipeline visibility & lead status',
          'Priority management (Low to Urgent)',
          'Instant team assignment & notifications',
          'Smart lead capture & history tracking',
        ],
        illustrationWidget: _buildLeadManagementIllustration(),
      ),
      _OnboardingData(
        badge: 'SMART FOLLOW-UPS',
        headline: 'Follow Up at the Right Time',
        description: 'Plan calls, meetings, and automated reminders so your team never misses an opportunity to close deals.',
        icon: Icons.notifications_active_rounded,
        accentColor: const Color(0xFF7C3AED),
        gradientColors: const [Color(0xFF6D28D9), Color(0xFFA78BFA)],
        features: [
          'Scheduled call logs & meeting reminders',
          'Quick follow-up presets (Today, Tomorrow)',
          'Actionable customer history & call notes',
          'Higher conversion with timely alerts',
        ],
        illustrationWidget: _buildFollowUpIllustration(),
      ),
      _OnboardingData(
        badge: 'MAXIMUM PRODUCTIVITY',
        headline: 'Everything in One Place',
        description: 'Track your tasks, work reports, check-ins, and performance from a simple, elegant CRM dashboard.',
        icon: Icons.rocket_launch_rounded,
        accentColor: const Color(0xFF059669),
        gradientColors: const [Color(0xFF047857), Color(0xFF34D399)],
        features: [
          'GPS & Face-verified smart attendance',
          'Daily work reports & task boards',
          'Performance metrics & activity logs',
          'Fast, reliable, and secure workflows',
        ],
        illustrationWidget: _buildProductivityIllustration(),
      ),
    ];
  }

  String _getRoleBadgeText(String role) {
    switch (role) {
      case 'Sales':
        return 'Sales Executives & Closers';
      case 'Telecaller':
        return 'Telecalling & Outreach Teams';
      case 'Manager':
      case 'Admin':
        return 'Team Leaders & Administrators';
      default:
        return 'Field & Office Professionals';
    }
  }

  Future<void> _finishOnboarding() async {
    if (_navigating) return;
    _navigating = true;
    HapticFeedback.mediumImpact();

    final userId = _userId;
    if (userId != null && userId.isNotEmpty) {
      await OnboardingService.setOnboardingCompleted(userId);
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _nextPage(int totalPages) {
    HapticFeedback.selectionClick();
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages();
    final isLastPage = _currentPage == pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Logo & Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E3A5F),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'STEP 0${_currentPage + 1} / 0${pages.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishOnboarding,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final data = pages[index];
                  return _buildPageContent(data);
                },
              ),
            ),

            // Bottom Navigation Area
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Row(
                children: [
                  // Progress Dots
                  Row(
                    children: List.generate(pages.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        height: 7,
                        width: isActive ? 24 : 7,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF1E3A5F)
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // CTA Button
                  ElevatedButton(
                    onPressed: () => _nextPage(pages.length),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLastPage ? 'Get Started' : 'Next',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          isLastPage ? Icons.arrow_forward_rounded : Icons.arrow_forward_ios_rounded,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(_OnboardingData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Illustration / Visual Card
          data.illustrationWidget,
          const SizedBox(height: 28),

          // Small Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: data.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data.badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: data.accentColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Main Headline
          Text(
            data.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle / Description
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // Feature Hints Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: data.features.map((f) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: data.accentColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: data.accentColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==================== ILLUSTRATION 1: WELCOME ====================
  Widget _buildWelcomeIllustration() {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background concentric circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Central Icon Composition
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.space_dashboard_rounded,
                  size: 46,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 14, color: Color(0xFF38BDF8)),
                    SizedBox(width: 6),
                    Text(
                      'Yatharth CRM Platform',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ILLUSTRATION 2: LEAD MANAGEMENT ====================
  Widget _buildLeadManagementIllustration() {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Floating pipeline pill cards
          Positioned(
            top: 24,
            left: 20,
            child: _buildFloatingTag('New Leads', Icons.fiber_new_rounded, const Color(0xFFF59E0B)),
          ),
          Positioned(
            top: 24,
            right: 20,
            child: _buildFloatingTag('Qualified', Icons.verified_user_rounded, const Color(0xFF10B981)),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            child: _buildFloatingTag('Urgent Priority', Icons.flag_rounded, const Color(0xFFEF4444)),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: _buildFloatingTag('Pipeline Won', Icons.star_rounded, const Color(0xFF38BDF8)),
          ),

          // Central Icon
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.filter_alt_rounded,
              size: 42,
              color: Color(0xFF0284C7),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ILLUSTRATION 3: FOLLOW-UPS ====================
  Widget _buildFollowUpIllustration() {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Floating Reminder Card
          Positioned(
            top: 22,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Tomorrow, 10:30 AM — Follow-up Call',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Central Icon Composition
          Positioned(
            bottom: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCircleIcon(Icons.phone_in_talk_rounded, const Color(0xFF38BDF8)),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    size: 42,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 14),
                _buildCircleIcon(Icons.chat_bubble_outline_rounded, const Color(0xFF10B981)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== ILLUSTRATION 4: PRODUCTIVITY ====================
  Widget _buildProductivityIllustration() {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Floating Badges
          Positioned(
            top: 24,
            left: 24,
            child: _buildFloatingTag('Check-In GPS', Icons.location_on_rounded, const Color(0xFF34D399)),
          ),
          Positioned(
            top: 24,
            right: 24,
            child: _buildFloatingTag('Work Reports', Icons.task_alt_rounded, Colors.white),
          ),
          Positioned(
            bottom: 24,
            child: _buildFloatingTag('All Systems Operational', Icons.shield_rounded, const Color(0xFF6EE7B7)),
          ),

          // Central Icon
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              size: 42,
              color: Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTag(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, size: 20, color: Colors.white),
    );
  }
}

class _OnboardingData {
  final String badge;
  final String headline;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;
  final List<String> features;
  final Widget illustrationWidget;

  const _OnboardingData({
    required this.badge,
    required this.headline,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
    required this.features,
    required this.illustrationWidget,
  });
}
