import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';
import 'home_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final bool checkIn;
  const AttendanceScreen({super.key, this.checkIn = true});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  bool _loading = false;
  bool _locationLoading = true;
  bool _withinRange = false;
  String? _error;
  String? _photoPath;
  String? _photoBase64;
  double? _latitude;
  double? _longitude;
  String _address = '';
  double _distance = 0;
  Map<String, dynamic>? _todayAttendance;
  bool _completed = false;
  bool _debugMode = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _init();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _getLocation();
    await _fetchTodayAttendance();
    if (_debugMode) {
      await _testApiConnection();
    }
  }

  Future<void> _testApiConnection() async {
    try {
      print('🟢 Testing API connection...');
      final response = await ApiService().get('test_simple.php');
      print('🟢 API Test Response: $response');
    } catch (e) {
      print('🔴 API Test Failed: $e');
    }
  }

  Future<void> _fetchTodayAttendance() async {
    try {
      print('🟢 Fetching today attendance...');
      final res = await ApiService().getTodayAttendance();
      print('🟢 Attendance Response: $res');

      if (mounted && res['success'] == true) {
        setState(() {
          _todayAttendance = res['data']?['attendance'];
        });
      }
    } catch (e) {
      print('🔴 Fetch attendance error: $e');
    }
  }

  Future<void> _getLocation() async {
    setState(() {
      _locationLoading = true;
      _error = null;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _error = 'GPS is disabled. Please enable location.';
        _locationLoading = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _error = 'Location permission denied';
          _locationLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _error = 'Location permission permanently denied';
        _locationLoading = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      await _checkLocation();
    } catch (e) {
      setState(() {
        _error = 'Failed to get location: $e';
        _locationLoading = false;
      });
    }
  }

  Future<void> _checkLocation() async {
    try {
      final res = await ApiService().getOfficeSettings();
      if (!mounted) return;

      if (res['success'] == true) {
        final office = res['data']?['office'];
        if (office != null) {
          final officeLat = double.parse(office['latitude'].toString());
          final officeLng = double.parse(office['longitude'].toString());
          final radius = int.parse(office['radius'].toString());

          final distance = Geolocator.distanceBetween(
            _latitude!, _longitude!, officeLat, officeLng,
          );

          setState(() {
            _distance = distance;
            _withinRange = distance <= radius;
            _locationLoading = false;
          });
        } else {
          setState(() {
            _withinRange = true;
            _locationLoading = false;
          });
        }
      } else {
        setState(() {
          _withinRange = true;
          _locationLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _withinRange = true;
        _locationLoading = false;
      });
    }
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
    );

    if (photo != null) {
      print('🟢 Photo captured: ${photo.path}');
      print('🟢 Photo size: ${await photo.length()} bytes');

      setState(() {
        _photoPath = photo.path;
        _photoBase64 = null;
      });

      try {
        final dir = await getTemporaryDirectory();
        final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

        print('🟢 Compressing image...');
        final compressed = await FlutterImageCompress.compressAndGetFile(
          photo.path, targetPath,
          minWidth: 480,
          minHeight: 640,
          quality: 60,
        );

        if (compressed != null) {
          final bytes = await compressed.readAsBytes();
          print('🟢 Compressed size: ${bytes.length} bytes');
          setState(() => _photoBase64 = base64Encode(bytes));
          setState(() => _photoPath = compressed.path);
        }
      } catch (e) {
        print('🔴 Compression error: $e');
      }
    }
  }

  Future<void> _submit() async {
    if (!_withinRange) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are outside office location.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_photoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selfie photo is required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final file = _photoPath != null ? File(_photoPath!) : null;
      Map<String, dynamic> response;

      print('🟢 Submitting attendance...');
      print('🟢 CheckIn: ${widget.checkIn}');
      print('🟢 Location: $_latitude, $_longitude');

      if (widget.checkIn) {
        response = await ApiService().checkIn(
            _latitude!,
            _longitude!,
            _address,
            file,
            _photoBase64
        );
      } else {
        response = await ApiService().checkOut(
            _latitude!,
            _longitude!,
            _address,
            file,
            _photoBase64
        );
      }

      print('🟢 Response: $response');

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() => _completed = true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.checkIn ? '✅ Check-in successful!' : '✅ Check-out successful!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        await _fetchTodayAttendance();

        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _safePop();
          }
        });
      } else {
        final errorMsg = response['message'] ?? 'Failed to submit attendance';
        print('🔴 API returned error: $errorMsg');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _loading = false);
      }
    } catch (e) {
      print('🔴 Submit error: $e');

      String errorMsg = 'Error: $e';
      if (e.toString().contains('Empty response')) {
        errorMsg = 'Server returned empty response. Please check your connection and try again.';
      } else if (e.toString().contains('401')) {
        errorMsg = 'Session expired. Please login again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMsg'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() => _loading = false);
    }
  }

  void _safePop() {
    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  void _goBack() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _safePop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCheckIn = widget.checkIn;
    final att = _todayAttendance;
    final checkInTime = att?['check_in'];
    final checkOutTime = att?['check_out'];
    final alreadyDone = isCheckIn ? checkInTime != null : checkOutTime != null;

    if (alreadyDone || _completed) {
      return _buildSuccessScreen(isCheckIn, checkInTime, checkOutTime);
    }

    return _buildMainScreen(isCheckIn);
  }

  // ==================== SUCCESS SCREEN ====================
  Widget _buildSuccessScreen(bool isCheckIn, dynamic checkInTime, dynamic checkOutTime) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: _buildAppBar(isCheckIn, true),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Success Icon
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1E3A5F).withOpacity(0.1),
                          const Color(0xFF2A5298).withOpacity(0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A5F).withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF1E3A5F),
                      size: 80,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _completed ? 'Completed!' : 'Already ${isCheckIn ? "Checked In" : "Checked Out"}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                        color: const Color(0xFF1E3A5F),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Helpers.formatTime((isCheckIn ? checkInTime : checkOutTime)?.toString()) ?? '--:--',
                        style: const TextStyle(
                          color: Color(0xFF1E3A5F),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  label: const Text(
                    'Go Back to Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== MAIN SCREEN ====================
  Widget _buildMainScreen(bool isCheckIn) {
    return PopScope(
      canPop: !_loading,
      onPopInvoked: (didPop) {
        if (!didPop && !_loading) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: _buildAppBar(isCheckIn, false),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: FadeTransition(
            opacity: _animationController,
            child: Column(
              children: [
                _buildHeaderCard(isCheckIn),
                const SizedBox(height: 16),
                _buildLocationCard(),
                const SizedBox(height: 16),
                _buildPhotoCard(),
                const SizedBox(height: 24),
                _buildSubmitButton(isCheckIn),
                const SizedBox(height: 12),
                _buildHelpText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar(bool isCheckIn, bool isSuccess) {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A5F),
      elevation: 0,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: _loading ? null : _goBack,
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/logo25.png',
            height: 180,
            width: 180,
            fit: BoxFit.contain,
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [Color(0xFF1E3A5F), Color(0xFF2A5298)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isCheckIn ? 'CHECK IN' : 'CHECK OUT',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== HEADER CARD ====================
  Widget _buildHeaderCard(bool isCheckIn) {
    return Container(
      padding: const EdgeInsets.all(20),
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
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCheckIn ? 'Check In' : 'Check Out',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCheckIn
                      ? 'Mark your attendance for today'
                      : 'Complete your attendance for today',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LOCATION CARD ====================
  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 3),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Location Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_locationLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Getting location...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_error != null)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _getLocation,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _withinRange
                        ? [const Color(0xFF1E3A5F).withOpacity(0.1), const Color(0xFF2A5298).withOpacity(0.05)]
                        : [Colors.red.shade50, Colors.red.shade100],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _withinRange ? const Color(0xFF1E3A5F).withOpacity(0.2) : Colors.red.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _withinRange ? const Color(0xFF1E3A5F) : Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _withinRange ? Icons.check_rounded : Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _withinRange
                            ? '✓ Within office area'
                            : '✗ Outside office area',
                        style: TextStyle(
                          color: _withinRange ? const Color(0xFF1E3A5F) : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.straighten_rounded, size: 14, color: Color(0xFF1E3A5F)),
                        const SizedBox(width: 4),
                        Text(
                          '${_distance.toStringAsFixed(1)} meters',
                          style: const TextStyle(
                            color: Color(0xFF1E3A5F),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gps_fixed_rounded, size: 14, color: Color(0xFF1E3A5F)),
                        const SizedBox(width: 4),
                        Text(
                          '${_latitude?.toStringAsFixed(4)}, ${_longitude?.toStringAsFixed(4)}',
                          style: const TextStyle(
                            color: Color(0xFF1E3A5F),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!_withinRange) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You are outside office location. Attendance not allowed.',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
        ],
      ),
    );
  }

  // ==================== PHOTO CARD ====================
  Widget _buildPhotoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 3),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Live Selfie',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Color(0xFF1E3A5F),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Camera Only',
                      style: TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _capturePhoto,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                gradient: _photoPath != null
                    ? null
                    : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade50,
                    Colors.grey.shade100,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _photoPath != null ? const Color(0xFF1E3A5F).withOpacity(0.5) : Colors.grey.shade300,
                  width: _photoPath != null ? 2 : 1.5,
                ),
                image: _photoPath != null
                    ? DecorationImage(
                  image: FileImage(File(_photoPath!)),
                  fit: BoxFit.cover,
                )
                    : null,
                boxShadow: _photoPath != null
                    ? [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withOpacity(0.2),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
                    : null,
              ),
              child: _photoPath == null
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tap to capture selfie',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Front camera will be used',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                  ),
                ],
              )
                  : Stack(
                children: [
                  // Photo displayed via decoration
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Selfie Captured ✓',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Tap to retake',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E3A5F),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF1E3A5F),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_photoPath != null) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E3A5F)),
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== SUBMIT BUTTON ====================
  Widget _buildSubmitButton(bool isCheckIn) {
    final enabled = !_loading && _withinRange && _photoPath != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: enabled
            ? [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.4),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: ElevatedButton.icon(
        onPressed: enabled ? _submit : null,
        icon: _loading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : Icon(
          isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
          size: 24,
        ),
        label: Text(
          _loading
              ? 'Processing...'
              : isCheckIn
              ? 'Confirm Check In'
              : 'Confirm Check Out',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(double.infinity, 58),
          elevation: enabled ? 4 : 0,
        ),
      ),
    );
  }

  // ==================== HELP TEXT ====================
  Widget _buildHelpText() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            'Make sure you are within office location',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}