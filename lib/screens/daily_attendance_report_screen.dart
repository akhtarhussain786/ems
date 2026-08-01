import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

class DailyAttendanceReportScreen extends StatefulWidget {
  const DailyAttendanceReportScreen({super.key});

  @override
  State<DailyAttendanceReportScreen> createState() => _DailyAttendanceReportScreenState();
}

class _DailyAttendanceReportScreenState extends State<DailyAttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  Map<String, dynamic>? _reportData;
  List<dynamic> _attendanceList = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Summary counts
  int _totalEmployees = 0;
  int _presentCount = 0;
  int _absentCount = 0;
  int _lateCount = 0;
  int _halfDayCount = 0;
  int _onLeaveCount = 0;

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
    _fetchDailyReport();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchDailyReport() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getDailyAttendance(_selectedDate);
      if (mounted && res['success'] == true) {
        final data = res['data'];
        setState(() {
          _reportData = data;
          _attendanceList = data?['attendance'] ?? [];
          _totalEmployees = _toInt(data?['total_employees']);
          _presentCount = _toInt(data?['present']);
          _absentCount = _toInt(data?['absent']);
          _lateCount = _toInt(data?['late']);
          _halfDayCount = _toInt(data?['half_day']);
          _onLeaveCount = _toInt(data?['on_leave']);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _totalEmployees = 0;
          _presentCount = 0;
          _absentCount = 0;
          _lateCount = 0;
          _halfDayCount = 0;
          _onLeaveCount = 0;
          _attendanceList = [];
        });
      }
    }
    if (mounted) setState(() => _loading = false);
  }



  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _changeDate(int offset) {
    final current = DateTime.parse(_selectedDate);
    final newDate = current.add(Duration(days: offset));
    if (newDate.isAfter(DateTime.now())) return;
    setState(() {
      _selectedDate = DateFormat('yyyy-MM-dd').format(newDate);
    });
    _fetchDailyReport();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present': return const Color(0xFF22c55e);
      case 'late': return const Color(0xFFf59e0b);
      case 'half-day': return const Color(0xFFef4444);
      case 'absent': return const Color(0xFFdc2626);
      case 'on_leave':
      case 'leave': return const Color(0xFF8b5cf6);
      default: return const Color(0xFF6b7280);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'present': return 'Present';
      case 'late': return 'Late';
      case 'half-day': return 'Half Day';
      case 'absent': return 'Absent';
      case 'on_leave':
      case 'leave': return 'On Leave';
      default: return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present': return Icons.check_circle_rounded;
      case 'late': return Icons.access_time_rounded;
      case 'half-day': return Icons.timelapse_rounded;
      case 'absent': return Icons.cancel_rounded;
      case 'on_leave':
      case 'leave': return Icons.event_busy_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(),
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
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: RefreshIndicator(
                      onRefresh: _fetchDailyReport,
                      color: const Color(0xFF1E3A5F),
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          _buildSummaryCards(),
                          const SizedBox(height: 16),
                          _buildAttendanceList(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar() {
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
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 24,
                );
              },
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
                'Daily Report',
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
              _fetchDailyReport();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(),
          ),
        ),
        const SizedBox(width: 4),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      centerTitle: false,
    );
  }

  // ==================== DATE SELECTOR ====================
  Widget _buildDateSelector() {
    final displayDate = DateFormat('dd MMMM yyyy').format(DateTime.parse(_selectedDate));
    final isToday = _selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now());

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
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
              ),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1E3A5F)),
            onPressed: () => _changeDate(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse(_selectedDate),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
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
                  setState(() => _selectedDate = DateFormat('yyyy-MM-dd').format(picked));
                  _fetchDailyReport();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF22c55e).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF22c55e),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now())
                  ? Colors.grey[300]
                  : const Color(0xFF1E3A5F),
            ),
            onPressed: () => _changeDate(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ==================== SUMMARY CARDS ====================
  Widget _buildSummaryCards() {
    return Column(
      children: [
        // Top Row — Total + Present
        Row(
          children: [
            Expanded(
              child: _buildSummaryTile(
                'Total',
                _totalEmployees,
                Icons.groups_rounded,
                const Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSummaryTile(
                'Present',
                _presentCount,
                Icons.check_circle_rounded,
                const Color(0xFF22c55e),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Bottom Row — Late, Absent, Half Day, Leave
        Row(
          children: [
            Expanded(child: _buildMiniSummaryTile('Late', _lateCount, const Color(0xFFf59e0b))),
            const SizedBox(width: 8),
            Expanded(child: _buildMiniSummaryTile('Absent', _absentCount, const Color(0xFFdc2626))),
            const SizedBox(width: 8),
            Expanded(child: _buildMiniSummaryTile('Half Day', _halfDayCount, const Color(0xFFef4444))),
            const SizedBox(width: 8),
            Expanded(child: _buildMiniSummaryTile('Leave', _onLeaveCount, const Color(0xFF8b5cf6))),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryTile(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSummaryTile(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== ATTENDANCE LIST ====================
  Widget _buildAttendanceList() {
    if (_attendanceList.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                'Employee Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A5F),
                ),
              ),
              const Spacer(),
              Text(
                '${_attendanceList.length} records',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_attendanceList.length, (i) {
          return _buildAttendanceCard(_attendanceList[i]);
        }),
      ],
    );
  }

  Widget _buildAttendanceCard(dynamic record) {
    final name = record['name'] ?? 'Unknown';
    final code = record['employee_code'] ?? '';
    final dept = record['department'] ?? '';
    final status = record['status'] ?? 'absent';
    final checkIn = record['check_in'];
    final checkOut = record['check_out'];
    final workingHours = record['working_hours'];
    final lateMinutes = _toInt(record['late_minutes']);
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withOpacity(0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$code • $dept',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (checkIn != null) ...[
                        Icon(Icons.login_rounded, size: 12, color: Colors.green[400]),
                        const SizedBox(width: 3),
                        Text(
                          Helpers.formatTime(checkIn),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (checkOut != null) ...[
                        Icon(Icons.logout_rounded, size: 12, color: Colors.red[400]),
                        const SizedBox(width: 3),
                        Text(
                          Helpers.formatTime(checkOut),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                      if (workingHours != null) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.schedule_rounded, size: 12, color: Colors.blue[400]),
                        const SizedBox(width: 3),
                        Text(
                          Helpers.formatDuration(workingHours),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Status badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusIcon(status), size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusLabel(status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (lateMinutes > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '$lateMinutes min late',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No attendance data',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'for ${DateFormat('dd MMMM yyyy').format(DateTime.parse(_selectedDate))}',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchDailyReport,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
