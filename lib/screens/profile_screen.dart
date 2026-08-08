import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/profile_image.dart';
import 'salary_report_screen.dart';
import 'attendance_report_screen.dart';
import 'home_screen.dart';
import 'daily_attendance_report_screen.dart';
import 'monthly_attendance_report_screen.dart';
import 'late_attendance_report_screen.dart';

// ==================== REPORT SCREENS ====================

class AbsentReportScreen extends StatelessWidget {
  const AbsentReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Absent Report'),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        // Keeps content clear of the system navigation bar
        top: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Absent Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Absent attendance records',
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final String? profileImagePath;
  final Function(String)? onImageUpdated;
  final VoidCallback? onDataChanged;

  const SettingsScreen({
    super.key,
    this.userData,
    this.profileImagePath,
    this.onImageUpdated,
    this.onDataChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _darkMode = false;
  bool _autoSync = true;
  String _selectedLanguage = 'English';
  final ImagePicker _picker = ImagePicker();

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _editProfile() async {
    final data = widget.userData ?? {};
    final mobileCtrl =
        TextEditingController(text: (data['mobile'] ?? '').toString());
    final addressCtrl =
        TextEditingController(text: (data['address'] ?? '').toString());
    final cityCtrl =
        TextEditingController(text: (data['city'] ?? '').toString());
    final stateCtrl =
        TextEditingController(text: (data['state'] ?? '').toString());
    final pincodeCtrl =
        TextEditingController(text: (data['pincode'] ?? '').toString());

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile',
                  prefixIcon: Icon(Icons.phone_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.home_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'State',
                        prefixIcon: Icon(Icons.map_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pincodeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pincode',
                  prefixIcon: Icon(Icons.markunread_mailbox_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldSave != true || !mounted) return;

    try {
      final res = await ApiService().updateProfile({
        'mobile': mobileCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'pincode': pincodeCtrl.text.trim(),
      });
      if (mounted) {
        if (res['success'] == true) {
          _showSnack(res['message'] ?? 'Profile updated successfully');
          widget.onDataChanged?.call();
        } else {
          _showSnack(res['message'] ?? 'Failed to update profile',
              error: true);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', error: true);
    }
  }

  Future<void> _changePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );
      if (image == null) return;

      final file = File(image.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', image.path);
      widget.onImageUpdated?.call(image.path);

      if (mounted) {
        _showSnack('Photo updated locally. Uploading...');
      }

      try {
        final res = await ApiService().updateProfilePhoto(file);
        if (mounted) {
          if (res['success'] == true) {
            _showSnack(res['message'] ?? 'Profile photo uploaded successfully');
            widget.onDataChanged?.call();
          } else {
            _showSnack(res['message'] ?? 'Photo upload failed', error: true);
          }
        }
      } catch (e) {
        if (mounted) {
          _showSnack('Photo saved locally, upload failed', error: true);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', error: true);
    }
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final shouldChange = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: Icon(Icons.verified_user_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Change Password'),
          ),
        ],
      ),
    );

    if (shouldChange != true || !mounted) return;

    if (newCtrl.text.length < 6) {
      _showSnack('New password must be at least 6 characters', error: true);
      return;
    }
    if (newCtrl.text != confirmCtrl.text) {
      _showSnack('Passwords do not match', error: true);
      return;
    }

    try {
      final res = await ApiService()
          .changePassword(currentCtrl.text, newCtrl.text);
      if (mounted) {
        if (res['success'] == true) {
          _showSnack(res['message'] ?? 'Password changed successfully');
        } else {
          _showSnack(res['message'] ?? 'Failed to change password',
              error: true);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        // Keeps content clear of the system navigation bar
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Settings Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsHeader('Profile Settings', Icons.person_rounded),
                  _buildSettingsTile(
                    icon: Icons.person_rounded,
                    title: 'Edit Profile',
                    subtitle: 'Update your profile information',
                    onTap: _editProfile,
                  ),
                  const Divider(height: 1, indent: 16),
                  _buildSettingsTile(
                    icon: Icons.photo_camera_rounded,
                    title: 'Change Photo',
                    subtitle: 'Update your profile picture',
                    onTap: _changePhoto,
                  ),
                  const Divider(height: 1, indent: 16),
                  _buildSettingsTile(
                    icon: Icons.lock_rounded,
                    title: 'Change Password',
                    subtitle: 'Update your password',
                    onTap: _changePassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
  
            // Preferences Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsHeader('Preferences', Icons.settings_rounded),
                  _buildSwitchTile(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    subtitle: 'Receive push notifications',
                    value: _notifications,
                    onChanged: (val) => setState(() => _notifications = val),
                  ),
                  const Divider(height: 1, indent: 16),
                  _buildSwitchTile(
                    icon: Icons.dark_mode_rounded,
                    title: 'Dark Mode',
                    subtitle: 'Enable dark theme',
                    value: _darkMode,
                    onChanged: (val) => setState(() => _darkMode = val),
                  ),
                  const Divider(height: 1, indent: 16),
                  _buildSwitchTile(
                    icon: Icons.sync_rounded,
                    title: 'Auto Sync',
                    subtitle: 'Automatically sync data',
                    value: _autoSync,
                    onChanged: (val) => setState(() => _autoSync = val),
                  ),
                  const Divider(height: 1, indent: 16),
                  _buildDropdownTile(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    subtitle: _selectedLanguage,
                    items: ['English', 'Hindi', 'Marathi', 'Gujarati'],
                    onChanged: (val) => setState(() => _selectedLanguage = val!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
  
            // About Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingsHeader('About', Icons.info_rounded),
                  _buildSettingsTile(
                    icon: Icons.info_rounded,
                    title: 'App Version',
                    subtitle: 'Yatharth Connect v1.0.0',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 16),
                  _buildSettingsTile(
                    icon: Icons.privacy_tip_rounded,
                    title: 'Privacy Policy',
                    subtitle: 'Read our privacy policy',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 16),
                  _buildSettingsTile(
                    icon: Icons.help_rounded,
                    title: 'Help & Support',
                    subtitle: 'Get help and support',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A5F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E3A5F),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E3A5F),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF1E3A5F),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF1E3A5F), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E3A5F),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: DropdownButton<String>(
        value: subtitle,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF1E3A5F)),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        // Keeps content clear of the system navigation bar
        top: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo25.png',
                  height: 80,
                  width: 80,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.business_center_rounded,
                      size: 80,
                      color: Color(0xFF1E3A5F),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Yatharth Connect',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Employee Attendance System',
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '© 2024 Yatharth Group of Institution',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== MAIN PROFILE SCREEN ====================

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final String? profileImagePath;
  final Function(String)? onImageUpdated;

  const ProfileScreen({
    super.key,
    this.userData,
    this.profileImagePath,
    this.onImageUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _profileImagePath;
  late Map<String, dynamic> _userData;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _userData = widget.userData ?? {};
    _profileImagePath = widget.profileImagePath;
    _loadProfileImage();
  }

  Future<void> _refreshProfile() async {
    try {
      final res = await ApiService().getProfile();
      if (!mounted || res['success'] != true) return;
      final emp = res['data']?['employee'];
      if (emp is Map<String, dynamic>) {
        final merged = Map<String, dynamic>.from(_userData);
        final fullName =
            '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
        if (fullName.isNotEmpty) merged['name'] = fullName;
        merged['employee_code'] = emp['employee_code'] ?? merged['employee_code'];
        merged['mobile'] = emp['mobile'] ?? merged['mobile'];
        merged['email'] = emp['email'] ?? merged['email'];
        merged['address'] = emp['address'] ?? '';
        merged['city'] = emp['city'] ?? '';
        merged['state'] = emp['state'] ?? '';
        merged['pincode'] = emp['pincode'] ?? '';
        merged['department_name'] =
            emp['department_name'] ?? merged['department_name'];
        merged['designation_name'] =
            emp['designation_name'] ?? merged['designation_name'];
        final photoUrl = ProfileImage.urlFor(emp['profile_photo']);
        if (photoUrl != null) merged['profile_photo'] = photoUrl;
        setState(() => _userData = merged);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.userKey, jsonEncode(merged));
      }
    } catch (e) {
      print('Error refreshing profile: $e');
    }
  }

  Future<void> _loadProfileImage() async {
    if (widget.profileImagePath != null && widget.profileImagePath!.isNotEmpty) {
      final file = File(widget.profileImagePath!);
      if (await file.exists()) {
        setState(() {
          _profileImagePath = widget.profileImagePath;
        });
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_path');
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        setState(() {
          _profileImagePath = imagePath;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );

      if (image != null) {
        final String imagePath = image.path;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', imagePath);

        setState(() {
          _profileImagePath = imagePath;
        });

        if (widget.onImageUpdated != null) {
          widget.onImageUpdated!(imagePath);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToSalaryReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SalaryReportScreen(),
      ),
    );
  }

  void _navigateToReport(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  void _goToDashboard() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _userData['name'] ?? 'Employee';
    final code = _userData['employee_code'] ?? 'EMP001';
    final mobile = _userData['mobile'] ?? 'N/A';
    final email = _userData['email'] ?? 'N/A';
    final role = _userData['role_name'] ?? _userData['role'] ?? 'Employee';
    final department = _userData['department_name'] ?? 'N/A';
    final designation = _userData['designation_name'] ?? 'N/A';

    // Server copy first so the avatar is the account's, not just this device's.
    // Handles the login response's relative path as well as an absolute URL.
    final profileImage = ProfileImage.resolve(
      serverPhoto: _userData['profile_photo'],
      localPath: _profileImagePath,
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _goToDashboard();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: const Color(0xFF1E3A5F),
          elevation: 0,
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: _goToDashboard,
          ),
        ),
        body: SafeArea(
          // Keeps content clear of the system navigation bar
          top: false,
          child: Container(
            color: const Color(0xFFF0F4F8),
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              children: [
                // ==================== PROFILE HEADER CARD ====================
                Container(
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
                        spreadRadius: 2,
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  child: Column(
                    children: [
                      // Profile Image
                      Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                              image: profileImage != null
                                  ? DecorationImage(
                                image: profileImage,
                                fit: BoxFit.cover,
                                onError: (_, __) {},
                              )
                                  : null,
                            ),
                            child: profileImage == null
                                ? CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white.withOpacity(0.9),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'E',
                                style: const TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                            )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 22,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Name
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Role
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Employee Code
                      Text(
                        'ID: $code',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tap to change photo hint
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                        child: const Text(
                          'Tap camera icon to change photo',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
  
                const SizedBox(height: 16),
  
                // ==================== PERSONAL INFORMATION ====================
                _buildSectionCard(
                  title: 'Personal Information',
                  icon: Icons.person_outline_rounded,
                  children: [
                    _buildInfoTile(Icons.phone_rounded, 'Mobile', mobile),
                    if (email.isNotEmpty && email != 'N/A') ...[
                      const Divider(height: 1, indent: 16),
                      _buildInfoTile(Icons.email_rounded, 'Email', email),
                    ],
                    const Divider(height: 1, indent: 16),
                    _buildInfoTile(Icons.business_rounded, 'Department', department),
                    const Divider(height: 1, indent: 16),
                    _buildInfoTile(Icons.work_rounded, 'Designation', designation),
                  ],
                ),
  
                const SizedBox(height: 16),
  
                // ==================== REPORTS & SETTINGS ====================
                _buildSectionCard(
                  title: 'Reports & Settings',
                  icon: Icons.grid_view_rounded,
                  children: [
                    _buildMenuItem(
                      icon: Icons.description_rounded,
                      title: 'Daily Report',
                      subtitle: "Today's attendance summary",
                      iconColor: Colors.blue,
                      onTap: () => _navigateToReport(const DailyAttendanceReportScreen()),
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildMenuItem(
                      icon: Icons.calendar_month_rounded,
                      title: 'Monthly Report',
                      subtitle: "This month's attendance summary",
                      iconColor: Colors.purple,
                      onTap: () => _navigateToReport(const MonthlyAttendanceReportScreen()),
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildMenuItem(
                      icon: Icons.warning_amber_rounded,
                      title: 'Late Report',
                      subtitle: 'Late attendance records',
                      iconColor: Colors.orange,
                      onTap: () => _navigateToReport(const LateAttendanceReportScreen()),
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildMenuItem(
                      icon: Icons.cancel_rounded,
                      title: 'Absent Report',
                      subtitle: 'Absent attendance records',
                      iconColor: Colors.red,
                      onTap: () => _navigateToReport(
                          const AttendanceReportScreen(type: ReportType.absent)),
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildMenuItem(
                      icon: Icons.attach_money_rounded,
                      title: 'Salary Report',
                      subtitle: 'Salary & deductions summary',
                      iconColor: Colors.green,
                      onTap: _navigateToSalaryReport,
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildMenuItem(
                      icon: Icons.settings_rounded,
                      title: 'Settings',
                      subtitle: 'App settings & preferences',
                      iconColor: Colors.grey,
                      showTrailing: true,
                      onTap: () => _navigateToReport(SettingsScreen(
                        userData: _userData,
                        profileImagePath: _profileImagePath,
                        onImageUpdated: widget.onImageUpdated,
                        onDataChanged: _refreshProfile,
                      )),
                    ),
                    const Divider(height: 1, indent: 16),
                    _buildMenuItem(
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      subtitle: 'Version 1.0.0',
                      iconColor: Colors.grey,
                      showTrailing: true,
                      onTap: () => _navigateToReport(const AboutScreen()),
                    ),
                  ],
                ),
  
                const SizedBox(height: 24),
  
                // ==================== LOGOUT BUTTON ====================
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        spreadRadius: 1,
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.red,
                        size: 22,
                      ),
                    ),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    subtitle: Text(
                      'Sign out from your account',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                // TODO: Implement logout logic
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Logging out...'),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
  
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== SECTION CARD ====================
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  // ==================== INFO TILE ====================
  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1E3A5F),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== MENU ITEM ====================
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    bool showTrailing = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E3A5F),
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      )
          : null,
      trailing: showTrailing
          ? const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: Colors.grey,
      )
          : null,
      onTap: onTap,
    );
  }
}