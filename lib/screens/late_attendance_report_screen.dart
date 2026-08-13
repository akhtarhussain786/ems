import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

class LateAttendanceReportScreen extends StatefulWidget {
  const LateAttendanceReportScreen({super.key});

  @override
  State<LateAttendanceReportScreen> createState() => _LateAttendanceReportScreenState();
}

class _LateAttendanceReportScreenState extends State<LateAttendanceReportScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  List<dynamic> _lateRecords = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Summary
  int _totalLateDays = 0;
  int _totalLateMinutes = 0;
  String _avgLateTime = '0 min';
  int _maxLateMinutes = 0;

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
    _fetchLateReport();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchLateReport() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getLateAttendance(_selectedMonth);
      if (mounted && res['success'] == true) {
        final data = res['data'];
        setState(() {
          _lateRecords = data?['records'] ?? data?['late_records'] ?? [];
          _totalLateDays = _toInt(data?['total_late_days']);
          _totalLateMinutes = _toInt(data?['total_late_minutes']);
          _avgLateTime = data?['avg_late_time'] ?? '${_totalLateDays > 0 ? (_totalLateMinutes ~/ _totalLateDays) : 0} min';
          _maxLateMinutes = _toInt(data?['max_late_minutes']);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lateRecords = [];
          _totalLateDays = 0;
          _totalLateMinutes = 0;
          _maxLateMinutes = 0;
          _avgLateTime = '0 min';
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
    _fetchLateReport();
  }

  Color _getLateColor(int minutes) {
    if (minutes <= 10) return const Color(0xFFf59e0b); // mild
    if (minutes <= 30) return const Color(0xFFf97316); // moderate
    if (minutes <= 60) return const Color(0xFFef4444); // serious
    return const Color(0xFFdc2626); // critical
  }

  String _getLateLabel(int minutes) {
    if (minutes <= 10) return 'Mild';
    if (minutes <= 30) return 'Moderate';
    if (minutes <= 60) return 'Serious';
    return 'Critical';
  }

  IconData _getLateIcon(int minutes) {
    if (minutes <= 10) return Icons.info_rounded;
    if (minutes <= 30) return Icons.warning_amber_rounded;
    if (minutes <= 60) return Icons.error_outline_rounded;
    return Icons.error_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(),
      body: SafeArea(
        // Keeps content clear of the system navigation bar
        top: false,
        child: Column(
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
                        onRefresh: _fetchLateReport,
                        color: const Color(0xFF1E3A5F),
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          children: [
                            _buildSummaryCard(),
                            const SizedBox(height: 12),
                            _buildStatsRow(),
                            const SizedBox(height: 16),
                            _buildLateRecordsList(),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
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
                return const Icon(Icons.access_time_rounded, color: Colors.white, size: 24);
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
                'Late Report',
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
            onPressed: () { HapticFeedback.lightImpact(); _fetchLateReport(); },
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
              gradient: const LinearGradient(colors: [Color(0xFFf59e0b), Color(0xFFf97316)]),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 18),
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
                  _fetchLateReport();
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

  // ==================== SUMMARY CARD ====================
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFf59e0b), Color(0xFFf97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFf59e0b).withOpacity(0.3),
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Late Attendance Summary',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_totalLateDays days late this month',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: $_totalLateMinutes minutes',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                ),
              ],
            ),
          ),
          // Big number
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  _totalLateDays.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                ),
                Text(
                  'Days',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATS ROW ====================
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildMiniStat('Total Late', '$_totalLateMinutes min', Icons.timer_rounded, const Color(0xFFf59e0b))),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniStat('Average', _avgLateTime, Icons.analytics_rounded, const Color(0xFF3b82f6))),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniStat('Max Late', '$_maxLateMinutes min', Icons.trending_up_rounded, const Color(0xFFdc2626))),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ==================== LATE RECORDS LIST ====================
  Widget _buildLateRecordsList() {
    if (_lateRecords.isEmpty) {
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
                  gradient: const LinearGradient(colors: [Color(0xFFf59e0b), Color(0xFFf97316)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Late Entries',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
              ),
              const Spacer(),
              Text(
                '${_lateRecords.length} records',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(_lateRecords.length, (i) => _buildLateCard(_lateRecords[i], i)),
      ],
    );
  }

  Widget _buildLateCard(dynamic record, int index) {
    final dateStr = record['date'] ?? '';
    final checkIn = record['check_in'];
    final checkOut = record['check_out'];
    final workingHours = record['working_hours'];
    final lateMinutes = _toInt(record['late_minutes']);
    final expectedTime = record['expected_time'] ?? '09:00 AM';
    final lateColor = _getLateColor(lateMinutes);

    String displayDate = dateStr;
    String dayName = '';
    try {
      final dt = DateTime.parse(dateStr);
      displayDate = DateFormat('dd MMM yyyy').format(dt);
      dayName = DateFormat('EEEE').format(dt);
    } catch (_) {}

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
        border: Border(
          left: BorderSide(color: lateColor, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Top row — date + late badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: lateColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getLateIcon(lateMinutes), color: lateColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDate,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dayName,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Late duration badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [lateColor, lateColor.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: lateColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$lateMinutes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'min late',
                        style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Details row
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDetailItem('Expected', expectedTime, Icons.schedule_rounded, Colors.grey),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  _buildDetailItem('Arrived', checkIn != null ? Helpers.formatTime(checkIn) : '--:--', Icons.login_rounded, lateColor),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  _buildDetailItem('Left', checkOut != null ? Helpers.formatTime(checkOut) : '--:--', Icons.logout_rounded, Colors.blue),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  _buildDetailItem('Hours', workingHours != null ? Helpers.formatDuration(workingHours) : '--', Icons.timelapse_rounded, const Color(0xFF1E3A5F)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Severity bar
            Row(
              children: [
                Text('Severity: ', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: lateColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getLateLabel(lateMinutes),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: lateColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (lateMinutes / 60).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(lateColor),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E3A5F)),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
        ),
      ],
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF22c55e).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFF22c55e)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No late entries! 🎉',
              style: TextStyle(
                color: Color(0xFF22c55e),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Perfect attendance for ${DateFormat('MMMM yyyy').format(DateTime.parse('$_selectedMonth-01'))}',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchLateReport,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
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
