import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'create_lead_screen.dart';

class LeadDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? lead;
  const LeadDetailScreen({super.key, this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _history = [];
  List<dynamic> _leadsList = [];
  bool _loadingLeads = false;
  bool _loading = true;
  String? _error;
  String _callStatus = 'No Answer';
  DateTime? _followUpDate;
  DateTime? _selectedDate; // Null means all dates
  late Map<String, dynamic> _leadData;
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
    _leadData = widget.lead ?? _getDefaultLead();
    _fetchLeadsList();
    if ((_leadData['id'] ?? 0) > 0) {
      _fetchHistory();
    }
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getDefaultLead() {
    return {
      'id': 0,
      'customer_name': 'Select a Lead',
      'first_name': '',
      'last_name': '',
      'customer_phone': 'N/A',
      'customer_mobile': 'N/A',
      'email': 'N/A',
      'course_interested': 'N/A',
      'lead_source': 'N/A',
      'source': 'N/A',
      'status': 'New',
      'priority': 'Medium',
      'city': 'N/A',
      'state': 'N/A',
    };
  }

  /// Filter leads by the selected calendar creation date.
  List<dynamic> get _filteredLeads {
    if (_selectedDate == null) return _leadsList;
    return _leadsList.where((l) {
      if (l is! Map) return false;
      final createdAt = l['created_at']?.toString() ?? '';
      if (createdAt.isEmpty) return false;
      try {
        final dt = DateTime.parse(createdAt.contains(' ') ? createdAt.replaceAll(' ', 'T') : createdAt);
        return dt.year == _selectedDate!.year &&
            dt.month == _selectedDate!.month &&
            dt.day == _selectedDate!.day;
      } catch (_) {
        final targetStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        return createdAt.startsWith(targetStr);
      }
    }).toList();
  }

  Future<void> _fetchLeadsList() async {
    setState(() => _loadingLeads = true);
    try {
      final res = await ApiService().post('leads/list', {});
      if (mounted && res['success'] == true && res['data'] is List) {
        final list = List<dynamic>.from(res['data']);
        setState(() {
          _leadsList = list;
          if (((_leadData['id'] ?? 0) <= 0) && list.isNotEmpty) {
            final first = list.first;
            if (first is Map) {
              _leadData = Map<String, dynamic>.from(first);
              _fetchHistory();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading leads list: $e');
    } finally {
      if (mounted) setState(() => _loadingLeads = false);
    }
  }

  void _selectLead(Map<String, dynamic> lead) {
    setState(() {
      _leadData = Map<String, dynamic>.from(lead);
      _history = [];
      _error = null;
    });
    _fetchHistory();
  }

  void _onDateFilterChanged(DateTime? date) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = date;
      final filtered = _filteredLeads;
      if (filtered.isNotEmpty) {
        final currentId = _leadData['id'];
        final exists = filtered.any((l) => l is Map && l['id'] == currentId);
        if (!exists) {
          final first = filtered.first;
          if (first is Map) {
            _leadData = Map<String, dynamic>.from(first);
            _fetchHistory();
          }
        }
      } else {
        _leadData = _getDefaultLead();
        _history = [];
        _error = null;
      }
    });
  }

  Future<void> _pickCalendarDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'SELECT LEAD CREATION DATE',
      confirmText: 'FILTER LEADS',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A5F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E3A5F),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _onDateFilterChanged(picked);
    }
  }

  Future<void> _fetchHistory() async {
    final leadId = int.tryParse('${_leadData['id'] ?? 0}') ?? 0;
    if (leadId <= 0) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService().post('leads/history', {'lead_id': leadId});
      if (!mounted) return;

      if (res['success'] != true) {
        setState(() => _error = res['message']?.toString() ?? 'Lead not found');
        return;
      }

      final data = res['data'];
      if (data is! Map) return;

      setState(() {
        final lead = data['lead'];
        if (lead is Map) {
          _leadData = {..._leadData, ...Map<String, dynamic>.from(lead)};
        }
        _history = _mergeActivity(data['calls'], data['follow_ups']);
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load this lead');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Calls and follow-ups in one newest-first list, tagged so the timeline can tell them apart.
  List<dynamic> _mergeActivity(dynamic calls, dynamic followUps) {
    final merged = <Map<String, dynamic>>[];

    for (final c in (calls is List ? calls : const [])) {
      if (c is Map) merged.add({...Map<String, dynamic>.from(c), 'type': 'call'});
    }
    for (final f in (followUps is List ? followUps : const [])) {
      if (f is Map) merged.add({...Map<String, dynamic>.from(f), 'type': 'follow_up'});
    }

    merged.sort((a, b) =>
        '${b['created_at'] ?? ''}'.compareTo('${a['created_at'] ?? ''}'));
    return merged;
  }

  // ==================== PHONE CALL FUNCTION ====================
  static const MethodChannel _channel = MethodChannel('com.yathrathems.ems/phone');

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty || phoneNumber == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanedNumber.startsWith('0')) {
      cleanedNumber = cleanedNumber.substring(1);
    }

    if (cleanedNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid phone number: $phoneNumber'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (cleanedNumber.length == 10) {
      cleanedNumber = '+91$cleanedNumber';
    } else if (!cleanedNumber.startsWith('+')) {
      cleanedNumber = '+$cleanedNumber';
    }

    try {
      final bool result = await _channel.invokeMethod('makePhoneCall', {
        'number': cleanedNumber,
      });
      if (result == true) {
        HapticFeedback.mediumImpact();
        return;
      }
    } catch (e) {
      debugPrint('Native dialer failed: $e');
    }

    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanedNumber);
      if (await canLaunchUrl(phoneUri)) {
        HapticFeedback.mediumImpact();
        await launchUrl(phoneUri);
        return;
      }
    } catch (e) {
      debugPrint('url_launcher tel: failed: $e');
    }

    try {
      final String simpleNumber = cleanedNumber.replaceAll('+', '');
      final Uri simpleUri = Uri(scheme: 'tel', path: simpleNumber);
      if (await canLaunchUrl(simpleUri)) {
        HapticFeedback.mediumImpact();
        await launchUrl(simpleUri);
        return;
      }
    } catch (e) {
      debugPrint('Simple number failed: $e');
    }

    _showCallFallbackDialog(cleanedNumber);
  }

  void _showCallFallbackDialog(String phoneNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_android_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('Call Number'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Phone dialer not available. Please manually call:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 2),
              ),
              child: SelectableText(
                phoneNumber,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap and hold to copy number',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _makePhoneCall(phoneNumber);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== WHATSAPP FUNCTION ====================
  Future<void> _openWhatsApp(String phoneNumber) async {
    if (phoneNumber.isEmpty || phoneNumber == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanedNumber.startsWith('0')) {
      cleanedNumber = cleanedNumber.substring(1);
    }

    if (cleanedNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid phone number: $phoneNumber'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (cleanedNumber.length == 10) {
      cleanedNumber = '91$cleanedNumber';
    }

    try {
      final String webUrl = 'https://wa.me/$cleanedNumber';
      final Uri webUri = Uri.parse(webUrl);
      if (await canLaunchUrl(webUri)) {
        HapticFeedback.lightImpact();
        await launchUrl(webUri);
        return;
      }
    } catch (e) {
      debugPrint('WhatsApp failed: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Open WhatsApp with number: $cleanedNumber'),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: 'COPY',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: cleanedNumber));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Number copied!'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _logCall() async {
    final leadId = _leadData['id'] ?? 0;
    if (leadId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot log call for this lead'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await ApiService().post('call_reports/create', {
        'lead_id': leadId,
        'call_status': _callStatus,
        'notes': '',
      });
      if (_followUpDate != null) {
        await ApiService().post('follow_ups/create', {
          'lead_id': leadId,
          'follow_up_date': _followUpDate!.toIso8601String().split('T')[0],
          'notes': '',
        });
      }
      _fetchHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Call logged successfully'), backgroundColor: Colors.green),
        );
        setState(() {
          _followUpDate = null;
          _callStatus = 'No Answer';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _fullName() {
    final name = _leadData['customer_name'] ?? _leadData['name'] ?? '';
    if (name.isNotEmpty && name != 'Lead Detail') return name;
    final firstName = _leadData['first_name'] ?? '';
    final lastName = _leadData['last_name'] ?? '';
    final combined = '$firstName $lastName'.trim();
    if (combined.isNotEmpty && combined != 'Lead Detail') return combined;
    return 'Select a Lead';
  }

  String _formatDateTime(dynamic dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    final s = dateTimeStr.toString().trim();
    if (s.isEmpty || s == 'null') return 'N/A';
    try {
      final dt = DateTime.parse(s.contains(' ') ? s.replaceAll(' ', 'T') : s);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return s;
    }
  }

  String _formatTime(dynamic dateTimeStr) {
    if (dateTimeStr == null) return '';
    final s = dateTimeStr.toString().trim();
    if (s.isEmpty || s == 'null') return '';
    try {
      final dt = DateTime.parse(s.contains(' ') ? s.replaceAll(' ', 'T') : s);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatDateShort(dynamic dateTimeStr) {
    if (dateTimeStr == null) return '';
    final s = dateTimeStr.toString().trim();
    if (s.isEmpty || s == 'null') return '';
    try {
      final dt = DateTime.parse(s.contains(' ') ? s.replaceAll(' ', 'T') : s);
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return s;
    }
  }

  // ==================== DATE & LEAD SELECTOR CARD ====================
  Widget _buildDateAndLeadSelectorCard() {
    final filtered = _filteredLeads;
    final currentId = _leadData['id'];
    final isDateFilterActive = _selectedDate != null;

    final isTodaySelected = _selectedDate != null &&
        _selectedDate!.year == DateTime.now().year &&
        _selectedDate!.month == DateTime.now().month &&
        _selectedDate!.day == DateTime.now().day;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final isYesterdaySelected = _selectedDate != null &&
        _selectedDate!.year == yesterday.year &&
        _selectedDate!.month == yesterday.month &&
        _selectedDate!.day == yesterday.day;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.06),
            spreadRadius: 1,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Calendar Icon & Filter title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter Leads by Creation Date',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    Text(
                      isDateFilterActive
                          ? 'Created on ${DateFormat('dd MMM yyyy').format(_selectedDate!)}'
                          : 'Showing all created leads',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${filtered.length} Leads',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1E3A5F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Date Filter Quick Chips & Calendar Picker
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "All Dates" chip
                _buildDateChip(
                  label: 'All Dates',
                  isSelected: _selectedDate == null,
                  icon: Icons.all_inclusive_rounded,
                  onTap: () => _onDateFilterChanged(null),
                ),
                const SizedBox(width: 6),

                // "Today" chip
                _buildDateChip(
                  label: 'Today',
                  isSelected: isTodaySelected,
                  icon: Icons.today_rounded,
                  onTap: () => _onDateFilterChanged(DateTime.now()),
                ),
                const SizedBox(width: 6),

                // "Yesterday" chip
                _buildDateChip(
                  label: 'Yesterday',
                  isSelected: isYesterdaySelected,
                  icon: Icons.history_toggle_off_rounded,
                  onTap: () => _onDateFilterChanged(yesterday),
                ),
                const SizedBox(width: 6),

                // "Custom Calendar Date" button
                GestureDetector(
                  onTap: _pickCalendarDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isDateFilterActive && !isTodaySelected && !isYesterdaySelected)
                          ? const Color(0xFF1E3A5F)
                          : const Color(0xFF1E3A5F).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isDateFilterActive && !isTodaySelected && !isYesterdaySelected)
                            ? const Color(0xFF1E3A5F)
                            : const Color(0xFF1E3A5F).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_calendar_rounded,
                          size: 14,
                          color: (isDateFilterActive && !isTodaySelected && !isYesterdaySelected)
                              ? Colors.white
                              : const Color(0xFF1E3A5F),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          (isDateFilterActive && !isTodaySelected && !isYesterdaySelected)
                              ? DateFormat('dd MMM yyyy').format(_selectedDate!)
                              : 'Select Date',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: (isDateFilterActive && !isTodaySelected && !isYesterdaySelected)
                                ? Colors.white
                                : const Color(0xFF1E3A5F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Date active banner (when a date is selected)
          if (isDateFilterActive) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF1E3A5F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Created on: ${DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate!)} (${filtered.length} leads)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _onDateFilterChanged(null),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Leads Selector / Dropdown
          if (_loadingLeads && _leadsList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E3A5F)),
                    ),
                    SizedBox(width: 10),
                    Text('Loading leads...', style: TextStyle(fontSize: 13, color: Color(0xFF1E3A5F))),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.event_busy_rounded, size: 36, color: Colors.orange),
                  const SizedBox(height: 6),
                  Text(
                    isDateFilterActive
                        ? 'No leads were created on ${DateFormat('dd MMM yyyy').format(_selectedDate!)}'
                        : 'No leads found in your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  if (isDateFilterActive) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _onDateFilterChanged(null),
                      icon: const Icon(Icons.all_inclusive_rounded, size: 16),
                      label: const Text('Show All Leads', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A5F),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else ...[
            DropdownButtonFormField<dynamic>(
              value: filtered.any((l) => l['id'] == currentId) ? currentId : (filtered.isNotEmpty ? filtered.first['id'] : null),
              hint: Text(
                isDateFilterActive ? 'Choose lead created on this date...' : 'Choose a lead from the list...',
                style: const TextStyle(fontSize: 13),
              ),
              isExpanded: true,
              items: filtered.map((l) {
                final id = l['id'];
                final name = l['customer_name'] ?? l['first_name'] ?? 'Lead #$id';
                final phone = l['customer_phone'] ?? l['phone'] ?? l['mobile'] ?? '';
                final status = (l['status'] ?? 'New').toString();
                final timeStr = _formatTime(l['created_at']);
                final dateStr = _formatDateShort(l['created_at']);

                final timeDisplay = isDateFilterActive
                    ? (timeStr.isNotEmpty ? ' • $timeStr' : '')
                    : (dateStr.isNotEmpty ? ' • $dateStr $timeStr' : '');

                return DropdownMenuItem<dynamic>(
                  value: id,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$name ($phone)$timeDisplay',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E3A5F),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (selectedId) {
                if (selectedId == null) return;
                final found = filtered.firstWhere(
                  (l) => l['id'] == selectedId,
                  orElse: () => null,
                );
                if (found != null && found is Map) {
                  _selectLead(Map<String, dynamic>.from(found));
                }
              },
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                labelText: isDateFilterActive
                    ? 'Leads Created on ${DateFormat('dd MMM').format(_selectedDate!)}'
                    : 'Select Lead',
                labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF1E3A5F), fontWeight: FontWeight.w600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
                ),
              ),
            ),

            // Horizontal Leads Quick Strip for the selected date
            if (filtered.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    final isSelected = item['id'] == currentId;
                    final name = item['customer_name'] ?? item['first_name'] ?? 'Lead #${item['id']}';
                    final timeStr = _formatTime(item['created_at']);
                    final status = (item['status'] ?? 'new').toString();

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _selectLead(Map<String, dynamic>.from(item));
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: const Color(0xFF1E3A5F).withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name.length > 15 ? '${name.substring(0, 15)}...' : name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF1E3A5F),
                                  ),
                                ),
                                if (timeStr.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '($timeStr)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSelected ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.orange.shade200 : _getStatusColor(status),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : const Color(0xFF1E3A5F).withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A5F) : const Color(0xFF1E3A5F).withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFF1E3A5F),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1E3A5F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = _leadData;
    final isPlaceholder = (lead['id'] ?? 0) == 0;
    final phone = lead['customer_phone'] ?? lead['customer_mobile'] ?? lead['phone'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(isPlaceholder),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await _fetchLeadsList();
            if ((_leadData['id'] ?? 0) > 0) {
              await _fetchHistory();
            }
          },
          color: const Color(0xFF1E3A5F),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date & Lead Selector Card
                  _buildDateAndLeadSelectorCard(),

                  // Lead Info Glass Card
                  _buildGlassLeadCard(lead, isPlaceholder, phone),
                  const SizedBox(height: 16),

                  if (_error != null) ...[
                    _buildErrorNotice(_error!),
                    const SizedBox(height: 16),
                  ],

                  if (!isPlaceholder) ...[
                    // Log Call Section
                    _buildGlassLogCallCard(),
                    const SizedBox(height: 16),

                    // Activity History
                    _buildGlassHistoryCard(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== GLASS APP BAR ====================
  PreferredSizeWidget _buildGlassAppBar(bool isPlaceholder) {
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
              borderRadius: BorderRadius.circular(12),
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
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 24,
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPlaceholder ? 'Lead Details' : _fullName(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _selectedDate != null
                      ? 'Created: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}'
                      : 'Lead Management & Details',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Quick Calendar Picker action
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: _pickCalendarDate,
            tooltip: 'Filter by Date',
            icon: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
              size: 22,
            ),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(),
          ),
        ),
        if (!isPlaceholder) ...[
          const SizedBox(width: 4),
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateLeadScreen(lead: _leadData),
                  ),
                );
                if (res != null && mounted) {
                  await _fetchLeadsList();
                  if ((_leadData['id'] ?? 0) > 0) {
                    await _fetchHistory();
                  }
                }
              },
              tooltip: 'Edit Lead',
              icon: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 20,
              ),
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                final phone = _leadData['customer_phone'] ?? _leadData['phone'] ?? '';
                if (phone.isNotEmpty) _makePhoneCall(phone);
              },
              icon: const Icon(
                Icons.call_rounded,
                color: Colors.white,
                size: 22,
              ),
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(),
            ),
          ),
        ],
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

  // ==================== GLASS LEAD CARD ====================
  Widget _buildGlassLeadCard(Map<String, dynamic> lead, bool isPlaceholder, String phone) {
    final createdAt = lead['created_at'];
    final creatorName = _person(lead['creator_first'], lead['creator_last']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creation Date Banner (Prominent badge so users always know when this lead was created)
          if (createdAt != null && createdAt.toString().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF1E3A5F)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Created: ${_formatDateTime(createdAt)}${creatorName != null ? ' by $creatorName' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Header with Avatar & Details
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A5F),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _fullName().isNotEmpty ? _fullName()[0].toUpperCase() : 'L',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName(),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (phone != 'N/A')
                      GestureDetector(
                        onTap: () => _makePhoneCall(phone),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 14,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'CALL',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (lead['status'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getStatusColor(lead['status']).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(lead['status']).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    lead['status']?.toString().toUpperCase() ?? 'NEW',
                    style: TextStyle(
                      color: _getStatusColor(lead['status']),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),

          // Info Grid
          _buildInfoGrid(lead),

          // Free-text fields
          _buildLongField('Requirement', lead['requirement']),
          _buildLongField('Notes', lead['notes']),

          // Action Buttons for Call & WhatsApp
          if (!isPlaceholder) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildGlassActionButton(
                    Icons.call_rounded,
                    'Call Now',
                    () => _makePhoneCall(phone),
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildGlassActionButton(
                    Icons.message_rounded,
                    'WhatsApp',
                    () => _openWhatsApp(phone),
                    Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==================== INFO GRID ====================
  String? _val(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  String? _person(dynamic first, dynamic last) {
    final name = '${first ?? ''} ${last ?? ''}'.trim();
    return name.isEmpty ? null : name;
  }

  Widget _buildErrorNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLongField(String label, dynamic value) {
    final text = _val(value);
    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E3A5F).withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E3A5F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(Map<String, dynamic> lead) {
    final budget = _val(lead['budget']);
    final createdAt = lead['created_at'];

    final candidates = <String, String?>{
      'Created Date': createdAt != null ? _formatDateShort(createdAt) : null,
      'Created Time': createdAt != null ? _formatTime(createdAt) : null,
      'Email': _val(lead['email']) ?? _val(lead['customer_email']),
      'Company': _val(lead['company_name']),
      'City': _val(lead['city']),
      'Source': _val(lead['lead_source']) ?? _val(lead['source']),
      'Campaign': _val(lead['campaign_name']),
      'Priority': _val(lead['priority']),
      'Budget': budget == null ? null : '₹$budget',
      'Status': _val(lead['status']),
      'Created by': _person(lead['creator_first'], lead['creator_last']),
      'Assigned to': _person(lead['assigned_first'], lead['assigned_last']),
      'Follow-up': _val(lead['follow_up_date']),
    };

    final items = [
      for (final entry in candidates.entries)
        if (entry.value != null) {'label': entry.key, 'value': entry.value!},
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item['label']!,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item['value']!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E3A5F),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== GLASS ACTION BUTTON ====================
  Widget _buildGlassActionButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== GLASS LOG CALL CARD ====================
  Widget _buildGlassLogCallCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.phone_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Log Call',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _callStatus,
            items: [
              'No Answer',
              'Connected',
              'Busy',
              'Switched Off',
              'Interested',
              'Not Interested',
              'Converted'
            ].map((s) => DropdownMenuItem(
              value: s,
              child: Text(s),
            )).toList(),
            onChanged: (v) => setState(() => _callStatus = v!),
            decoration: InputDecoration(
              labelText: 'Call Status',
              labelStyle: TextStyle(color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Follow-up Date',
              labelStyle: TextStyle(color: Colors.grey[600]),
              hintText: _followUpDate != null
                  ? DateFormat('yyyy-MM-dd').format(_followUpDate!)
                  : 'Tap to select follow-up date',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
              ),
              suffixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF1E3A5F)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 60)),
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
              if (d != null) setState(() => _followUpDate = d);
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _logCall,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF1E3A5F).withOpacity(0.3),
            ),
            child: const Text(
              'Save Call Log',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== GLASS HISTORY CARD ====================
  Widget _buildGlassHistoryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.deepPurple, Colors.deepPurpleAccent],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Activity History',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const Spacer(),
              if (_history.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_history.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _loading
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: Color(0xFF1E3A5F),
                strokeWidth: 3,
              ),
            ),
          )
              : _history.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 48,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No activity yet',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, __) => const Divider(height: 4),
            itemBuilder: (_, i) {
              final h = _history[i];
              final isCall = h['type'] == 'call' || h['call_status'] != null;
              final status = isCall ? (h['call_status'] ?? '') : (h['follow_up_date'] ?? '');
              final date = h['created_at'] ?? '';

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCall
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCall ? Icons.phone_rounded : Icons.event_note_rounded,
                    color: isCall ? Colors.blue : Colors.green,
                    size: 18,
                  ),
                ),
                title: Text(
                  isCall ? 'Call: $status' : 'Follow-up: $status',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                subtitle: Text(
                  h['notes'] ?? date,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
                dense: true,
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'new':
        return Colors.blue;
      case 'contacted':
        return Colors.orange;
      case 'interested':
        return Colors.green;
      case 'qualified':
        return Colors.teal;
      case 'won':
        return Colors.purple;
      case 'lost':
      case 'not interested':
      case 'not_interested':
        return Colors.red;
      case 'converted':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}