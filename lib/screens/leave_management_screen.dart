import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class LeaveManagementScreen extends StatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  State<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends State<LeaveManagementScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _leaves = [];
  List<dynamic> _balances = [];
  bool _loading = true;
  int _tabIndex = 0;
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
    _fetch();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('leaves/my');
      if (mounted && res['success'] == true) setState(() => _leaves = res['data'] ?? []);
      final bal = await ApiService().get('leaves/balance');
      if (mounted && bal['success'] == true) setState(() => _balances = bal['data'] ?? []);
    } catch (e) { debugPrint('leave_management_screen: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Approved':
        return Icons.check_circle_rounded;
      case 'Rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(),
      floatingActionButton: _buildFAB(),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1E3A5F),
                  strokeWidth: 3,
                ),
              )
            : Column(
                children: [
                  _buildTabRow(),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _tabIndex == 0 ? _buildLeaveList() : _buildBalance(),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.time_to_leave_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
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
                'Leave Management System',
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
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetch();
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 22,
            ),
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

  // ==================== FLOATING ACTION BUTTON ====================
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        HapticFeedback.mediumImpact();
        _showApplyForm(context);
      },
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded, size: 24),
      label: const Text(
        'Apply Leave',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  // ==================== TAB ROW ====================
  Widget _buildTabRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        children: [
          Expanded(
            child: _buildGlassTab('My Leaves (${_leaves.length})', 0),
          ),
          Expanded(
            child: _buildGlassTab('Leave Balances', 1),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTab(String label, int idx) {
    final isSelected = _tabIndex == idx;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _tabIndex = idx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F).withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== LEAVE LIST WITH BALANCE SUMMARY ====================
  Widget _buildLeaveList() {
    return RefreshIndicator(
      onRefresh: _fetch,
      color: const Color(0xFF1E3A5F),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildBalanceSummaryCard(),
          const SizedBox(height: 12),
          if (_leaves.isEmpty)
            _buildEmptyState(
              icon: Icons.event_note_rounded,
              message: 'No leaves applied yet',
              subMessage: 'Tap Apply Leave to submit a request',
            )
          else
            ..._leaves.map((l) => _buildLeaveCard(l)),
        ],
      ),
    );
  }

  // ==================== BALANCE SUMMARY CARD ====================
  Widget _buildBalanceSummaryCard() {
    return Container(
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
            color: const Color(0xFF1E3A5F).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
              SizedBox(width: 6),
              Text(
                'Leave Balance Summary (Annual)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _balances.map((b) {
                final type = b['leave_type'] ?? '';
                final remaining = b['remaining'] ?? 0;
                final allotted = b['allotted'] ?? 0;
                final used = b['used'] ?? 0;

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$remaining',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            ' / $allotted left',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                      Text(
                        'Used: $used',
                        style: const TextStyle(color: Colors.white54, fontSize: 9),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> l) {
    final status = l['status'] ?? 'Pending';
    final statusColor = _statusColor(status);
    final days = l['total_days'] ?? 1;

    return GestureDetector(
      onTap: () => _showLeaveDetails(l),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l['leave_type'] ?? 'Leave',
                    style: const TextStyle(
                      color: Color(0xFF1E3A5F),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(_statusIcon(status), color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.date_range_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  '${l['start_date']}  →  ${l['end_date']}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$days day(s)',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            if (l['reason'] != null && l['reason'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Reason: ${l['reason']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
            if (l['remarks'] != null && l['remarks'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: status == 'Rejected' ? Colors.red.withOpacity(0.05) : Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: status == 'Rejected' ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  'Admin Remarks: ${l['remarks']}',
                  style: TextStyle(
                    color: status == 'Rejected' ? Colors.red[700] : Colors.green[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== BALANCE TAB ====================
  Widget _buildBalance() {
    if (_balances.isEmpty) {
      return _buildEmptyState(
        icon: Icons.account_balance_wallet_rounded,
        message: 'No leave balances recorded',
        subMessage: 'Pull down to refresh balances',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: const Color(0xFF1E3A5F),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _balances.length,
        itemBuilder: (_, i) {
          final b = _balances[i];
          final type = b['leave_type'] ?? '';
          final allotted = b['allotted'] ?? 0;
          final used = b['used'] ?? 0;
          final remaining = b['remaining'] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: Color(0xFF1E3A5F),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Allotted: $allotted days  •  Used: $used days',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$remaining',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const Text(
                        'Remaining',
                        style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
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
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState({required IconData icon, required String message, required String subMessage}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(subMessage, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  // ==================== LEAVE DETAILS MODAL ====================
  void _showLeaveDetails(Map<String, dynamic> l) async {
    HapticFeedback.lightImpact();
    final status = l['status'] ?? 'Pending';
    final statusColor = _statusColor(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_note_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('Leave Request Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Leave Type', l['leave_type'] ?? 'N/A'),
            _buildDetailRow('From Date', l['start_date'] ?? 'N/A'),
            _buildDetailRow('To Date', l['end_date'] ?? 'N/A'),
            _buildDetailRow('Day Type', l['day_type'] ?? 'Full Day'),
            _buildDetailRow('Total Days', '${l['total_days'] ?? 1}'),
            _buildDetailRow('Reason', l['reason'] ?? 'N/A'),
            if (l['remarks'] != null && l['remarks'].toString().isNotEmpty)
              _buildDetailRow('Admin Remarks', l['remarks']),
            if (l['attachment_url'] != null || l['attachment'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: const [
                    Icon(Icons.attach_file_rounded, size: 16, color: Colors.blue),
                    SizedBox(width: 6),
                    Text('Attachment Uploaded', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E3A5F))),
          ),
        ],
      ),
    );
  }

  // ==================== APPLY LEAVE FORM ====================
  void _showApplyForm(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final reasonCtrl = TextEditingController();
    String leaveType = 'Casual Leave';
    String dayType = 'Full Day'; // Full Day vs Half Day
    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now();
    File? attachment;
    bool submitting = false;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          double calcDays() {
            if (dayType == 'Half Day' || leaveType == 'Half Day') return 0.5;
            return (toDate.difference(fromDate).inDays + 1).toDouble();
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Apply Leave',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Leave Type Dropdown
                    DropdownButtonFormField<String>(
                      value: leaveType,
                      decoration: InputDecoration(
                        labelText: 'Leave Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Casual Leave', child: Text('Casual Leave (CL - 8 days/yr)')),
                        DropdownMenuItem(value: 'Sick Leave', child: Text('Sick Leave (SL - 8 days/yr)')),
                        DropdownMenuItem(value: 'Earned Leave', child: Text('Earned Leave (EL/PL - 15 days/yr)')),
                        DropdownMenuItem(value: 'Half Day', child: Text('Half Day Leave (0.5 day)')),
                        DropdownMenuItem(value: 'Leave Without Pay', child: Text('Unpaid Leave (LWP)')),
                      ],
                      onChanged: (v) => setLocalState(() => leaveType = v!),
                    ),
                    const SizedBox(height: 12),

                    // Full Day / Half Day Switch
                    Row(
                      children: [
                        const Text('Duration:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Full Day'),
                          selected: dayType == 'Full Day',
                          selectedColor: const Color(0xFF1E3A5F),
                          labelStyle: TextStyle(color: dayType == 'Full Day' ? Colors.white : Colors.black),
                          onSelected: (sel) => setLocalState(() => dayType = 'Full Day'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Half Day'),
                          selected: dayType == 'Half Day',
                          selectedColor: const Color(0xFF1E3A5F),
                          labelStyle: TextStyle(color: dayType == 'Half Day' ? Colors.white : Colors.black),
                          onSelected: (sel) => setLocalState(() => dayType = 'Half Day'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Date Selectors
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: fromDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 14)),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (d != null) {
                                setLocalState(() {
                                  fromDate = d;
                                  if (toDate.isBefore(d)) toDate = d;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'From Date',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('${fromDate.day}/${fromDate.month}/${fromDate.year}'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: toDate,
                                firstDate: fromDate,
                                lastDate: fromDate.add(const Duration(days: 60)),
                              );
                              if (d != null) setLocalState(() => toDate = d);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'To Date',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text('${toDate.day}/${toDate.month}/${toDate.year}'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Total Days Calculation Card
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF1E3A5F), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Total Days Calculated: ${calcDays()} day(s)',
                            style: const TextStyle(color: Color(0xFF1E3A5F), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Reason Textfield
                    TextFormField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Reason for Leave',
                        hintText: 'Provide detailed reason...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Reason is required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Attachment Picker
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.attach_file_rounded, color: attachment != null ? Colors.green : Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              attachment != null ? 'Attachment Selected: ${attachment!.path.split('/').last}' : 'Attachment (Medical Cert, Optional)',
                              style: TextStyle(fontSize: 12, color: attachment != null ? Colors.green : Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final x = await picker.pickImage(source: ImageSource.gallery);
                              if (x != null) setLocalState(() => attachment = File(x.path));
                            },
                            child: Text(attachment != null ? 'Change' : 'Pick Image'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Submit Button
                    ElevatedButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setLocalState(() => submitting = true);

                              final payload = {
                                'leave_type': leaveType,
                                'day_type': dayType,
                                'from_date': fromDate.toIso8601String().split('T')[0],
                                'to_date': toDate.toIso8601String().split('T')[0],
                                'reason': reasonCtrl.text.trim(),
                              };

                              if (attachment != null) {
                                final bytes = await attachment!.readAsBytes();
                                payload['attachment'] = 'data:image/jpeg;base64,' + base64Encode(bytes);
                              }

                              final res = await ApiService().post('leaves/apply', payload);
                              setLocalState(() => submitting = false);

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                if (res['success'] == true) {
                                  _fetch();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✅ Leave application submitted successfully'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['message'] ?? '❌ Failed to submit leave'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: submitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit Leave Application', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}