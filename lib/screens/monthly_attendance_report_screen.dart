import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

class MonthlyAttendanceReportScreen extends StatefulWidget {
  const MonthlyAttendanceReportScreen({super.key});

  @override
  State<MonthlyAttendanceReportScreen> createState() => _MonthlyAttendanceReportScreenState();
}

class _MonthlyAttendanceReportScreenState extends State<MonthlyAttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  Map<String, dynamic>? _summaryData;
  List<dynamic> _calendarData = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Summary
  int _totalDays = 0;
  int _workingDays = 0;
  int _presentDays = 0;
  int _absentDays = 0;
  int _lateDays = 0;
  int _halfDays = 0;
  int _leaveDays = 0;
  String _totalHours = '0h 0m';
  String _avgHours = '0h 0m';

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
    _fetchMonthlyReport();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchMonthlyReport() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getMonthlyAttendance(_selectedMonth);
      if (mounted && res['success'] == true) {
        final data = res['data'];
        setState(() {
          _summaryData = data?['summary'];
          _calendarData = data?['calendar'] ?? data?['attendance'] ?? [];
          _extractSummary(data);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _totalDays = 0;
          _workingDays = 0;
          _presentDays = 0;
          _absentDays = 0;
          _lateDays = 0;
          _halfDays = 0;
          _leaveDays = 0;
          _totalHours = '0h 0m';
          _avgHours = '0h 0m';
          _calendarData = [];
        });
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _extractSummary(Map<String, dynamic>? data) {
    if (data == null) return;
    final s = data['summary'] ?? data;
    _totalDays = _toInt(s['total_days']);
    _workingDays = _toInt(s['working_days']);
    _presentDays = _toInt(s['present_days'] ?? s['present']);
    _absentDays = _toInt(s['absent_days'] ?? s['absent']);
    _lateDays = _toInt(s['late_days'] ?? s['late']);
    _halfDays = _toInt(s['half_day_count'] ?? s['half_day']);
    _leaveDays = _toInt(s['leave_days'] ?? s['on_leave']);
    _totalHours = s['total_working_hours'] ?? '${_presentDays * 9}h 0m';
    _avgHours = s['avg_working_hours'] ?? '8h 30m';
  }



  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _changeMonth(int offset) {
    final parts = _selectedMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month + offset, 1);
    final now = DateTime.now();
    if (date.isAfter(DateTime(now.year, now.month + 1, 0))) return;
    setState(() {
      _selectedMonth = DateFormat('yyyy-MM').format(date);
    });
    _fetchMonthlyReport();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present': return const Color(0xFF22c55e);
      case 'late': return const Color(0xFFf59e0b);
      case 'half-day': return const Color(0xFFef4444);
      case 'absent': return const Color(0xFFdc2626);
      case 'on_leave':
      case 'leave': return const Color(0xFF8b5cf6);
      case 'holiday': return const Color(0xFF06b6d4);
      case 'upcoming': return const Color(0xFFd1d5db);
      default: return const Color(0xFF6b7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildMonthSelector(),
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
                      onRefresh: _fetchMonthlyReport,
                      color: const Color(0xFF1E3A5F),
                      child: ListView(
                        padding: const EdgeInsets.all(12),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          _buildOverviewCard(),
                          const SizedBox(height: 12),
                          _buildStatsGrid(),
                          const SizedBox(height: 16),
                          _buildAttendanceCalendarList(),
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
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Image.asset(
              'assets/images/logo25.png',
              height: 32, width: 32, fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 24);
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
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              Text(
                'Monthly Report',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 0.3),
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
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: IconButton(
            onPressed: () { HapticFeedback.lightImpact(); _fetchMonthlyReport(); },
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

  // ==================== MONTH SELECTOR ====================
  Widget _buildMonthSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)]),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1E3A5F)),
            onPressed: () => _changeMonth(-1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(now.year, now.month),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year + 1),
                  initialEntryMode: DatePickerEntryMode.calendarOnly,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(primary: Color(0xFF1E3A5F), onPrimary: Colors.white),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() { _selectedMonth = DateFormat('yyyy-MM').format(picked); });
                  _fetchMonthlyReport();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy').format(DateTime.parse('$_selectedMonth-01')),
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF1E3A5F)),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1E3A5F)),
            onPressed: () => _changeMonth(1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ==================== OVERVIEW CARD ====================
  Widget _buildOverviewCard() {
    final attendancePercent = _workingDays > 0 ? (_presentDays / _workingDays * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        children: [
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: attendancePercent / 100,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Center(
                      child: Text(
                        '${attendancePercent.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_presentDays of $_workingDays working days',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildOverviewChip('Total Hours', _totalHours),
                        const SizedBox(width: 8),
                        _buildOverviewChip('Avg/Day', _avgHours),
                      ],
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

  Widget _buildOverviewChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9)),
        ],
      ),
    );
  }

  // ==================== STATS GRID ====================
  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Present', _presentDays, Icons.check_circle_rounded, const Color(0xFF22c55e))),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Absent', _absentDays, Icons.cancel_rounded, const Color(0xFFdc2626))),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Late', _lateDays, Icons.access_time_rounded, const Color(0xFFf59e0b))),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Leave', _leaveDays, Icons.event_busy_rounded, const Color(0xFF8b5cf6))),
      ],
    );
  }

  Widget _buildStatCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ==================== CALENDAR LIST ====================
  Widget _buildAttendanceCalendarList() {
    if (_calendarData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.calendar_month_rounded, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No data for this month', style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
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
                  gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.view_list_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Day-wise Attendance',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_calendarData.length, (i) => _buildDayRow(_calendarData[i])),
      ],
    );
  }

  Widget _buildDayRow(dynamic day) {
    final dateStr = day['date'] ?? '';
    final status = day['status'] ?? 'upcoming';
    final checkIn = day['check_in'];
    final checkOut = day['check_out'];
    final workingHours = day['working_hours'];
    final lateMinutes = _toInt(day['late_minutes']);
    final statusColor = _getStatusColor(status);
    final isHoliday = status == 'holiday';
    final isUpcoming = status == 'upcoming';

    String dayNum = '';
    String dayName = '';
    try {
      final dt = DateTime.parse(dateStr);
      dayNum = dt.day.toString();
      dayName = DateFormat('EEE').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHoliday ? const Color(0xFF06b6d4).withOpacity(0.06) : isUpcoming ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHoliday ? const Color(0xFF06b6d4).withOpacity(0.2) : Colors.grey.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Date circle
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(dayNum, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor)),
                Text(dayName, style: TextStyle(fontSize: 8, color: statusColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: isHoliday
                ? Text('Sunday / Holiday', style: TextStyle(color: const Color(0xFF06b6d4), fontWeight: FontWeight.w500, fontSize: 13))
                : isUpcoming
                    ? Text('Upcoming', style: TextStyle(color: Colors.grey[400], fontSize: 13))
                    : Row(
                        children: [
                          if (checkIn != null) ...[
                            Icon(Icons.login_rounded, size: 12, color: Colors.green[400]),
                            const SizedBox(width: 3),
                            Text(Helpers.formatTime(checkIn), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(width: 8),
                          ],
                          if (checkOut != null) ...[
                            Icon(Icons.logout_rounded, size: 12, color: Colors.red[400]),
                            const SizedBox(width: 3),
                            Text(Helpers.formatTime(checkOut), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(width: 8),
                          ],
                          if (workingHours != null) ...[
                            Icon(Icons.schedule_rounded, size: 12, color: Colors.blue[400]),
                            const SizedBox(width: 3),
                            Text(Helpers.formatDuration(workingHours), style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          ],
                          if (lateMinutes > 0) ...[
                            const SizedBox(width: 8),
                            Text('${lateMinutes}m late', style: TextStyle(fontSize: 10, color: Colors.orange[700], fontWeight: FontWeight.w500)),
                          ],
                        ],
                      ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status == 'present' ? 'P' : status == 'late' ? 'L' : status == 'absent' ? 'A' : status == 'half-day' ? 'HD' : status == 'leave' || status == 'on_leave' ? 'LV' : status == 'holiday' ? 'H' : '-',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
