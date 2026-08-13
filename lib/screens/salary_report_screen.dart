import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

class SalaryReportScreen extends StatefulWidget {
  const SalaryReportScreen({super.key});

  @override
  State<SalaryReportScreen> createState() => _SalaryReportScreenState();
}

class _SalaryReportScreenState extends State<SalaryReportScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _loadingSlip = false;
  List<dynamic> _salaryData = [];
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  Map<String, dynamic>? _selectedEmployee;
  Map<String, dynamic>? _salarySlip;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _fetchSalaryData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchSalaryData() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().post('salary/list', {
        'month': _selectedMonth,
      });
      if (mounted && res['success'] == true) {
        setState(() => _salaryData = res['data'] ?? []);
      }
    } catch (e) {
      print('Error fetching salary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchSalarySlip(int employeeId) async {
    setState(() => _loadingSlip = true);
    try {
      final res = await ApiService().post('salary/slip', {
        'employee_id': employeeId,
        'month': _selectedMonth,
      });
      if (mounted && res['success'] == true) {
        setState(() => _salarySlip = res['data']);
        _showSalarySlipDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to fetch salary slip'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error fetching slip: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    if (mounted) setState(() => _loadingSlip = false);
  }

  // ==================== FIXED: Safe Number Conversion ====================
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  void _showSalarySlipDialog() {
    if (_salarySlip == null) return;

    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Salary Slip',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildSalarySlipContent(),
                ),
              ),
              // Bottom Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadPDF(),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Download PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _printSlip(),
                        icon: const Icon(Icons.print),
                        label: const Text('Print'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalarySlipContent() {
    final s = _salarySlip!;
    final employee = s['employee'] ?? {};
    final salary = s['salary'] ?? {};

    // FIXED: Safe extraction of values with proper type conversion
    final basicSalary = _toDouble(salary['basic_salary']);
    final presentDays = _toInt(salary['present_days']);
    final paidLeaveDays = _toInt(salary['paid_leave_days']);
    final earnedLeaveDays = _toInt(salary['earned_leave_days']);
    final totalEarnings = _toDouble(salary['total_earnings']);
    final unpaidLeaveDays = _toInt(salary['unpaid_leave_days']);
    final absentDays = _toInt(salary['absent_days']);
    final halfDays = _toInt(salary['half_days']);
    final lateDays = _toInt(salary['late_days']);
    final otherDeductions = _toDouble(salary['other_deductions']);
    final totalDeductions = _toDouble(salary['total_deductions']);
    final netSalary = _toDouble(salary['net_salary']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company Header
        Center(
          child: Column(
            children: [
              Text(
                'YATHARTH INSTITUTION',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A5F),
                ),
              ),
              Text(
                'Salary Slip - ${_selectedMonth.replaceAll('-', ' ')}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const Divider(thickness: 2),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Employee Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _infoRow('Employee Name', employee['name'] ?? ''),
              _infoRow('Employee Code', employee['code'] ?? ''),
              _infoRow('Department', employee['department'] ?? ''),
              _infoRow('Designation', employee['designation'] ?? ''),
              _infoRow('Month', _selectedMonth.replaceAll('-', ' ')),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Earnings
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.arrow_upward, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'EARNINGS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.green),
              _amountRow('Basic Salary', basicSalary),
              _amountRow('Present Days', presentDays, isDays: true),
              _amountRow('Paid Leave', paidLeaveDays, isDays: true),
              _amountRow('Earned Leave', earnedLeaveDays, isDays: true),
              const Divider(color: Colors.green),
              _amountRow('Total Earnings', totalEarnings, isTotal: true, color: Colors.green),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Deductions
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.arrow_downward, color: Colors.red[700], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'DEDUCTIONS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.red),
              _amountRow('Unpaid Leave', unpaidLeaveDays, isDays: true),
              _amountRow('Absent Days', absentDays, isDays: true),
              _amountRow('Half Days', halfDays, isDays: true),
              _amountRow('Late Days', lateDays, isDays: true),
              _amountRow('Other Deductions', otherDeductions),
              const Divider(color: Colors.red),
              _amountRow('Total Deductions', totalDeductions, isTotal: true, color: Colors.red),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Net Payable
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'NET PAYABLE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹ ${NumberFormat('#,##0.00').format(netSalary)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Amount in Words
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Amount in Words: ${_numberToWords(netSalary)}',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ),

        const SizedBox(height: 12),
        Center(
          child: Text(
            'This is a computer generated salary slip.',
            style: TextStyle(color: Colors.grey[400], fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Text(
            ':  $value',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, dynamic value, {bool isDays = false, bool isTotal = false, Color? color}) {
    final amount = _toDouble(value);
    final days = _toInt(value);
    final displayValue = isDays ? days.toString() : '₹ ${NumberFormat('#,##0.00').format(amount)}';
    final isNegative = label.contains('Unpaid') ||
        label.contains('Absent') ||
        label.contains('Half') ||
        label.contains('Late') ||
        label.contains('Deductions');

    final textColor = isTotal ? color : (isNegative ? Colors.red[700] : Colors.grey[800]);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: textColor,
              fontSize: isTotal ? 14 : 13,
            ),
          ),
          Text(
            displayValue,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: textColor,
              fontSize: isTotal ? 14 : 13,
            ),
          ),
        ],
      ),
    );
  }

  void _downloadPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📄 PDF Download started...'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  void _printSlip() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🖨️ Printing...'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }

  String _numberToWords(double number) {
    return '${NumberFormat('#,##0.00').format(number)} Rupees Only';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(),
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
                  : _salaryData.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: RefreshIndicator(
                  onRefresh: _fetchSalaryData,
                  color: const Color(0xFF1E3A5F),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _salaryData.length,
                    itemBuilder: (ctx, i) {
                      final s = _salaryData[i];
                      return _buildGlassSalaryCard(s);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.attach_money_rounded,
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
                'Salary Report',
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
              _fetchSalaryData();
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

  // ==================== MONTH SELECTOR ====================
  Widget _buildMonthSelector() {
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
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
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
                    _selectedMonth = DateFormat('yyyy-MM').format(picked);
                    _fetchSalaryData();
                  });
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(
                        DateTime.parse('${_selectedMonth}-01'),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down_rounded, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.attach_money_rounded,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            'No salary data found',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'for ${DateFormat('MMMM yyyy').format(DateTime.parse('${_selectedMonth}-01'))}',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchSalaryData,
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
    );
  }

  // ==================== GLASS SALARY CARD ====================
  Widget _buildGlassSalaryCard(Map<String, dynamic> s) {
    final employee = s['employee'] ?? {};
    final salary = s['salary'] ?? {};

    // FIXED: Safe extraction with proper type conversion
    final netSalary = _toDouble(salary['net_salary']);
    final basicSalary = _toDouble(salary['basic_salary']);
    final totalDeductions = _toDouble(salary['total_deductions']);
    final presentDays = _toInt(salary['present_days']);
    final paidLeaveDays = _toInt(salary['paid_leave_days']);
    final earnedLeaveDays = _toInt(salary['earned_leave_days']);
    final absentDays = _toInt(salary['absent_days']);
    final unpaidLeaveDays = _toInt(salary['unpaid_leave_days']);
    final halfDays = _toInt(salary['half_days']);

    final totalLeave = paidLeaveDays + earnedLeaveDays;
    final totalAbsent = absentDays + unpaidLeaveDays;
    final progressPercent = basicSalary > 0 ? (netSalary / basicSalary) * 100 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with gradient border
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (employee['name'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
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
                      employee['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E3A5F),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${employee['code'] ?? ''} | ${employee['department'] ?? ''}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Net Salary
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹ ${NumberFormat('#,##0.00').format(netSalary)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  Text(
                    'Basic: ₹ ${NumberFormat('#,##0.00').format(basicSalary)}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPercent >= 80
                          ? Colors.green
                          : progressPercent >= 50
                          ? Colors.orange
                          : Colors.red,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${progressPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip('Present', presentDays, Colors.green),
              _buildStatChip('Leave', totalLeave, Colors.blue),
              _buildStatChip('Absent', totalAbsent, Colors.red),
              _buildStatChip('Deduction', totalDeductions, Colors.orange, isAmount: true),
            ],
          ),
          const SizedBox(height: 8),
          // View Slip Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _fetchSalarySlip(_toInt(employee['id'])),
              icon: _loadingSlip
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.remove_red_eye_rounded, size: 18),
              label: Text(
                _loadingSlip ? 'Loading...' : 'View Salary Slip',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, dynamic value, Color color, {bool isAmount = false}) {
    final displayValue = isAmount
        ? '₹${NumberFormat('#,##0').format(_toDouble(value))}'
        : _toInt(value).toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[500], fontSize: 10),
          ),
          Text(
            displayValue,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}