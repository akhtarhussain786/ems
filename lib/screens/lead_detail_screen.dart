import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

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
      print('Error loading leads list: $e');
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
        // The API scopes a lead to its creator, its telecaller and admins, so a
        // miss here means this user is not entitled to it.
        setState(() => _error = res['message']?.toString() ?? 'Lead not found');
        return;
      }

      // `data` is an object of {lead, calls, follow_ups} — the previous code
      // assigned the whole thing to the history List, which threw a TypeError
      // that a bare catch swallowed, so history was always empty.
      final data = res['data'];
      if (data is! Map) return;

      setState(() {
        final lead = data['lead'];
        if (lead is Map) {
          // Server copy wins: it carries the fields the list view never loads.
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

  /// Calls and follow-ups in one newest-first list, tagged so the timeline can
  /// tell them apart.
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

    // Clean the phone number - keep only digits
    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove leading zeros
    if (cleanedNumber.startsWith('0')) {
      cleanedNumber = cleanedNumber.substring(1);
    }

    // Check if it's a valid phone number
    if (cleanedNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid phone number: $phoneNumber'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Add country code if missing (India +91)
    if (cleanedNumber.length == 10) {
      cleanedNumber = '+91$cleanedNumber';
    } else if (!cleanedNumber.startsWith('+')) {
      cleanedNumber = '+$cleanedNumber';
    }

    print('🔵 Attempting to call: $cleanedNumber');

    // METHOD 1: Try Native Android Intent
    try {
      final bool result = await _channel.invokeMethod('makePhoneCall', {
        'number': cleanedNumber,
      });
      if (result == true) {
        HapticFeedback.mediumImpact();
        return;
      }
    } catch (e) {
      print('🔴 Native method failed: $e');
    }

    // METHOD 2: Try url_launcher with tel:
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanedNumber);
      if (await canLaunchUrl(phoneUri)) {
        HapticFeedback.mediumImpact();
        await launchUrl(phoneUri);
        return;
      }
    } catch (e) {
      print('🔴 url_launcher tel: failed: $e');
    }

    // METHOD 3: Try with just numbers
    try {
      final String simpleNumber = cleanedNumber.replaceAll('+', '');
      final Uri simpleUri = Uri(scheme: 'tel', path: simpleNumber);
      if (await canLaunchUrl(simpleUri)) {
        HapticFeedback.mediumImpact();
        await launchUrl(simpleUri);
        return;
      }
    } catch (e) {
      print('🔴 Simple number failed: $e');
    }

    // ULTIMATE FALLBACK: Show dialog with number
    _showCallFallbackDialog(cleanedNumber);
  }

  // ==================== FALLBACK DIALOG ====================
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
      print('🔴 WhatsApp failed: $e');
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

  Widget _buildLeadSelectorCard() {
    if (_loadingLeads && _leadsList.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E3A5F)),
            ),
            SizedBox(width: 10),
            Text('Loading assigned leads...', style: TextStyle(fontSize: 13, color: Color(0xFF1E3A5F))),
          ],
        ),
      );
    }

    if (_leadsList.isEmpty) return const SizedBox.shrink();

    final currentId = _leadData['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          Row(
            children: [
              const Icon(Icons.person_search_rounded, color: Color(0xFF1E3A5F), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Select Lead',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_leadsList.length} Leads',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A5F), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<dynamic>(
            value: _leadsList.any((l) => l['id'] == currentId) ? currentId : null,
            hint: const Text('Choose a lead from the list...', style: TextStyle(fontSize: 13)),
            isExpanded: true,
            items: _leadsList.map((l) {
              final id = l['id'];
              final name = l['customer_name'] ?? l['first_name'] ?? 'Lead #$id';
              final phone = l['customer_phone'] ?? l['phone'] ?? l['mobile'] ?? '';
              final status = (l['status'] ?? 'New').toString();
              return DropdownMenuItem<dynamic>(
                value: id,
                child: Text(
                  '$name ($phone) - ${status.toUpperCase()}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E3A5F), fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (selectedId) {
              if (selectedId == null) return;
              final found = _leadsList.firstWhere(
                (l) => l['id'] == selectedId,
                orElse: () => null,
              );
              if (found != null && found is Map) {
                _selectLead(Map<String, dynamic>.from(found));
              }
            },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = _leadData;
    final isPlaceholder = (lead['id'] ?? 0) == 0;
    final phone = lead['customer_phone'] ?? lead['customer_mobile'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(isPlaceholder),
      body: SafeArea(
        // Keeps content clear of the system navigation bar
        top: false,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lead Selector Card (when opened from modules or navigating leads)
                _buildLeadSelectorCard(),

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
            child: Text(
              isPlaceholder ? 'Lead Detail' : _fullName(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        if (!isPlaceholder)
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
                _makePhoneCall(AutofillHints.telephoneNumber);
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
          // Header with Avatar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A5F),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _fullName().isNotEmpty ? _fullName()[0].toUpperCase() : 'L',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName(),
                      style: const TextStyle(
                        fontSize: 18,
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
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(lead['status']).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(lead['status']).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    lead['status'] ?? 'New',
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

          // Free-text fields, too long for the two-column grid
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
  /// Trimmed string for a field, or null when the value is absent/blank so the
  /// grid can leave it out rather than showing a column of "N/A".
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

  /// Shown when the lead could not be loaded — most often because it belongs to
  /// someone else, since the API scopes leads to creator, telecaller and admin.
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

  /// Full-width block for free text. Renders nothing when the field is empty.
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

    // Everything the create form captures, so nothing entered is invisible.
    final candidates = <String, String?>{
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
      'Created': _val(lead['created_at']),
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
              hintText: _followUpDate?.toIso8601String().split('T')[0] ?? 'Tap to select',
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
                  style: TextStyle(
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
      case 'not interested':
        return Colors.red;
      case 'converted':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}