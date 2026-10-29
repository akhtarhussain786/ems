import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class TelecallerScreen extends StatefulWidget {
  const TelecallerScreen({super.key});

  @override
  State<TelecallerScreen> createState() => _TelecallerScreenState();
}

class _TelecallerScreenState extends State<TelecallerScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _leads = [];
  List<dynamic> _followUps = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  int _tabIndex = 0; // 0 = Leads, 1 = Follow-ups

  // Search & Filter Controllers & State
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _statusFilter = '';
  String _priorityFilter = '';
  String _sourceFilter = '';
  String _followUpFilter = ''; // 'today', 'overdue', 'upcoming', 'has_follow_up', 'no_follow_up'
  int? _createdByFilter;
  String? _createdByNameFilter;
  List<Map<String, dynamic>> _creators = [];
  String _datePreset = 'all'; // 'all', 'today', 'yesterday', 'this_week', 'this_month', 'custom'
  DateTimeRange? _selectedDateRange;
  String _sortBy = 'default'; // 'default', 'newest', 'oldest', 'follow_up_asc', 'follow_up_desc', 'name_asc'

  // Standard 11 Call Outcomes
  static const List<Map<String, dynamic>> _callOutcomes = [
    {
      'label': 'Connected — Interested',
      'icon': Icons.thumb_up_alt_rounded,
      'color': Color(0xFF2E7D32),
      'requiresFollowUp': false,
    },
    {
      'label': 'Connected — Not Interested',
      'icon': Icons.thumb_down_alt_rounded,
      'color': Color(0xFFC62828),
      'requiresFollowUp': false,
    },
    {
      'label': 'No Answer',
      'icon': Icons.phone_missed_rounded,
      'color': Color(0xFFEF6C00),
      'requiresFollowUp': false,
    },
    {
      'label': 'Busy',
      'icon': Icons.phone_paused_rounded,
      'color': Color(0xFFD84315),
      'requiresFollowUp': false,
    },
    {
      'label': 'Switched Off',
      'icon': Icons.power_settings_new_rounded,
      'color': Color(0xFF546E7A),
      'requiresFollowUp': false,
    },
    {
      'label': 'Invalid Number',
      'icon': Icons.error_outline_rounded,
      'color': Color(0xFFB71C1C),
      'requiresFollowUp': false,
    },
    {
      'label': 'Call Back Required',
      'icon': Icons.phone_callback_rounded,
      'color': Color(0xFF3949AB),
      'requiresFollowUp': true,
    },
    {
      'label': 'Follow-up Scheduled',
      'icon': Icons.event_available_rounded,
      'color': Color(0xFF6A1B9A),
      'requiresFollowUp': true,
    },
    {
      'label': 'Meeting Requested',
      'icon': Icons.groups_rounded,
      'color': Color(0xFF00897B),
      'requiresFollowUp': true,
    },
    {
      'label': 'Converted / Successful',
      'icon': Icons.verified_rounded,
      'color': Color(0xFF1B5E20),
      'requiresFollowUp': false,
    },
    {
      'label': 'Other',
      'icon': Icons.more_horiz_rounded,
      'color': Color(0xFF616161),
      'requiresFollowUp': false,
    },
  ];

  Color _outcomeColor(String? outcome) {
    if (outcome == null || outcome.isEmpty) return Colors.grey;
    for (final item in _callOutcomes) {
      if (item['label'].toString().toLowerCase() == outcome.toLowerCase()) {
        return item['color'] as Color;
      }
    }
    return _statusColor(outcome);
  }

  IconData _outcomeIcon(String? outcome) {
    if (outcome == null || outcome.isEmpty) return Icons.phone_rounded;
    for (final item in _callOutcomes) {
      if (item['label'].toString().toLowerCase() == outcome.toLowerCase()) {
        return item['icon'] as IconData;
      }
    }
    return Icons.phone_callback_rounded;
  }

  List<dynamic> get _displayedFollowUps {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _followUps;
    return _followUps.where((f) {
      final name = (f['lead_name'] ?? f['customer_name'] ?? '').toString().toLowerCase();
      final phone = (f['lead_phone'] ?? f['phone'] ?? f['customer_phone'] ?? '').toString().toLowerCase();
      final notes = (f['notes'] ?? '').toString().toLowerCase();
      final req = (f['lead_requirement'] ?? '').toString().toLowerCase();
      return name.contains(query) || phone.contains(query) || notes.contains(query) || req.contains(query);
    }).toList();
  }

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _sources = ['Call', 'WhatsApp', 'Website', 'Facebook', 'Google', 'Instagram', 'Referral', 'Field Visit', 'Other'];
  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];
  final List<String> _statuses = [
    'new', 'calling', 'connected', 'interested', 'qualified',
    'follow_up', 'busy', 'no_answer', 'not_interested', 'wrong_number', 'duplicate', 'lost', 'won'
  ];

  int get _activeFilterCount {
    int count = 0;
    if (_searchCtrl.text.trim().isNotEmpty) count++;
    if (_statusFilter.isNotEmpty) count++;
    if (_priorityFilter.isNotEmpty) count++;
    if (_sourceFilter.isNotEmpty) count++;
    if (_followUpFilter.isNotEmpty) count++;
    if (_createdByFilter != null) count++;
    if (_datePreset != 'all') count++;
    if (_sortBy != 'default') count++;
    return count;
  }

  List<Map<String, dynamic>> get _availableCreators {
    if (_creators.isNotEmpty) return _creators;
    final Map<int, Map<String, dynamic>> map = {};
    for (final l in _leads) {
      final id = l['creator_id'] ?? l['created_by'] ?? l['employee_id'];
      if (id != null && int.tryParse(id.toString()) != null) {
        final intId = int.parse(id.toString());
        String name = '';
        if (l['creator_first'] != null && l['creator_first'].toString().trim().isNotEmpty) {
          name = "${l['creator_first']} ${l['creator_last'] ?? ''}".trim();
          if (l['creator_code'] != null && l['creator_code'].toString().isNotEmpty) {
            name += " (${l['creator_code']})";
          }
        } else if (l['creator_username'] != null && l['creator_username'].toString().trim().isNotEmpty) {
          name = l['creator_username'].toString();
        }
        if (name.isNotEmpty && !map.containsKey(intId)) {
          map[intId] = {'id': intId, 'name': name};
        }
      }
    }
    return map.values.toList();
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
    _fetch();
    _fetchCreators();
    _animationController.forward();
  }

  Future<void> _fetchCreators() async {
    try {
      final res = await ApiService().get('telecaller/creators');
      if (mounted && res['success'] == true && res['data'] is List) {
        setState(() {
          _creators = List<Map<String, dynamic>>.from(res['data']);
        });
      }
    } catch (e) {
      debugPrint('telecaller_screen fetch creators error: $e');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _animationController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final reqData = <String, dynamic>{
        if (_searchCtrl.text.trim().isNotEmpty) 'search': _searchCtrl.text.trim(),
        if (_statusFilter.isNotEmpty) 'status': _statusFilter,
        if (_priorityFilter.isNotEmpty) 'priority': _priorityFilter.toLowerCase(),
        if (_sourceFilter.isNotEmpty) 'source': _sourceFilter,
        if (_followUpFilter.isNotEmpty) 'follow_up_filter': _followUpFilter,
        if (_createdByFilter != null) 'created_by': _createdByFilter,
        if (_sortBy != 'default') 'sort_by': _sortBy,
        if (_selectedDateRange != null) ...{
          'from_date': DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start),
          'to_date': DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end),
        }
      };

      // If no custom filters applied, load full dashboard for stats & today followups
      if (_activeFilterCount == 0) {
        final res = await ApiService().get('telecaller/dashboard');
        if (mounted && res['success'] == true) {
          setState(() {
            _leads = (res['data'] is Map ? (res['data']!['leads'] ?? []) : []);
            _followUps = (res['data'] is Map ? (res['data']!['today_follow_ups'] ?? []) : []);
            _stats = (res['data'] is Map ? (res['data']!['stats'] ?? {}) : {});
          });
        }
      } else {
        final res = await ApiService().post('telecaller/leads', reqData);
        if (mounted && res['success'] == true) {
          setState(() {
            _leads = res['data'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('telecaller_screen fetch error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onSearchChanged(String v) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _fetch();
    });
  }

  void _onSearchSubmitted([String? query]) {
    _searchDebounce?.cancel();
    HapticFeedback.lightImpact();
    _fetch();
  }

  void _clearSearch() {
    HapticFeedback.selectionClick();
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {});
    _fetch();
  }

  void _resetFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _searchCtrl.clear();
      _statusFilter = '';
      _priorityFilter = '';
      _sourceFilter = '';
      _followUpFilter = '';
      _createdByFilter = null;
      _createdByNameFilter = null;
      _datePreset = 'all';
      _selectedDateRange = null;
      _sortBy = 'default';
    });
    _fetch();
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'won': case 'qualified': return Colors.green;
      case 'lost': case 'not_interested': case 'wrong_number': return Colors.red;
      case 'interested': return Colors.blue;
      case 'follow_up': return Colors.deepPurple;
      case 'calling': case 'connected': return Colors.teal;
      case 'busy': case 'no_answer': return Colors.amber.shade800;
      case 'duplicate': return Colors.grey;
      case 'new': return Colors.orange;
      default: return Colors.grey;
    }
  }

  // ==================== PHONE & WHATSAPP ====================
  Future<void> _makePhoneCall(String phoneNumber, [Map<String, dynamic>? lead]) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available'), backgroundColor: Colors.red),
      );
      return;
    }

    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);

    if (cleaned.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid phone number: $phoneNumber'), backgroundColor: Colors.red),
      );
      return;
    }

    if (cleaned.length == 10) {
      cleaned = '+91$cleaned';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }

    try {
      final Uri uri = Uri(scheme: 'tel', path: cleaned);
      if (await canLaunchUrl(uri)) {
        HapticFeedback.mediumImpact();
        await launchUrl(uri);
        // Automatically open the unified Call Log & Follow-up dialog so when they return to the app, it's ready!
        if (lead != null && mounted) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _showCallFeedbackDialog(lead);
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Dialer launch error: $e');
    }

    // Fallback: Copy number
    Clipboard.setData(ClipboardData(text: cleaned));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phone copied: $cleaned'),
        backgroundColor: const Color(0xFF1E3A5F),
      ),
    );
    if (lead != null && mounted) {
      _showCallFeedbackDialog(lead);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
    if (cleaned.length == 10) cleaned = '91$cleaned';

    try {
      final Uri uri = Uri.parse('whatsapp://send?phone=$cleaned');
      if (await canLaunchUrl(uri)) {
        HapticFeedback.lightImpact();
        await launchUrl(uri);
        return;
      }
      final Uri webUri = Uri.parse('https://wa.me/$cleaned');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');
    }

    Clipboard.setData(ClipboardData(text: cleaned));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('WhatsApp number copied: $cleaned'), backgroundColor: Colors.green),
    );
  }

  // ==================== CREATE INQUIRY MODAL ====================
  void _openCreateInquiryModal() {
    HapticFeedback.mediumImpact();

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final requirementCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    String selectedSource = 'Call';
    String selectedPriority = 'Medium';
    DateTime? selectedFupDate;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_call, color: Color(0xFF1E3A5F), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create New Inquiry',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                              Text(
                                'Add caller details and schedule follow-up',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Customer Name *
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Customer Name *',
                        hintText: 'Enter full name',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Customer name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Mobile Number *
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number *',
                        hintText: '10-digit mobile number',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.length < 10) return 'Enter valid 10-digit number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Requirement / Course
                    TextFormField(
                      controller: requirementCtrl,
                      decoration: InputDecoration(
                        labelText: 'Requirement / Course / Inquiry for',
                        hintText: 'e.g. Spoken English, Web Dev, Class 10...',
                        prefixIcon: const Icon(Icons.school_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // City & Email Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cityCtrl,
                            decoration: InputDecoration(
                              labelText: 'City / Location',
                              hintText: 'e.g. Jamshedpur',
                              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email (Optional)',
                              hintText: 'name@email.com',
                              prefixIcon: const Icon(Icons.email_outlined, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Source & Priority Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSource,
                            decoration: InputDecoration(
                              labelText: 'Lead Source',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _sources.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setModalState(() => selectedSource = v ?? 'Call'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedPriority,
                            decoration: InputDecoration(
                              labelText: 'Priority',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                            onChanged: (v) => setModalState(() => selectedPriority = v ?? 'Medium'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Follow-up Date & Day Selector
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedFupDate ?? DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                          helpText: 'SELECT FOLLOW-UP DATE',
                        );
                        if (picked != null) {
                          setModalState(() => selectedFupDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F).withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedFupDate != null ? const Color(0xFF1E3A5F) : Colors.grey.shade300,
                            width: selectedFupDate != null ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_note_rounded, color: Color(0xFF1E3A5F)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'SCHEDULE NEXT FOLLOW-UP',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedFupDate != null
                                        ? '${DateFormat('dd MMM yyyy (EEEE)').format(selectedFupDate!)}'
                                        : 'Tap to select date & day',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selectedFupDate != null ? const Color(0xFF1E3A5F) : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedFupDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                onPressed: () => setModalState(() => selectedFupDate = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notes / Remarks
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Initial Notes / Call Summary',
                        hintText: 'Write caller interest or notes...',
                        prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => isSaving = true);

                          final fDateStr = selectedFupDate != null
                              ? DateFormat('yyyy-MM-dd').format(selectedFupDate!)
                              : null;

                          final req = {
                            'customer_name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'requirement': requirementCtrl.text.trim(),
                            'city': cityCtrl.text.trim(),
                            'source': selectedSource,
                            'priority': selectedPriority.toLowerCase(),
                            'notes': notesCtrl.text.trim(),
                            if (fDateStr != null) 'follow_up_date': fDateStr,
                            'status': fDateStr != null ? 'follow_up' : 'new',
                          };

                          final res = await ApiService().post('telecaller/create-inquiry', req);
                          setModalState(() => isSaving = false);

                          if (mounted) {
                            Navigator.pop(context);
                            if (res['success'] == true) {
                              _fetch();
                              final phone = phoneCtrl.text.trim();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Inquiry for ${nameCtrl.text.trim()} saved!'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  action: SnackBarAction(
                                    label: 'CALL NOW',
                                    textColor: Colors.white,
                                    onPressed: () => _makePhoneCall(phone),
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? '❌ Failed to create inquiry'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save Inquiry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== FILTER MODAL ====================
  void _openFilterModal() {
    HapticFeedback.lightImpact();

    String tempStatus = _statusFilter;
    String tempPriority = _priorityFilter;
    String tempSource = _sourceFilter;
    String tempFollowUp = _followUpFilter;
    int? tempCreatedBy = _createdByFilter;
    String? tempCreatedByName = _createdByNameFilter;
    String tempDatePreset = _datePreset;
    DateTimeRange? tempRange = _selectedDateRange;
    String tempSort = _sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    children: [
                      const Icon(Icons.filter_alt_rounded, color: Color(0xFF1E3A5F)),
                      const SizedBox(width: 8),
                      const Text(
                        'Filter & Sort Leads',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempStatus = '';
                            tempPriority = '';
                            tempSource = '';
                            tempFollowUp = '';
                            tempCreatedBy = null;
                            tempCreatedByName = null;
                            tempDatePreset = 'all';
                            tempRange = null;
                            tempSort = 'default';
                          });
                        },
                        child: const Text('Reset All', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                  const Divider(),

                  // 1. Follow-up Filter
                  const Text('FOLLOW-UP FILTER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildFilterChip('All', tempFollowUp == '', () => setModalState(() => tempFollowUp = '')),
                      _buildFilterChip('🔔 Today\'s Follow-up', tempFollowUp == 'today', () => setModalState(() => tempFollowUp = 'today'), activeColor: Colors.orange.shade800),
                      _buildFilterChip('⚠️ Overdue', tempFollowUp == 'overdue', () => setModalState(() => tempFollowUp = 'overdue'), activeColor: Colors.red),
                      _buildFilterChip('📅 Upcoming', tempFollowUp == 'upcoming', () => setModalState(() => tempFollowUp = 'upcoming'), activeColor: Colors.blue),
                      _buildFilterChip('Has Follow-up', tempFollowUp == 'has_follow_up', () => setModalState(() => tempFollowUp = 'has_follow_up')),
                      _buildFilterChip('No Follow-up', tempFollowUp == 'no_follow_up', () => setModalState(() => tempFollowUp = 'no_follow_up')),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. Created Date Range Presets
                  const Text('CREATED DATE PRESET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildFilterChip('All Time', tempDatePreset == 'all', () {
                        setModalState(() {
                          tempDatePreset = 'all';
                          tempRange = null;
                        });
                      }),
                      _buildFilterChip('Today', tempDatePreset == 'today', () {
                        final now = DateTime.now();
                        final t = DateTime(now.year, now.month, now.day);
                        setModalState(() {
                          tempDatePreset = 'today';
                          tempRange = DateTimeRange(start: t, end: t);
                        });
                      }),
                      _buildFilterChip('Yesterday', tempDatePreset == 'yesterday', () {
                        final now = DateTime.now();
                        final y = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
                        setModalState(() {
                          tempDatePreset = 'yesterday';
                          tempRange = DateTimeRange(start: y, end: y);
                        });
                      }),
                      _buildFilterChip('This Week', tempDatePreset == 'this_week', () {
                        final now = DateTime.now();
                        final start = now.subtract(Duration(days: now.weekday - 1));
                        setModalState(() {
                          tempDatePreset = 'this_week';
                          tempRange = DateTimeRange(start: DateTime(start.year, start.month, start.day), end: DateTime(now.year, now.month, now.day));
                        });
                      }),
                      _buildFilterChip('This Month', tempDatePreset == 'this_month', () {
                        final now = DateTime.now();
                        setModalState(() {
                          tempDatePreset = 'this_month';
                          tempRange = DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month, now.day));
                        });
                      }),
                      _buildFilterChip('Custom Range', tempDatePreset == 'custom', () async {
                        final now = DateTime.now();
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: tempRange ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
                        );
                        if (picked != null) {
                          setModalState(() {
                            tempDatePreset = 'custom';
                            tempRange = picked;
                          });
                        }
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Status Filter
                  const Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildFilterChip('All Status', tempStatus.isEmpty, () => setModalState(() => tempStatus = '')),
                      ..._statuses.map((st) => _buildFilterChip(
                        st.replaceAll('_', ' ').toUpperCase(),
                        tempStatus == st,
                            () => setModalState(() => tempStatus = st),
                      )),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4. Priority Filter
                  const Text('PRIORITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('All', tempPriority.isEmpty, () => setModalState(() => tempPriority = '')),
                      ..._priorities.map((p) => _buildFilterChip(
                        p,
                        tempPriority.toLowerCase() == p.toLowerCase(),
                            () => setModalState(() => tempPriority = p.toLowerCase()),
                      )),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 5. Source Filter
                  const Text('SOURCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildFilterChip('All Sources', tempSource.isEmpty, () => setModalState(() => tempSource = '')),
                      ..._sources.map((src) => _buildFilterChip(
                        src,
                        tempSource == src,
                            () => setModalState(() => tempSource = src),
                      )),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 6. Created By Filter (Specific Person / Staff)
                  const Text('CREATED BY (STAFF / SPECIFIC PERSON)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildFilterChip(
                        'All Creators',
                        tempCreatedBy == null,
                        () => setModalState(() {
                          tempCreatedBy = null;
                          tempCreatedByName = null;
                        }),
                      ),
                      ..._availableCreators.map((c) {
                        final cId = int.tryParse(c['id'].toString());
                        final cName = c['name'] ?? 'Staff #${c['id']}';
                        final code = c['employee_code'] != null && c['employee_code'].toString().isNotEmpty ? ' (${c['employee_code']})' : '';
                        final label = '$cName$code';
                        return _buildFilterChip(
                          label,
                          tempCreatedBy == cId,
                          () => setModalState(() {
                            tempCreatedBy = cId;
                            tempCreatedByName = cName;
                          }),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 7. Sort By
                  const Text('SORT BY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildFilterChip('Default (Priority)', tempSort == 'default', () => setModalState(() => tempSort = 'default')),
                      _buildFilterChip('Newest First', tempSort == 'newest', () => setModalState(() => tempSort = 'newest')),
                      _buildFilterChip('Oldest First', tempSort == 'oldest', () => setModalState(() => tempSort = 'oldest')),
                      _buildFilterChip('Follow-up Date (Earliest)', tempSort == 'follow_up_asc', () => setModalState(() => tempSort = 'follow_up_asc')),
                      _buildFilterChip('Follow-up Date (Latest)', tempSort == 'follow_up_desc', () => setModalState(() => tempSort = 'follow_up_desc')),
                      _buildFilterChip('Name (A-Z)', tempSort == 'name_asc', () => setModalState(() => tempSort = 'name_asc')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _statusFilter = tempStatus;
                          _priorityFilter = tempPriority;
                          _sourceFilter = tempSource;
                          _followUpFilter = tempFollowUp;
                          _createdByFilter = tempCreatedBy;
                          _createdByNameFilter = tempCreatedByName;
                          _datePreset = tempDatePreset;
                          _selectedDateRange = tempRange;
                          _sortBy = tempSort;
                        });
                        Navigator.pop(context);
                        _fetch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, {Color? activeColor}) {
    final color = activeColor ?? const Color(0xFF1E3A5F);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateInquiryModal,
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_call, size: 20),
        label: const Text('Create Inquiry', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A5F)))
            : FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              if (_stats != null && _activeFilterCount == 0) _buildStatsRow(),
              _buildTabRow(),
              _buildSearchBar(),
              if (_activeFilterCount > 0) _buildActiveFiltersBanner(),
              Expanded(
                child: _tabIndex == 0
                    ? _buildLeads()
                    : _buildFollowUps(),
              ),
            ],
          ),
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
                  Icons.phone_android_rounded,
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
              const Text(
                'YATHARTH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Telecaller Dashboard',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
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
        // Quick "+ Inquiry" button
        Container(
          margin: const EdgeInsets.only(right: 6),
          child: TextButton.icon(
            onPressed: _openCreateInquiryModal,
            icon: const Icon(Icons.add, color: Colors.white, size: 16),
            label: const Text('+ Inquiry', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        // Refresh button
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetch();
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  // ==================== STATS ROW ====================
  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildGlassStatCard('Assigned', '${_stats!['total_assigned'] ?? 0}', Colors.blue),
          _buildGlassStatCard("Today's Calls", '${_stats!['today_calls'] ?? 0}', Colors.orange),
          _buildGlassStatCard('Pending FUP', '${_stats!['pending_followups'] ?? 0}', Colors.red),
          _buildGlassStatCard('Converted', '${_stats!['converted'] ?? 0}', Colors.green),
        ],
      ),
    );
  }

  Widget _buildGlassStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
            Text(
              value,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TAB ROW ====================
  Widget _buildTabRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            child: _buildGlassTab('Leads (${_leads.length})', 0),
          ),
          Expanded(
            child: _buildGlassTab('Due Follow-ups (${_followUps.length})', 1),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F).withOpacity(0.06) : Colors.transparent,
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

  // ==================== SEARCH & FILTER BAR ====================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
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
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearchSubmitted,
                decoration: InputDecoration(
                  hintText: 'Search by name, phone, course...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded, color: Color(0xFF1E3A5F)),
                    onPressed: () => _onSearchSubmitted(),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: Colors.grey[400], size: 20),
                    onPressed: _clearSearch,
                  )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Dedicated Search Button
          GestureDetector(
            onTap: () => _onSearchSubmitted(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),

          // Filter Button with Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: _openFilterModal,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _activeFilterCount > 0 ? const Color(0xFF1E3A5F) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _activeFilterCount > 0 ? const Color(0xFF1E3A5F) : Colors.grey.shade300,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: _activeFilterCount > 0 ? Colors.white : const Color(0xFF1E3A5F),
                    size: 20,
                  ),
                ),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_activeFilterCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== ACTIVE FILTERS BANNER ====================
  Widget _buildActiveFiltersBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF1E3A5F)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Filtered by: ${_followUpFilter.isNotEmpty ? 'Follow-up: $_followUpFilter • ' : ''}${_createdByFilter != null ? 'Created by: ${_createdByNameFilter ?? '#$_createdByFilter'} • ' : ''}${_statusFilter.isNotEmpty ? 'Status: $_statusFilter • ' : ''}${_datePreset != 'all' ? 'Date: $_datePreset • ' : ''}${_searchCtrl.text.isNotEmpty ? 'Search: "${_searchCtrl.text}"' : ''}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E3A5F)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _resetFilters,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Clear', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== LEADS LIST ====================
  Widget _buildLeads() {
    if (_leads.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        color: const Color(0xFF1E3A5F),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchCtrl.text.trim().isNotEmpty ? Icons.search_off_rounded : Icons.people_outline_rounded,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchCtrl.text.trim().isNotEmpty
                          ? 'No leads found matching "${_searchCtrl.text.trim()}"'
                          : 'No leads found',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchCtrl.text.trim().isNotEmpty
                          ? 'Check customer name, mobile number, or company name'
                          : (_activeFilterCount > 0 ? 'Try clearing or changing filters' : 'Tap "+ Create Inquiry" to add a lead'),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    if (_searchCtrl.text.trim().isNotEmpty || _activeFilterCount > 0) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: const Text('Reset All Filters / Search'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: const Color(0xFF1E3A5F),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
        itemCount: _leads.length,
        itemBuilder: (_, i) {
          final l = _leads[i];
          final name = l['customer_name'] ?? '';
          final phone = l['phone'] ?? l['customer_phone'] ?? l['mobile'] ?? '';
          final status = l['status'] ?? 'new';
          final statusColor = _statusColor(status);
          final priority = l['priority']?.toString() ?? '';
          final source = l['source'] ?? l['lead_source'] ?? '';
          final city = l['city']?.toString() ?? '';
          final requirement = l['requirement']?.toString() ?? '';

          // Creator info
          String creatorName = '';
          if (l['creator_first'] != null && l['creator_first'].toString().trim().isNotEmpty) {
            creatorName = "${l['creator_first']} ${l['creator_last'] ?? ''}".trim();
            if (l['creator_code'] != null && l['creator_code'].toString().isNotEmpty) {
              creatorName += " (${l['creator_code']})";
            }
          } else if (l['creator_username'] != null && l['creator_username'].toString().trim().isNotEmpty) {
            creatorName = l['creator_username'].toString();
          } else {
            creatorName = 'Admin / System';
          }

          // Assigned Telecaller info
          String assignedName = '';
          if (l['assigned_first'] != null && l['assigned_first'].toString().trim().isNotEmpty) {
            assignedName = "${l['assigned_first']} ${l['assigned_last'] ?? ''}".trim();
            if (l['assigned_code'] != null && l['assigned_code'].toString().isNotEmpty) {
              assignedName += " (${l['assigned_code']})";
            }
          } else if (l['assigned_to'] != null && l['assigned_to'].toString().isNotEmpty) {
            assignedName = "Telecaller #${l['assigned_to']}";
          } else {
            assignedName = 'Unassigned';
          }

          // Follow-up formatted with Day
          String? followUpFormatted;
          String? followUpTag;
          Color followUpTagColor = Colors.deepPurple;
          final fupRaw = l['follow_up_date']?.toString();
          if (fupRaw != null && fupRaw.isNotEmpty && fupRaw != '0000-00-00') {
            final fdt = DateTime.tryParse(fupRaw);
            if (fdt != null) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final fDateOnly = DateTime(fdt.year, fdt.month, fdt.day);

              final dayDiff = fDateOnly.difference(today).inDays;
              final dateStr = DateFormat('dd MMM yyyy (EEEE)').format(fdt);
              final timeStr = l['follow_up_time'] != null && l['follow_up_time'].toString().isNotEmpty
                  ? ' at ${l['follow_up_time']}'
                  : '';

              followUpFormatted = '$dateStr$timeStr';

              if (dayDiff == 0) {
                followUpTag = 'TODAY';
                followUpTagColor = Colors.orange.shade800;
              } else if (dayDiff < 0) {
                followUpTag = 'OVERDUE';
                followUpTagColor = Colors.red.shade700;
              } else {
                followUpTag = 'UPCOMING';
                followUpTagColor = Colors.blue.shade700;
              }
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: followUpTag == 'TODAY'
                  ? Border.all(color: Colors.orange.shade400, width: 1.5)
                  : (followUpTag == 'OVERDUE' ? Border.all(color: Colors.red.shade300, width: 1.5) : null),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ExpansionTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E3A5F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (priority.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: priority.toLowerCase() == 'urgent' ? Colors.red.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: priority.toLowerCase() == 'urgent' ? Colors.red.shade200 : Colors.grey.shade300, width: 0.5),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: priority.toLowerCase() == 'urgent' ? Colors.red : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded, size: 11, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(phone, style: TextStyle(color: Colors.grey[800], fontSize: 11, fontWeight: FontWeight.w600)),
                      if (city.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('• $city', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                      ],
                      if (source.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('• $source', style: TextStyle(color: Colors.blue.shade700, fontSize: 10, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // FOLLOW UP (DIRECTLY VISIBLE IN SUBTITLE)
                  if (followUpFormatted != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: followUpTagColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            followUpTag == 'TODAY' ? Icons.alarm_on_rounded : Icons.event_available_rounded,
                            size: 11,
                            color: followUpTagColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'FUP: $followUpFormatted',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: followUpTagColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '[$followUpTag]',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: followUpTagColor),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'No follow-up set',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    ),

                  const SizedBox(height: 2),
                  // ASSIGNED TELECALLER & CREATOR ROW
                  Row(
                    children: [
                      Icon(Icons.headset_mic_rounded, size: 10.5, color: assignedName == 'Unassigned' ? Colors.grey : const Color(0xFF1E3A5F)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Assigned: $assignedName',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: assignedName == 'Unassigned' ? Colors.grey.shade600 : const Color(0xFF1E3A5F),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• by $creatorName',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),

                  // LATEST CALL FEEDBACK BADGE
                  if ((l['latest_call_outcome'] ?? l['latest_call_status']) != null &&
                      (l['latest_call_outcome'] ?? l['latest_call_status']).toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _outcomeColor((l['latest_call_outcome'] ?? l['latest_call_status']).toString()).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _outcomeColor((l['latest_call_outcome'] ?? l['latest_call_status']).toString()).withOpacity(0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _outcomeIcon((l['latest_call_outcome'] ?? l['latest_call_status']).toString()),
                            size: 10,
                            color: _outcomeColor((l['latest_call_outcome'] ?? l['latest_call_status']).toString()),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Last: ${l['latest_call_outcome'] ?? l['latest_call_status']}',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: _outcomeColor((l['latest_call_outcome'] ?? l['latest_call_status']).toString()),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (l['latest_call_at'] != null && l['latest_call_at'].toString().isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '• ${l['latest_call_at'].toString().length >= 16 ? l['latest_call_at'].toString().substring(5, 16) : l['latest_call_at']}',
                              style: TextStyle(fontSize: 8.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showCallFeedbackDialog(l);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.2), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rate_review_rounded, size: 11, color: Color(0xFF1E3A5F)),
                          SizedBox(width: 2),
                          Text(
                            'Feedback',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (requirement.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.school_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  requirement,
                                  style: TextStyle(color: Colors.grey.shade800, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (l['notes'] != null && l['notes'].toString().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.note_alt_outlined, size: 14, color: Colors.amber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${l['notes']}',
                                  style: TextStyle(color: Colors.grey.shade800, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 6),
                      // Latest Call Note preview if available
                      if (l['latest_call_notes'] != null && l['latest_call_notes'].toString().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F).withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.12)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.rate_review_outlined, size: 14, color: Color(0xFF1E3A5F)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Latest Call Note: ${l['latest_call_notes']}',
                                  style: TextStyle(color: Colors.grey.shade800, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 6),
                      // Action Buttons Row 1: Call, WhatsApp, Immediate Feedback
                      Row(
                        children: [
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.call_rounded,
                              'Call',
                              () => _makePhoneCall(phone, l),
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.message_rounded,
                              'WhatsApp',
                              () => _openWhatsApp(phone),
                              Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.rate_review_rounded,
                              'Feedback',
                              () => _showCallFeedbackDialog(l),
                              const Color(0xFF1E3A5F),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Action Buttons Row 2: Follow-up, Qualify, Not Int.
                      Row(
                        children: [
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.event_rounded,
                              'Follow-up',
                              () => _showFollowUpDialog(l),
                              Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.check_circle_rounded,
                              'Qualify',
                              () => _qualifyLead(l),
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.cancel_rounded,
                              'Not Int.',
                              () => _updateStatus(l, 'not_interested'),
                              Colors.red,
                            ),
                          ),
                        ],
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

  // ==================== GLASS ACTION BUTTON ====================
  Widget _buildGlassActionButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FOLLOW-UPS LIST ====================
  Widget _buildFollowUps() {
    final displayed = _displayedFollowUps;
    if (displayed.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetch,
        color: const Color(0xFF1E3A5F),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.18),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _searchCtrl.text.trim().isNotEmpty ? Icons.search_off_rounded : Icons.event_note_rounded,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchCtrl.text.trim().isNotEmpty
                          ? 'No follow-ups match "${_searchCtrl.text.trim()}"'
                          : 'No due follow-ups for today',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if (_searchCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Clear Search'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: const Color(0xFF1E3A5F),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
        itemCount: displayed.length,
        itemBuilder: (_, i) {
          final f = displayed[i];
          final leadName = f['lead_name'] ?? f['customer_name'] ?? 'Unknown';
          final phone = f['lead_phone'] ?? f['phone'] ?? f['customer_phone'] ?? '';
          final requirement = f['lead_requirement']?.toString() ?? '';

          String dateDay = '';
          if (f['follow_up_date'] != null) {
            final fdt = DateTime.tryParse(f['follow_up_date'].toString());
            if (fdt != null) {
              dateDay = DateFormat('dd MMM yyyy (EEEE)').format(fdt);
            } else {
              dateDay = f['follow_up_date'].toString();
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurple.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.08),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.deepPurpleAccent],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.event_note_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leadName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A5F)),
                      ),
                      if (phone.isNotEmpty)
                        Text('📞 $phone', style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '📅 $dateDay ${f['follow_up_time'] ?? ''}',
                        style: const TextStyle(color: Colors.deepPurple, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      if (requirement.isNotEmpty)
                        Text('📝 $requirement', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                      if (f['notes'] != null && f['notes'].toString().isNotEmpty)
                        Text('💬 ${f['notes']}', style: TextStyle(color: Colors.grey[700], fontSize: 11), maxLines: 2),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Call & Auto-Log Follow-up
                    GestureDetector(
                      onTap: () => _makePhoneCall(phone, {
                        'id': f['lead_id'] ?? f['id'],
                        'customer_name': leadName,
                        'phone': phone,
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.call_rounded, color: Colors.green, size: 18),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Complete
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await ApiService().post('follow_ups/complete', {'id': f['id']});
                        _fetch();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.blue, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== IMMEDIATE CALL FEEDBACK MODAL ====================
  void _showCallFeedbackDialog(Map<String, dynamic> l) {
    HapticFeedback.lightImpact();
    final phone = l['phone'] ?? l['customer_phone'] ?? l['mobile'] ?? '';
    final name = l['customer_name'] ?? 'Customer';
    final leadId = l['lead_id'] ?? l['id'];
    final notesCtrl = TextEditingController();
    
    // Default outcome
    String selectedOutcome = (l['latest_call_outcome'] ?? l['latest_call_status'] ?? 'Connected — Interested').toString();
    bool match = _callOutcomes.any((item) => item['label'].toString().toLowerCase() == selectedOutcome.toLowerCase());
    if (!match) {
      selectedOutcome = 'Connected — Interested';
    } else {
      selectedOutcome = _callOutcomes.firstWhere((item) => item['label'].toString().toLowerCase() == selectedOutcome.toLowerCase())['label'] as String;
    }

    DateTime? selectedFupDate;
    TimeOfDay? selectedFupTime = const TimeOfDay(hour: 10, minute: 30);
    bool isSubmitting = false;
    String? validationError;

    // Pre-select follow-up date if outcome requires it
    final initialMap = _callOutcomes.firstWhere((item) => item['label'] == selectedOutcome, orElse: () => _callOutcomes.first);
    if (initialMap['requiresFollowUp'] == true) {
      selectedFupDate = DateTime.now().add(const Duration(days: 1));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          final now = DateTime.now();
          final tomorrow = now.add(const Duration(days: 1));
          final in2Days = now.add(const Duration(days: 2));
          final in3Days = now.add(const Duration(days: 3));
          final in1Week = now.add(const Duration(days: 7));

          final currentOutcomeMap = _callOutcomes.firstWhere(
            (item) => item['label'] == selectedOutcome,
            orElse: () => _callOutcomes.first,
          );
          final bool requiresFollowUp = currentOutcomeMap['requiresFollowUp'] == true;
          final Color currentOutcomeColor = currentOutcomeMap['color'] as Color;

          return Container(
            padding: EdgeInsets.only(
              top: 18,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.rate_review_rounded, color: Color(0xFF1E3A5F), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Call Feedback: $name',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                if (phone.isNotEmpty)
                                  Text(
                                    phone,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                  ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('#$leadId', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (phone.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.call_rounded, color: Colors.green),
                          tooltip: 'Redial',
                          onPressed: () => _makePhoneCall(phone),
                        ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Validation Error
                  if (validationError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              validationError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. Call Outcome selector
                  Row(
                    children: [
                      const Text('SELECT CALL OUTCOME *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const Spacer(),
                      Text(
                        selectedOutcome,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: currentOutcomeColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _callOutcomes.map((item) {
                      final label = item['label'] as String;
                      final isSelected = selectedOutcome == label;
                      final color = item['color'] as Color;
                      final icon = item['icon'] as IconData;

                      return ChoiceChip(
                        avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : color),
                        label: Text(label),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.grey.shade800,
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: color.withOpacity(0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? color : color.withOpacity(0.3),
                            width: isSelected ? 1.5 : 0.8,
                          ),
                        ),
                        onSelected: (val) {
                          if (val) {
                            setLocalState(() {
                              selectedOutcome = label;
                              validationError = null;
                              if (item['requiresFollowUp'] == true && selectedFupDate == null) {
                                selectedFupDate = tomorrow;
                              }
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // 2. Schedule Next Follow-up
                  if (requiresFollowUp || selectedFupDate != null) ...[
                    Row(
                      children: [
                        Text(
                          requiresFollowUp ? 'FOLLOW-UP DATE & TIME *' : 'FOLLOW-UP (OPTIONAL)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: requiresFollowUp ? Colors.deepPurple : Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        if (selectedFupDate != null)
                          GestureDetector(
                            onTap: () {
                              setLocalState(() {
                                selectedFupDate = null;
                                validationError = null;
                              });
                            },
                            child: const Text('Clear Follow-up', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickDayChip(
                          'Tomorrow (${DateFormat('E').format(tomorrow)})',
                          selectedFupDate != null &&
                              selectedFupDate!.year == tomorrow.year &&
                              selectedFupDate!.month == tomorrow.month &&
                              selectedFupDate!.day == tomorrow.day,
                          () => setLocalState(() {
                            selectedFupDate = tomorrow;
                            validationError = null;
                          }),
                        ),
                        _buildQuickDayChip(
                          '+2 Days (${DateFormat('E').format(in2Days)})',
                          selectedFupDate != null &&
                              selectedFupDate!.year == in2Days.year &&
                              selectedFupDate!.month == in2Days.month &&
                              selectedFupDate!.day == in2Days.day,
                          () => setLocalState(() {
                            selectedFupDate = in2Days;
                            validationError = null;
                          }),
                        ),
                        _buildQuickDayChip(
                          '+3 Days (${DateFormat('E').format(in3Days)})',
                          selectedFupDate != null &&
                              selectedFupDate!.year == in3Days.year &&
                              selectedFupDate!.month == in3Days.month &&
                              selectedFupDate!.day == in3Days.day,
                          () => setLocalState(() {
                            selectedFupDate = in3Days;
                            validationError = null;
                          }),
                        ),
                        _buildQuickDayChip(
                          '+1 Week',
                          selectedFupDate != null &&
                              selectedFupDate!.year == in1Week.year &&
                              selectedFupDate!.month == in1Week.month &&
                              selectedFupDate!.day == in1Week.day,
                          () => setLocalState(() {
                            selectedFupDate = in1Week;
                            validationError = null;
                          }),
                        ),
                        _buildQuickDayChip(
                          'Custom Date 📅',
                          selectedFupDate != null &&
                              selectedFupDate!.day != tomorrow.day &&
                              selectedFupDate!.day != in2Days.day &&
                              selectedFupDate!.day != in3Days.day &&
                              selectedFupDate!.day != in1Week.day,
                          () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedFupDate ?? tomorrow,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                              helpText: 'SELECT FOLLOW-UP DATE & DAY',
                            );
                            if (picked != null) {
                              setLocalState(() {
                                selectedFupDate = picked;
                                validationError = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildQuickTimeChip(
                          'Morning (10:30 AM)',
                          selectedFupTime?.hour == 10 && selectedFupTime?.minute == 30,
                          () => setLocalState(() => selectedFupTime = const TimeOfDay(hour: 10, minute: 30)),
                        ),
                        _buildQuickTimeChip(
                          'Afternoon (02:30 PM)',
                          selectedFupTime?.hour == 14 && selectedFupTime?.minute == 30,
                          () => setLocalState(() => selectedFupTime = const TimeOfDay(hour: 14, minute: 30)),
                        ),
                        _buildQuickTimeChip(
                          'Evening (05:00 PM)',
                          selectedFupTime?.hour == 17 && selectedFupTime?.minute == 0,
                          () => setLocalState(() => selectedFupTime = const TimeOfDay(hour: 17, minute: 0)),
                        ),
                        _buildQuickTimeChip(
                          'Custom Time ⏰',
                          selectedFupTime != null &&
                              !(selectedFupTime?.hour == 10 && selectedFupTime?.minute == 30) &&
                              !(selectedFupTime?.hour == 14 && selectedFupTime?.minute == 30) &&
                              !(selectedFupTime?.hour == 17 && selectedFupTime?.minute == 0),
                          () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedFupTime ?? const TimeOfDay(hour: 10, minute: 30),
                            );
                            if (picked != null) {
                              setLocalState(() => selectedFupTime = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (selectedFupDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.deepPurple.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.alarm_on_rounded, color: Colors.deepPurple, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Scheduled: ${DateFormat('dd MMM yyyy (EEEE)').format(selectedFupDate!)}${selectedFupTime != null ? ' at ${selectedFupTime!.format(context)}' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepPurple),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        setLocalState(() {
                          selectedFupDate = tomorrow;
                          selectedFupTime = const TimeOfDay(hour: 10, minute: 30);
                        });
                      },
                      icon: const Icon(Icons.event_note_rounded, size: 16),
                      label: const Text('Add Next Follow-up Date (Optional)', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A5F),
                        side: BorderSide(color: const Color(0xFF1E3A5F).withOpacity(0.3)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 3. Discussion Summary & Notes
                  const Text('CALL SUMMARY / NOTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Discussed requirements, customer questions, next steps...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (requiresFollowUp && selectedFupDate == null) {
                                setLocalState(() {
                                  validationError = '⚠️ "$selectedOutcome" requires a follow-up date & time. Please select one above.';
                                });
                                return;
                              }

                              setLocalState(() {
                                isSubmitting = true;
                                validationError = null;
                              });

                              final fDateStr = selectedFupDate != null
                                  ? DateFormat('yyyy-MM-dd').format(selectedFupDate!)
                                  : null;
                              final fTimeStr = (selectedFupDate != null && selectedFupTime != null)
                                  ? selectedFupTime!.format(context)
                                  : null;

                              final req = {
                                'lead_id': leadId,
                                'call_status': selectedOutcome,
                                'call_outcome': selectedOutcome,
                                'notes': notesCtrl.text.trim(),
                                if (fDateStr != null) 'follow_up_date': fDateStr,
                                if (fTimeStr != null) 'follow_up_time': fTimeStr,
                              };

                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);
                              final res = await ApiService().post('telecaller/call-feedback', req);
                              setLocalState(() => isSubmitting = false);

                              if (mounted) {
                                navigator.pop();
                                _fetch();

                                if (res['success'] == true) {
                                  final msg = fDateStr != null
                                      ? '✅ Feedback saved! Next follow-up: ${DateFormat('dd MMM (EEEE)').format(selectedFupDate!)}'
                                      : '✅ Feedback "$selectedOutcome" saved for $name!';

                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(msg),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(res['message'] ?? 'Failed to save feedback'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Save Call Feedback', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickTimeChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F).withOpacity(0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade300,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickDayChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple.withOpacity(0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.deepPurple : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }

  // ==================== FOLLOW-UP DIALOG ====================
  void _showFollowUpDialog(Map<String, dynamic> l) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final notesCtrl = TextEditingController();
    final leadId = l['lead_id'] ?? l['id'];
    final name = l['customer_name'] ?? 'Customer';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) {
          final now = DateTime.now();
          final tomorrow = now.add(const Duration(days: 1));
          final in2Days = now.add(const Duration(days: 2));
          final in3Days = now.add(const Duration(days: 3));

          return Container(
            padding: EdgeInsets.only(
              top: 18,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.event_note_rounded, color: Colors.deepPurple, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Schedule Follow-up: $name',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text('Select next contact date with day', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Quick Date Chips
                  const Text('CHOOSE DATE & DAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildQuickDayChip(
                        'Tomorrow (${DateFormat('E').format(tomorrow)})',
                        selectedDate.year == tomorrow.year && selectedDate.month == tomorrow.month && selectedDate.day == tomorrow.day,
                        () => setLocalState(() => selectedDate = tomorrow),
                      ),
                      _buildQuickDayChip(
                        '+2 Days (${DateFormat('E').format(in2Days)})',
                        selectedDate.year == in2Days.year && selectedDate.month == in2Days.month && selectedDate.day == in2Days.day,
                        () => setLocalState(() => selectedDate = in2Days),
                      ),
                      _buildQuickDayChip(
                        '+3 Days (${DateFormat('E').format(in3Days)})',
                        selectedDate.year == in3Days.year && selectedDate.month == in3Days.month && selectedDate.day == in3Days.day,
                        () => setLocalState(() => selectedDate = in3Days),
                      ),
                      _buildQuickDayChip(
                        'Custom Date 📅',
                        (selectedDate.day != tomorrow.day && selectedDate.day != in2Days.day && selectedDate.day != in3Days.day),
                        () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                            helpText: 'SELECT FOLLOW-UP DATE & DAY',
                          );
                          if (picked != null) {
                            setLocalState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Date & Day Display Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepPurple.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: Colors.deepPurple, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SCHEDULED FOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                              Text(
                                DateFormat('dd MMM yyyy (EEEE)').format(selectedDate),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepPurple),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Follow-up Notes / Discussion Topic',
                      hintText: 'What should be followed up on this date?',
                      prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Schedule Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () async {
                        setLocalState(() => isSaving = true);
                        final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                        final res = await ApiService().post('telecaller/follow-up', {
                          'lead_id': leadId,
                          'follow_up_date': dateStr,
                          'notes': notesCtrl.text.trim(),
                        });
                        setLocalState(() => isSaving = false);

                        if (mounted) {
                          Navigator.pop(context);
                          _fetch();
                          if (res['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ Follow-up scheduled for ${DateFormat('dd MMM (EEEE)').format(selectedDate)}!'),
                                backgroundColor: Colors.deepPurple,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Failed to schedule follow-up'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Set Follow-up', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== QUALIFY LEAD ====================
  Future<void> _qualifyLead(Map<String, dynamic> l) async {
    HapticFeedback.mediumImpact();
    final leadId = l['lead_id'] ?? l['id'];
    final res = await ApiService().post('telecaller/qualify', {'lead_id': leadId});
    if (mounted) {
      _fetch();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Lead qualified successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ==================== UPDATE STATUS ====================
  Future<void> _updateStatus(Map<String, dynamic> l, String status) async {
    HapticFeedback.mediumImpact();
    final leadId = l['lead_id'] ?? l['id'];
    final res = await ApiService().post('telecaller/update-status', {
      'lead_id': leadId,
      'status': status,
    });
    if (mounted) {
      _fetch();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Status updated successfully!'),
          backgroundColor: status == 'not_interested' || status == 'wrong_number' ? Colors.red : Colors.blue,
        ),
      );
    }
  }
}