import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/api_service.dart';

class SalaryReportScreen extends StatefulWidget {
  const SalaryReportScreen({super.key});

  @override
  State<SalaryReportScreen> createState() => _SalaryReportScreenState();
}

class _SalaryReportScreenState extends State<SalaryReportScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _loadingSlip = false;
  bool _generatingPdf = false;
  List<dynamic> _salaryData = [];
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to fetch salary slip'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _loadingSlip = false);
  }

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
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
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
                        Icon(Icons.receipt_long_rounded, color: Colors.white),
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
                        onPressed: _generatingPdf ? null : () => _downloadPDF(),
                        icon: _generatingPdf
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(_generatingPdf ? 'Generating...' : 'Download PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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

    final basicSalary = _toDouble(salary['basic_salary']);
    final baseEarnedSalary = _toDouble(salary['base_earned_salary']);
    final bonusAmount = _toDouble(salary['bonus_amount']);
    final allowances = _toDouble(salary['total_earnings']);
    final grossEarnings = (baseEarnedSalary > 0 ? baseEarnedSalary : basicSalary) + (allowances > 0 ? allowances : bonusAmount);

    final presentDays = _toDouble(salary['present_days']);
    final paidLeaveDays = _toDouble(salary['paid_leave_days']);
    final earnedLeaveDays = _toDouble(salary['earned_leave_days']);
    final weeklyOffDays = _toDouble(salary['weekly_off_days']);
    final holidayDays = _toDouble(salary['holiday_days']);

    final unpaidLeaveDays = _toDouble(salary['unpaid_leave_days']);
    final absentDays = _toDouble(salary['absent_days']);
    final halfDays = _toDouble(salary['half_days']);
    final lateDays = _toDouble(salary['late_days']);
    final attendanceDeduction = _toDouble(salary['attendance_deduction']);
    final otherDeductions = _toDouble(salary['other_deductions']);
    final totalDeductions = _toDouble(salary['total_deductions']);

    final currentNetSalary = _toDouble(salary['current_net_salary'] ?? salary['net_salary']);
    final previousDue = _toDouble(salary['previous_due']);
    final totalPayable = _toDouble(salary['total_payable'] ?? currentNetSalary);
    final paidAmount = _toDouble(salary['paid_amount']);
    final remainingDue = _toDouble(salary['remaining_due'] ?? (totalPayable - paidAmount));
    final displayNet = totalPayable > 0 ? totalPayable : currentNetSalary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              const Text(
                'YATHARTH INSTITUTION',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              Text(
                'Salary Slip - ${_selectedMonth.replaceAll('-', ' ')}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Divider(thickness: 1.5),
            ],
          ),
        ),
        const SizedBox(height: 8),

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
        const SizedBox(height: 14),

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
              _amountRow('Basic Monthly Salary', basicSalary),
              if (allowances > 0 || bonusAmount > 0)
                _amountRow('Allowances / Bonus', allowances > 0 ? allowances : bonusAmount),
              _amountRow('Present Days', presentDays, isDays: true),
              _amountRow('Paid Leave', paidLeaveDays, isDays: true),
              if (earnedLeaveDays > 0)
                _amountRow('Earned Leave', earnedLeaveDays, isDays: true),
              if (weeklyOffDays > 0)
                _amountRow('Weekly Off', weeklyOffDays, isDays: true),
              if (holidayDays > 0)
                _amountRow('Holidays', holidayDays, isDays: true),
              const Divider(color: Colors.green),
              _amountRow('Total Gross Earnings', grossEarnings, isTotal: true, color: Colors.green[800]),
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
              if (attendanceDeduction > 0)
                _amountRow('Attendance Deduction', attendanceDeduction),
              if (otherDeductions > 0)
                _amountRow('Other Deductions', otherDeductions),
              const Divider(color: Colors.red),
              _amountRow('Total Deductions', totalDeductions, isTotal: true, color: Colors.red[800]),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Net & Ledger Summary
        if (previousDue > 0 || paidAmount > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              children: [
                _amountRow('Current Month Net', currentNetSalary),
                if (previousDue > 0)
                  _amountRow('Previous Due (Carry Forward)', previousDue, color: Colors.red[700]),
                if (paidAmount > 0)
                  _amountRow('Amount Paid', paidAmount, color: Colors.green[700]),
                if (remainingDue > 0 && previousDue > 0)
                  _amountRow('Remaining Outstanding Due', remainingDue, isTotal: true, color: Colors.red[800]),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Net Payable Banner
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
              Text(
                previousDue > 0 ? 'TOTAL PAYABLE' : 'NET PAYABLE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹ ${NumberFormat('#,##0.00').format(displayNet)}',
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
            'Amount in Words: ${_numberToWords(displayNet)}',
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ),

        // Payment Transactions & History Section (if any payments exist)
        if ((s['payments'] is List) && (s['payments'] as List).isNotEmpty) ...[
          const SizedBox(height: 14),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: Colors.green[800], size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'PAYMENT TRANSACTIONS',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green[900]),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(s['payments'] as List).length} PAID',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green[900]),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.green),
                ...(s['payments'] as List).map((p) {
                  final pAmount = _toDouble(p['amount']);
                  final pDate = p['payment_date'] ?? '';
                  final pMethod = (p['payment_method'] ?? 'bank_transfer').toString().replaceAll('_', ' ').toUpperCase();
                  final pRef = p['reference_no'] ?? '';
                  final pNotes = p['notes'] ?? '';
                  final pCreatedBy = p['created_by_name'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹ ${NumberFormat('#,##0.00').format(pAmount)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[800]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pMethod,
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green[900]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Date: $pDate', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                            if (pRef.toString().isNotEmpty)
                              Text('Ref: $pRef', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                          ],
                        ),
                        if (pNotes.toString().isNotEmpty || pCreatedBy.toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${pNotes.isNotEmpty ? pNotes : ''}${pCreatedBy.isNotEmpty ? ' (By: $pCreatedBy)' : ''}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showMonthWiseLedgerSheet(_toInt(employee['id']), employee['name'] ?? 'Employee');
            },
            icon: const Icon(Icons.history_edu_rounded, size: 16),
            label: const Text(
              'View All Months Status (Paid & Pending)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A5F),
              side: const BorderSide(color: Color(0xFF1E3A5F), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
          Expanded(
            child: Text(
              ':  $value',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, dynamic value, {bool isDays = false, bool isTotal = false, Color? color}) {
    final amount = _toDouble(value);
    final days = _toDouble(value);
    final displayValue = isDays ? (days % 1 == 0 ? days.toInt().toString() : days.toString()) : '₹ ${NumberFormat('#,##0.00').format(amount)}';
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

  String _formatCurrency(double amount) {
    return 'Rs. ${NumberFormat('#,##0.00').format(amount)}';
  }

  String _numberToWordsIndian(double number) {
    int n = number.round();
    if (n <= 0) return 'Zero Rupees Only';

    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String convertLessThanOneThousand(int num) {
      String current = '';
      if (num % 100 < 20) {
        current = units[num % 100];
        num = num ~/ 100;
      } else {
        current = units[num % 10];
        num = num ~/ 10;
        current = '${tens[num % 10]} $current'.trim();
        num = num ~/ 10;
      }
      if (num == 0) return current;
      return '${units[num]} Hundred $current'.trim();
    }

    String result = '';
    int crore = n ~/ 10000000;
    n %= 10000000;
    int lakh = n ~/ 100000;
    n %= 100000;
    int thousand = n ~/ 1000;
    n %= 1000;
    int remainder = n;

    if (crore > 0) result += '${convertLessThanOneThousand(crore)} Crore ';
    if (lakh > 0) result += '${convertLessThanOneThousand(lakh)} Lakh ';
    if (thousand > 0) result += '${convertLessThanOneThousand(thousand)} Thousand ';
    if (remainder > 0) result += convertLessThanOneThousand(remainder);

    return '${result.trim()} Rupees Only';
  }

  Future<void> _downloadPDF() async {
    if (_salarySlip == null) return;
    setState(() => _generatingPdf = true);

    try {
      final s = _salarySlip!;
      final employee = s['employee'] ?? {};
      final salary = s['salary'] ?? {};

      final empName = employee['name'] ?? 'Employee';
      final empCode = employee['code'] ?? '-';
      final empDept = employee['department'] ?? '-';
      final empDesg = employee['designation'] ?? '-';

      final basicSalary = _toDouble(salary['basic_salary']);
      final baseEarnedSalary = _toDouble(salary['base_earned_salary']);
      final presentDays = _toDouble(salary['present_days']);
      final paidLeave = _toDouble(salary['paid_leave_days']);
      final earnedLeave = _toDouble(salary['earned_leave_days']);
      final weeklyOff = _toDouble(salary['weekly_off_days']);
      final holidays = _toDouble(salary['holiday_days']);
      final allowances = _toDouble(salary['total_earnings'] ?? salary['bonus_amount']);
      final grossEarnings = (baseEarnedSalary > 0 ? baseEarnedSalary : basicSalary) + allowances;

      final unpaidLeave = _toDouble(salary['unpaid_leave_days']);
      final absentDays = _toDouble(salary['absent_days']);
      final halfDays = _toDouble(salary['half_days']);
      final lateDays = _toDouble(salary['late_days']);
      final attendanceDeduction = _toDouble(salary['attendance_deduction']);
      final otherDeductions = _toDouble(salary['other_deductions']);
      final totalDeductions = _toDouble(salary['total_deductions']);

      final currentNet = _toDouble(salary['current_net_salary'] ?? salary['net_salary']);
      final previousDue = _toDouble(salary['previous_due']);
      final totalPayable = _toDouble(salary['total_payable'] ?? currentNet);
      final paidAmount = _toDouble(salary['paid_amount']);
      final remainingDue = _toDouble(salary['remaining_due'] ?? (totalPayable - paidAmount));
      final finalNet = totalPayable > 0 ? totalPayable : currentNet;
      final paymentStatus = (salary['payment_status'] ?? (remainingDue <= 0 && paidAmount > 0 ? 'paid' : (paidAmount > 0 ? 'partially_paid' : 'unpaid'))).toString().toUpperCase();

      // Format month name nicely (e.g. September 2026)
      String monthDisplay = _selectedMonth;
      try {
        final parsedDate = DateTime.parse('${_selectedMonth}-01');
        monthDisplay = DateFormat('MMMM yyyy').format(parsedDate);
      } catch (_) {}

      // Load company logo asset
      pw.MemoryImage? logoImage;
      try {
        final logoData = await rootBundle.load('assets/images/logo25.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {
        try {
          final logoData2 = await rootBundle.load('assets/images/logo.png');
          logoImage = pw.MemoryImage(logoData2.buffer.asUint8List());
        } catch (_) {}
      }

      final navyColor = PdfColor.fromHex('1E3A5F');
      final darkNavy = PdfColor.fromHex('0B2545');
      final lightBg = PdfColor.fromHex('F8FAFC');
      final borderGrey = PdfColor.fromHex('CBD5E1');
      final greenBg = PdfColor.fromHex('F0FDF4');
      final greenBorder = PdfColor.fromHex('86EFAC');
      final greenText = PdfColor.fromHex('166534');
      final redBg = PdfColor.fromHex('FEF2F2');
      final redBorder = PdfColor.fromHex('FECACA');
      final redText = PdfColor.fromHex('991B1B');

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: navyColor, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
              ),
              child: pw.Column(
                children: [
                  // 1. Top Royal Header Banner
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: pw.BoxDecoration(
                      color: navyColor,
                      borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(8)),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            if (logoImage != null) ...[
                              pw.Container(
                                width: 44,
                                height: 44,
                                padding: const pw.EdgeInsets.all(3),
                                decoration: const pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                                ),
                                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                              ),
                              pw.SizedBox(width: 12),
                            ],
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'YATHARTH INSTITUTION',
                                  style: pw.TextStyle(
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Employee Management System - Official Pay Slip',
                                  style: const pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.grey300,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'PAYSLIP',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: navyColor,
                                ),
                              ),
                              pw.Text(
                                monthDisplay,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Container
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(14),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // 2. Employee Details Card
                        pw.Container(
                          padding: const pw.EdgeInsets.all(10),
                          decoration: pw.BoxDecoration(
                            color: lightBg,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: borderGrey),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    _pdfKeyValue('Employee Name', empName, isBold: true),
                                    pw.SizedBox(height: 4),
                                    _pdfKeyValue('Employee Code', empCode),
                                    pw.SizedBox(height: 4),
                                    _pdfKeyValue('Department', empDept),
                                  ],
                                ),
                              ),
                              pw.SizedBox(width: 16),
                              pw.Expanded(
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    _pdfKeyValue('Designation', empDesg),
                                    pw.SizedBox(height: 4),
                                    _pdfKeyValue('Pay Period', monthDisplay),
                                    pw.SizedBox(height: 4),
                                    _pdfKeyValue('Status', paymentStatus, isStatus: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 10),

                        // 3. Attendance Summary Strip
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: borderGrey),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                            children: [
                              _pdfMiniStat('Present Days', '${presentDays.toStringAsFixed(presentDays % 1 == 0 ? 0 : 1)}'),
                              _pdfMiniStat('Paid Leave', '${paidLeave.toStringAsFixed(paidLeave % 1 == 0 ? 0 : 1)}'),
                              if (earnedLeave > 0)
                                _pdfMiniStat('Earned Leave', '${earnedLeave.toStringAsFixed(earnedLeave % 1 == 0 ? 0 : 1)}'),
                              _pdfMiniStat('Weekly / Holiday', '${(weeklyOff + holidays).toStringAsFixed((weeklyOff + holidays) % 1 == 0 ? 0 : 1)}'),
                              _pdfMiniStat('Absent / LOP', '${(absentDays + unpaidLeave).toStringAsFixed((absentDays + unpaidLeave) % 1 == 0 ? 0 : 1)}', isAlert: (absentDays + unpaidLeave) > 0),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 10),

                        // 4. Earnings vs Deductions Table
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Earnings Column
                            pw.Expanded(
                              child: pw.Container(
                                decoration: pw.BoxDecoration(
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                  border: pw.Border.all(color: greenBorder),
                                ),
                                child: pw.Column(
                                  children: [
                                    pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: pw.BoxDecoration(
                                        color: greenBg,
                                        borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
                                      ),
                                      child: pw.Row(
                                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text('EARNINGS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: greenText)),
                                          pw.Text('AMOUNT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: greenText)),
                                        ],
                                      ),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(8),
                                      child: pw.Column(
                                        children: [
                                          _pdfAmountRow('Basic Salary', _formatCurrency(basicSalary)),
                                          if (allowances > 0)
                                            _pdfAmountRow('Allowances / Bonus', _formatCurrency(allowances)),
                                          _pdfAmountRow('Present Days Earned', '${presentDays.toStringAsFixed(presentDays % 1 == 0 ? 0 : 1)} Days'),
                                          _pdfAmountRow('Paid Leave Days', '${paidLeave.toStringAsFixed(paidLeave % 1 == 0 ? 0 : 1)} Days'),
                                          if (earnedLeave > 0)
                                            _pdfAmountRow('Earned Leaves', '${earnedLeave.toStringAsFixed(earnedLeave % 1 == 0 ? 0 : 1)} Days'),
                                          pw.Divider(color: greenBorder, thickness: 1),
                                          _pdfAmountRow('Total Gross Earnings', _formatCurrency(grossEarnings), isBold: true, textColor: greenText),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            pw.SizedBox(width: 10),
                            // Deductions Column
                            pw.Expanded(
                              child: pw.Container(
                                decoration: pw.BoxDecoration(
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                                  border: pw.Border.all(color: redBorder),
                                ),
                                child: pw.Column(
                                  children: [
                                    pw.Container(
                                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: pw.BoxDecoration(
                                        color: redBg,
                                        borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
                                      ),
                                      child: pw.Row(
                                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text('DEDUCTIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: redText)),
                                          pw.Text('AMOUNT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: redText)),
                                        ],
                                      ),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.all(8),
                                      child: pw.Column(
                                        children: [
                                          _pdfAmountRow('Unpaid Leave (LOP)', '${unpaidLeave.toStringAsFixed(unpaidLeave % 1 == 0 ? 0 : 1)} Days'),
                                          _pdfAmountRow('Absent Days', '${absentDays.toStringAsFixed(absentDays % 1 == 0 ? 0 : 1)} Days'),
                                          _pdfAmountRow('Half Days / Late', '${(halfDays + lateDays).toStringAsFixed((halfDays + lateDays) % 1 == 0 ? 0 : 1)} Days'),
                                          if (attendanceDeduction > 0)
                                            _pdfAmountRow('Attendance Deduction', _formatCurrency(attendanceDeduction)),
                                          if (otherDeductions > 0)
                                            _pdfAmountRow('Other Deductions', _formatCurrency(otherDeductions)),
                                          pw.Divider(color: redBorder, thickness: 1),
                                          _pdfAmountRow('Total Deductions', _formatCurrency(totalDeductions), isBold: true, textColor: redText),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 10),

                        // 5. Ledger Breakdown (Previous Due, Paid, Remaining)
                        if (previousDue > 0 || paidAmount > 0) ...[
                          pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            decoration: pw.BoxDecoration(
                              color: lightBg,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              border: pw.Border.all(color: borderGrey),
                            ),
                            child: pw.Column(
                              children: [
                                _pdfAmountRow('Current Month Net Salary', _formatCurrency(currentNet)),
                                if (previousDue > 0)
                                  _pdfAmountRow('Previous Unpaid Due (Carry Forward)', '+ ${_formatCurrency(previousDue)}', textColor: redText),
                                if (paidAmount > 0)
                                  _pdfAmountRow('Amount Disbursed / Paid', '- ${_formatCurrency(paidAmount)}', textColor: greenText),
                                if (remainingDue > 0)
                                  _pdfAmountRow('Outstanding Balance Due', _formatCurrency(remainingDue), isBold: true, textColor: redText),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 10),
                        ],

                        // 6. Net Payable Banner
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: pw.BoxDecoration(
                            color: darkNavy,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    previousDue > 0 ? 'TOTAL PAYABLE (INCL. PREV DUE)' : 'NET SALARY PAYABLE',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                      color: PdfColors.white,
                                    ),
                                  ),
                                  pw.Text(
                                    _numberToWordsIndian(finalNet),
                                    style: const pw.TextStyle(
                                      fontSize: 8,
                                      color: PdfColors.grey300,
                                    ),
                                  ),
                                ],
                              ),
                              pw.Text(
                                _formatCurrency(finalNet),
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 16,
                                  color: PdfColors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 35),

                        // 7. Signatures Area
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Container(
                                  width: 140,
                                  decoration: const pw.BoxDecoration(
                                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey500, width: 1)),
                                  ),
                                  padding: const pw.EdgeInsets.only(top: 4),
                                  child: pw.Center(
                                    child: pw.Text(
                                      'Employee Signature',
                                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Container(
                                  width: 160,
                                  decoration: const pw.BoxDecoration(
                                    border: pw.Border(top: pw.BorderSide(color: PdfColors.grey500, width: 1)),
                                  ),
                                  padding: const pw.EdgeInsets.only(top: 4),
                                  child: pw.Center(
                                    child: pw.Text(
                                      'Authorized Signatory (HR / Director)',
                                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyColor),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 14),

                        // 8. Bottom Footnote
                        pw.Center(
                          child: pw.Text(
                            'This is a computer-generated document from Yatharth EMS and does not require a physical stamp.',
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Salary_Slip_${empCode}_$_selectedMonth.pdf');
      await file.writeAsBytes(bytes);

      if (mounted) {
        OpenFilex.open(file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('✅ Salary Slip PDF downloaded: ${file.path.split('/').last}')),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  pw.Widget _pdfKeyValue(String key, String value, {bool isBold = false, bool isStatus = false}) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 85,
          child: pw.Text(
            '$key:',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isStatus
                  ? (value == 'PAID' ? PdfColors.green800 : (value == 'UNPAID' ? PdfColors.red800 : PdfColors.orange800))
                  : PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfMiniStat(String title, String value, {bool isAlert = false}) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: isAlert ? PdfColors.red800 : PdfColors.blue900,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfAmountRow(String label, String value, {bool isBold = false, PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? PdfColors.grey800,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  String _numberToWords(double number) {
    return _numberToWordsIndian(number);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildMonthSelector(),
            if (!_loading && _salaryData.isNotEmpty) _buildSummaryHeader(),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildSummaryHeader() {
    double totalPayroll = 0;
    double totalPaid = 0;
    double totalDue = 0;

    for (var item in _salaryData) {
      final sal = item['salary'] ?? {};
      final payable = _toDouble(sal['total_payable'] ?? sal['current_net_salary'] ?? sal['net_salary']);
      final paid = _toDouble(sal['paid_amount']);
      final due = _toDouble(sal['remaining_due'] ?? (payable - paid));
      totalPayroll += payable;
      totalPaid += paid;
      totalDue += due;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Expanded(
            child: _summaryStatItem('Total Payable', totalPayroll, const Color(0xFF1E3A5F)),
          ),
          Container(width: 1, height: 35, color: Colors.grey[200]),
          Expanded(
            child: _summaryStatItem('Total Paid', totalPaid, Colors.green[700]!),
          ),
          Container(width: 1, height: 35, color: Colors.grey[200]),
          Expanded(
            child: _summaryStatItem('Outstanding', totalDue, Colors.red[700]!),
          ),
        ],
      ),
    );
  }

  Widget _summaryStatItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          '₹${NumberFormat('#,##0').format(amount)}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

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
          margin: const EdgeInsets.only(right: 8),
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
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      centerTitle: false,
    );
  }

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
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSalaryCard(Map<String, dynamic> s) {
    final employee = s['employee'] ?? {};
    final salary = s['salary'] ?? {};
    final running = s['running_salary'];

    final basicSalary = _toDouble(salary['basic_salary']);
    final currentNet = _toDouble(salary['current_net_salary'] ?? salary['net_salary']);
    final previousDue = _toDouble(salary['previous_due']);
    final totalPayable = _toDouble(salary['total_payable'] ?? currentNet);
    final paidAmount = _toDouble(salary['paid_amount']);
    final remainingDue = _toDouble(salary['remaining_due'] ?? (totalPayable - paidAmount));
    final status = (salary['payment_status'] ?? 'unpaid').toString().toLowerCase();

    final presentDays = _toDouble(salary['present_days']);
    final paidLeaveDays = _toDouble(salary['paid_leave_days']);
    final earnedLeaveDays = _toDouble(salary['earned_leave_days']);
    final absentDays = _toDouble(salary['absent_days']);
    final unpaidLeaveDays = _toDouble(salary['unpaid_leave_days']);
    final halfDays = _toDouble(salary['half_days']);
    final totalDeductions = _toDouble(salary['total_deductions']);

    final totalLeave = paidLeaveDays + earnedLeaveDays;
    final totalAbsent = absentDays + unpaidLeaveDays;
    final progressPercent = basicSalary > 0 ? (currentNet / basicSalary) * 100 : 0;

    Color statusBg = Colors.red[50]!;
    Color statusColor = Colors.red[700]!;
    String statusText = 'UNPAID';
    if (status == 'paid') {
      statusBg = Colors.green[50]!;
      statusColor = Colors.green[700]!;
      statusText = 'PAID';
    } else if (status == 'partially_paid' || paidAmount > 0) {
      statusBg = Colors.orange[50]!;
      statusColor = Colors.orange[800]!;
      statusText = 'PARTIAL';
    }

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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Name, Status Badge & Net Payable
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 44,
                  height: 44,
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
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                      '${employee['code'] ?? ''} • ${employee['department'] ?? ''}',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹ ${NumberFormat('#,##0.00').format(totalPayable)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Running Salary Highlight (if ongoing month)
          if (running != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Running (${running['eligible_days_till_today']}d worked):',
                        style: TextStyle(fontSize: 11, color: Colors.blue[900], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Text(
                    '₹ ${NumberFormat('#,##0.00').format(_toDouble(running['estimated_earned_salary']))}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                  ),
                ],
              ),
            ),
          ],

          // Ledger Breakdown Row
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ledgerMiniCol('Current Net', currentNet, const Color(0xFF1E3A5F)),
                _ledgerMiniCol('Prev Due', previousDue, previousDue > 0 ? Colors.red[700]! : Colors.grey[600]!),
                _ledgerMiniCol('Paid', paidAmount, paidAmount > 0 ? Colors.green[700]! : Colors.grey[600]!),
                _ledgerMiniCol('Remaining', remainingDue, remainingDue > 0 ? Colors.red[700]! : Colors.grey[600]!),
              ],
            ),
          ),

          const SizedBox(height: 8),
          // Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (progressPercent / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPercent >= 80
                          ? Colors.green
                          : progressPercent >= 50
                              ? Colors.orange
                              : Colors.red,
                    ),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${progressPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10,
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
              _buildStatChip('Deductions', totalDeductions, Colors.orange, isAmount: true),
            ],
          ),
          const SizedBox(height: 8),

          // Action Buttons (View Slip & Month-wise Ledger)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () => _fetchSalarySlip(_toInt(employee['id'])),
                  icon: _loadingSlip
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.remove_red_eye_rounded, size: 16),
                  label: Text(
                    _loadingSlip ? 'Loading...' : 'Salary Slip',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: () => _showMonthWiseLedgerSheet(_toInt(employee['id']), employee['name'] ?? 'Employee'),
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                  label: const Text(
                    'Months Ledger',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E3A5F),
                    side: const BorderSide(color: Color(0xFF1E3A5F), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMonthWiseLedgerSheet(int employeeId, String empName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MonthWiseLedgerModal(
        employeeId: employeeId,
        employeeName: empName,
        toDouble: _toDouble,
        toInt: _toInt,
      ),
    );
  }

  void _showPaymentHistoryDialog(Map<String, dynamic> item) {
    final employee = item['employee'] ?? {};
    final payments = (item['payments'] as List<dynamic>?) ?? [];
    final empName = employee['name'] ?? 'Employee';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Transactions',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                          ),
                          Text(empName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          '${payments.length} Transaction${payments.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[800]),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Expanded(
                    child: payments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 8),
                                Text('No payment transactions found', style: TextStyle(color: Colors.grey[500])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: payments.length,
                            itemBuilder: (context, i) {
                              final p = payments[i];
                              final pAmount = _toDouble(p['amount']);
                              final pDate = p['payment_date'] ?? '';
                              final pMethod = (p['payment_method'] ?? 'bank_transfer').toString().replaceAll('_', ' ').toUpperCase();
                              final pRef = p['reference_no'] ?? '';
                              final pNotes = p['notes'] ?? '';
                              final pCreatedBy = p['created_by_name'] ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '₹ ${NumberFormat('#,##0.00').format(pAmount)}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green[800]),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blue[100]!),
                                          ),
                                          child: Text(
                                            pMethod,
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text('Date: $pDate', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                                          ],
                                        ),
                                        if (pRef.toString().isNotEmpty)
                                          Text('Ref: $pRef', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                                      ],
                                    ),
                                    if (pNotes.toString().isNotEmpty || pCreatedBy.toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '${pNotes.isNotEmpty ? pNotes : ''}${pCreatedBy.isNotEmpty ? ' (Recorded by: $pCreatedBy)' : ''}',
                                        style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _ledgerMiniCol(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        Text(
          '₹${NumberFormat('#,##0').format(amount)}',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, dynamic value, Color color, {bool isAmount = false}) {
    final displayValue = isAmount
        ? '₹${NumberFormat('#,##0').format(_toDouble(value))}'
        : (_toDouble(value) % 1 == 0 ? _toInt(value).toString() : value.toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[500], fontSize: 9),
          ),
          Text(
            displayValue,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _MonthWiseLedgerModal extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  final double Function(dynamic) toDouble;
  final int Function(dynamic) toInt;

  const _MonthWiseLedgerModal({
    required this.employeeId,
    required this.employeeName,
    required this.toDouble,
    required this.toInt,
  });

  @override
  State<_MonthWiseLedgerModal> createState() => _MonthWiseLedgerModalState();
}

class _MonthWiseLedgerModalState extends State<_MonthWiseLedgerModal> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _ledgerData;

  @override
  void initState() {
    super.initState();
    _fetchLedger();
  }

  Future<void> _fetchLedger() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService().post('salary/ledger', {
        'employee_id': widget.employeeId,
      });

      if (mounted) {
        if (res['success'] == true) {
          setState(() => _ledgerData = res['data']);
        } else {
          setState(() => _error = res['message'] ?? 'Failed to load ledger');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_edu_rounded, color: Color(0xFF1E3A5F), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Monthly Salary Ledger',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            Text(
                              widget.employeeName,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Content
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1E3A5F),
                            strokeWidth: 3,
                          ),
                        )
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline_rounded, size: 40, color: Colors.red[300]),
                                  const SizedBox(height: 8),
                                  Text(_error!, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _fetchLedger,
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E3A5F),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildLedgerContent(scrollController),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLedgerContent(ScrollController scrollController) {
    if (_ledgerData == null) return const SizedBox.shrink();

    final summary = _ledgerData!['summary'] ?? {};
    final months = (_ledgerData!['months'] as List<dynamic>?) ?? [];
    final totalEarned = widget.toDouble(summary['total_earned']);
    final totalPaid = widget.toDouble(summary['total_paid']);
    final totalDue = widget.toDouble(summary['total_outstanding_due']);
    final paidMonthsList = (summary['paid_months'] as List<dynamic>?) ?? [];
    final unpaidMonthsList = (summary['unpaid_months'] as List<dynamic>?) ?? [];

    return ListView(
      controller: scrollController,
      children: [
        // 1. Summary Cards (Total Received vs Total Baki)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'TOTAL RECEIVED',
                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹ ${NumberFormat('#,##0.00').format(totalPaid)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${paidMonthsList.length} Month${paidMonthsList.length == 1 ? '' : 's'} Paid',
                            style: TextStyle(color: Colors.greenAccent[100], fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pending_actions_rounded, color: Colors.orangeAccent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'OUTSTANDING BAKI',
                                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹ ${NumberFormat('#,##0.00').format(totalDue)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${unpaidMonthsList.length} Month${unpaidMonthsList.length == 1 ? '' : 's'} Pending',
                            style: TextStyle(color: Colors.orangeAccent[100], fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Earned (All Months):',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11),
                    ),
                    Text(
                      '₹ ${NumberFormat('#,##0.00').format(totalEarned)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Month Status Chips
        const Text(
          'Month-by-Month Status Breakdown',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
        ),
        const SizedBox(height: 10),

        // 2. Month-wise Timeline Cards
        ...months.map((m) {
          final mName = m['month_name'] ?? m['month_year'] ?? '';
          final netSal = widget.toDouble(m['net_salary']);
          final paidAmt = widget.toDouble(m['paid_amount']);
          final remDue = widget.toDouble(m['remaining_due']);
          final status = (m['payment_status'] ?? 'unpaid').toString().toLowerCase();
          final isCurrent = m['is_current'] == true;
          final payments = (m['payments'] as List<dynamic>?) ?? [];

          final isPaid = status == 'paid' || (paidAmt >= netSal && netSal > 0);
          final isPartial = status == 'partially_paid' || (paidAmt > 0 && remDue > 0);

          Color cardBorder = isPaid ? Colors.green[200]! : (isPartial ? Colors.orange[200]! : Colors.red[200]!);
          Color statusBg = isPaid ? Colors.green[50]! : (isPartial ? Colors.orange[50]! : Colors.red[50]!);
          Color statusText = isPaid ? Colors.green[800]! : (isPartial ? Colors.orange[800]! : Colors.red[800]!);
          String statusLabel = isPaid ? 'PAID / MIL GYA' : (isPartial ? 'PARTIALLY PAID' : (isCurrent ? 'CURRENT MONTH (DUE)' : 'UNPAID / BAKI'));
          IconData statusIcon = isPaid ? Icons.check_circle_rounded : (isPartial ? Icons.timelapse_rounded : Icons.cancel_rounded);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: cardBorder.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header of Month Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 16,
                            color: const Color(0xFF1E3A5F),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A5F)),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Running', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, size: 12, color: statusText),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusText),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Body of Month Card
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statBox('Net Salary', '₹ ${NumberFormat('#,##0.00').format(netSal)}', const Color(0xFF1E3A5F)),
                          _statBox('Amount Paid', '₹ ${NumberFormat('#,##0.00').format(paidAmt)}', Colors.green[700]!),
                          _statBox('Balance Baki', '₹ ${NumberFormat('#,##0.00').format(remDue)}', remDue > 0 ? Colors.red[700]! : Colors.grey[600]!),
                        ],
                      ),

                      // If payments exist for this month
                      if (payments.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.payment_rounded, size: 13, color: Colors.green[800]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Payment Received Details:',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green[900]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ...payments.map((p) {
                                final pAmt = widget.toDouble(p['amount']);
                                final pDt = p['payment_date'] ?? '';
                                final pMode = (p['payment_method'] ?? 'bank_transfer').toString().replaceAll('_', ' ').toUpperCase();
                                final pRef = p['reference_no'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '• ₹ ${NumberFormat('#,##0.00').format(pAmt)} on $pDt via $pMode${pRef.isNotEmpty ? ' (Ref: $pRef)' : ''}',
                                    style: TextStyle(fontSize: 10, color: Colors.green[900], fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}