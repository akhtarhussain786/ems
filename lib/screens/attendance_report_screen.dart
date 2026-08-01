import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

enum ReportType { daily, monthly, late, absent }

class AttendanceReportScreen extends StatefulWidget {
  final ReportType type;

  const AttendanceReportScreen({super.key, required this.type});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<dynamic> _records = [];
  Map<String, dynamic> _stats = {};
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  ReportType get _type => widget.type;
  bool get _isDaily => _type == ReportType.daily;

  String get _title {
    switch (_type) {
      case ReportType.daily:
        return 'Daily Report';
      case ReportType.monthly:
        return 'Monthly Report';
      case ReportType.late:
        return 'Late Report';
      case ReportType.absent:
        return 'Absent Report';
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final ApiService api = ApiService();
      final res = switch (_type) {
        ReportType.daily => await api.getDailyAttendance(_selectedDate),
        ReportType.monthly => await api.getMonthlyAttendance(_selectedMonth),
        ReportType.late => await api.getLateAttendance(_selectedMonth),
        ReportType.absent => await api.getAbsentAttendance(_selectedMonth),
      };
      if (mounted && res['success'] == true) {
        setState(() {
          if (_isDaily) {
            _records = res['data'] != null ? [res['data']] : [];
            _stats = {
              'office_start': res['office_start'],
              'office_end': res['office_end'],
            };
          } else {
            _records = res['data'] ?? [];
            _stats = switch (_type) {
              ReportType.monthly => res['stats'] ?? {},
              ReportType.late => {'total_late': res['total_late'] ?? 0},
              ReportType.absent => {'total_absent': res['total_absent'] ?? 0},
              ReportType.daily => {},
            };
          }
        });
      }
    } catch (e) {
      print('Error fetching report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(),
      body: Column(
        children: [
          _buildDateSelector(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1E3A5F),
                      strokeWidth: 3,
                    ),
                  )
                : _records.isEmpty
                    ? _buildEmptyState()
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: RefreshIndicator(
                          onRefresh: _fetchData,
                          color: const Color(0xFF1E3A5F),
                          child: ListView(
                            padding: const EdgeInsets.all(12),
                            children: _buildContent(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent() {
    final children = <Widget>[];
    if (_isDaily) {
      children.addAll(
        _records.map((r) => _buildDailySummary(r)).toList(),
      );
    } else {
      if (_type == ReportType.monthly && _stats.isNotEmpty) {
        children.add(_buildMonthlyStats());
      }
      if (_type == ReportType.late) {
        children.add(
          _buildTotalBanner(
            label: 'Total late days',
            value: _stats['total_late'] ?? 0,
            color: Colors.orange,
            icon: Icons.warning_amber_rounded,
          ),
        );
      }
      if (_type == ReportType.absent) {
        children.add(
          _buildTotalBanner(
            label: 'Total absent days',
            value: _stats['total_absent'] ?? 0,
            color: Colors.red,
            icon: Icons.cancel_rounded,
          ),
        );
      }
      children.addAll(
        _records.map((r) => _buildRecordCard(r)).toList(),
      );
    }
    return children;
  }

  // ==================== DAILY SUMMARY CARD ====================
  Widget _buildDailySummary(Map<String, dynamic> r) {
    final status = r['status'] ?? 'absent';
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    status == 'late'
                        ? Icons.warning_amber_rounded
                        : status == 'absent' || status == 'half-day'
                            ? Icons.cancel_rounded
                            : Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel(status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('EEEE, dd MMM yyyy')
                            .format(DateTime.parse(_selectedDate)),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _detailRow(
                  Icons.login_rounded,
                  'Check-In',
                  Helpers.formatTime(r['check_in']),
                ),
                const Divider(height: 16),
                _detailRow(
                  Icons.logout_rounded,
                  'Check-Out',
                  Helpers.formatTime(r['check_out']),
                ),
                const Divider(height: 16),
                _detailRow(
                  Icons.timer_rounded,
                  'Working Hours',
                  Helpers.formatDuration(r['working_hours']),
                ),
                if ((r['late_minutes'] ?? 0) > 0) ...[
                  const Divider(height: 16),
                  _detailRow(
                    Icons.warning_amber_rounded,
                    'Late By',
                    '${r['late_minutes']} min',
                  ),
                ],
                if ((r['remarks'] ?? '').toString().isNotEmpty) ...[
                  const Divider(height: 16),
                  _detailRow(
                    Icons.notes_rounded,
                    'Remarks',
                    r['remarks'].toString(),
                  ),
                ],
                if (r['check_in_photo'] != null || r['check_out_photo'] != null) ...[
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (r['check_in_photo'] != null)
                        _photoThumb(r['check_in_photo'], 'Check-In'),
                      if (r['check_out_photo'] != null) ...[
                        const SizedBox(width: 16),
                        _photoThumb(r['check_out_photo'], 'Check-Out'),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoThumb(String url, String label) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 90,
              height: 90,
              color: Colors.grey[200],
              child: const Icon(
                Icons.broken_image_rounded,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF1E3A5F), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1E3A5F),
          ),
        ),
      ],
    );
  }

  // ==================== MONTHLY STATS ====================
  Widget _buildMonthlyStats() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatChip('Present', _stats['present'] ?? 0, Colors.green),
          _buildStatChip('Late', _stats['late'] ?? 0, Colors.orange),
          _buildStatChip('Half-Day', _stats['half_day'] ?? 0, Colors.red),
        ],
      ),
    );
  }

  Widget _buildTotalBanner({
    required String label,
    required dynamic value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, dynamic value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ==================== RECORD CARD (monthly / late / absent) ====================
  Widget _buildRecordCard(Map<String, dynamic> record) {
    final status = record['status'] ?? '';
    final color = _statusColor(status);
    final hasCheckIn = record['check_in'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                Helpers.getStatusEmoji(status),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Helpers.formatDate(record['attendance_date']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  record['day_name'] ?? Helpers.getDayOfWeek(
                      record['attendance_date']),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                if (hasCheckIn) ...[
                  const SizedBox(height: 4),
                  Text(
                    'In: ${Helpers.formatTime(record['check_in'])}   Out: ${Helpers.formatTime(record['check_out'])}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (status == 'late' && (record['late_minutes'] ?? 0) > 0)
                Text(
                  '${record['late_minutes']} min late',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.orange[700],
                  ),
                )
              else if (hasCheckIn)
                Text(
                  Helpers.formatDuration(record['working_hours']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== DATE / MONTH SELECTOR ====================
  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isDaily
                          ? DateFormat('EEEE, dd MMM yyyy')
                              .format(DateTime.parse(_selectedDate))
                          : DateFormat('MMMM yyyy')
                              .format(DateTime.parse('$_selectedMonth-01')),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down_rounded,
                        color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _isDaily
          ? DateTime.parse(_selectedDate)
          : DateTime(now.year, now.month),
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A5F),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (_isDaily) {
          _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _selectedMonth = DateFormat('yyyy-MM').format(picked);
        }
        _fetchData();
      });
    }
  }

  // ==================== GLASS APP BAR ====================
  PreferredSizeWidget _buildGlassAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A5F),
      elevation: 0,
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
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Image.asset(
              'assets/images/logo25.png',
              height: 32,
              width: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                _isDaily
                    ? Icons.calendar_today_rounded
                    : _type == ReportType.late
                        ? Icons.warning_amber_rounded
                        : _type == ReportType.absent
                            ? Icons.cancel_rounded
                            : Icons.calendar_month_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Colors.white70],
                ).createShader(bounds),
                child: const Text(
                  'YATHARTH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                _title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetchData();
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 22,
            ),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(),
          ),
        ),
        const SizedBox(width: 4),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      centerTitle: false,
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState() {
    final String message;
    switch (_type) {
      case ReportType.daily:
        message = 'No attendance record for this date';
        break;
      case ReportType.monthly:
        message = 'No attendance records for this month';
        break;
      case ReportType.late:
        message = 'No late attendance for this month';
        break;
      case ReportType.absent:
        message = 'No absences for this month';
        break;
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isDaily
                ? Icons.event_busy_rounded
                : _type == ReportType.late
                    ? Icons.event_available_rounded
                    : _type == ReportType.absent
                        ? Icons.check_circle_outline_rounded
                        : Icons.calendar_month_rounded,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'half-day':
        return Colors.red;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'present':
        return 'Present';
      case 'late':
        return 'Late';
      case 'half-day':
        return 'Half Day';
      case 'absent':
        return 'Absent';
      default:
        return 'No Record';
    }
  }
}
