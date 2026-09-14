import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/lead_constants.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_dropdown_sheet.dart';
import '../widgets/form_section_card.dart';
import '../widgets/date_time_selector_card.dart';

/// Premium CRM Create Lead / Edit Lead Screen
///
/// Features a SaaS CRM aesthetic, structured into 5 logical sections:
/// 1. Basic Information
/// 2. Lead Details
/// 3. Location Details
/// 4. Follow-Up Information
/// 5. Notes
///
/// Includes inline validation, sticky bottom CTAs ("Create Lead" & "Save & Add Another"),
/// keyboard safe insets, and full edit mode support.
class CreateLeadScreen extends StatefulWidget {
  final Map<String, dynamic>? lead;

  const CreateLeadScreen({super.key, this.lead});

  @override
  State<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _requirementCtrl = TextEditingController();
  final _campaignCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Dropdown / Selection states
  String _source = 'Website';
  String _priority = 'Medium';
  String _status = 'New';
  String _nextAction = 'Follow-up Call';
  int? _selectedTelecaller;
  DateTime? _followUpDate;
  TimeOfDay? _followUpTime;

  bool _submitting = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool get isEditMode => widget.lead != null && (widget.lead!['id'] != null || widget.lead!['lead_id'] != null);
  int? get editId => widget.lead != null ? (widget.lead!['id'] ?? widget.lead!['lead_id']) : null;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _populateExistingData();
    _animController.forward();
  }

  void _populateExistingData() {
    if (widget.lead == null) return;
    final l = widget.lead!;

    _nameCtrl.text = l['customer_name'] ?? l['name'] ?? '';
    _phoneCtrl.text = l['phone'] ?? l['customer_phone'] ?? l['mobile'] ?? '';
    _altPhoneCtrl.text = l['alt_phone'] ?? l['alternate_mobile'] ?? l['customer_mobile'] ?? '';
    _emailCtrl.text = l['email'] ?? l['customer_email'] ?? '';
    _companyCtrl.text = l['company_name'] ?? l['company'] ?? '';
    _requirementCtrl.text = l['requirement'] ?? l['course_interested'] ?? l['interested_service'] ?? '';
    _campaignCtrl.text = l['campaign_name'] ?? l['campaign'] ?? '';
    _budgetCtrl.text = l['budget'] != null ? '${l['budget']}' : '';
    _addressCtrl.text = l['address'] ?? '';
    _cityCtrl.text = l['city'] ?? '';
    _stateCtrl.text = l['state'] ?? '';
    _pincodeCtrl.text = l['pincode'] ?? l['pin_code'] ?? '';
    _notesCtrl.text = l['notes'] ?? '';

    final rawSource = l['source'] ?? l['lead_source'] ?? 'Website';
    _source = LeadConstants.sources.contains(rawSource) ? rawSource : 'Website';

    final rawPriority = l['priority'] ?? 'Medium';
    _priority = LeadConstants.priorities.contains(rawPriority) ? rawPriority : 'Medium';

    final rawStatus = l['status'] ?? 'New';
    _status = LeadConstants.statuses.contains(rawStatus) ? rawStatus : 'New';

    _selectedTelecaller = l['assigned_to'];

    if (l['follow_up_date'] != null && l['follow_up_date'].toString().isNotEmpty) {
      try {
        final parsed = DateTime.parse(l['follow_up_date'].toString());
        _followUpDate = parsed;
        _followUpTime = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    _requirementCtrl.dispose();
    _campaignCtrl.dispose();
    _budgetCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _resetFormFields() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _altPhoneCtrl.clear();
    _emailCtrl.clear();
    _companyCtrl.clear();
    _requirementCtrl.clear();
    _campaignCtrl.clear();
    _budgetCtrl.clear();
    _addressCtrl.clear();
    _cityCtrl.clear();
    _stateCtrl.clear();
    _pincodeCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _source = 'Website';
      _priority = 'Medium';
      _status = 'New';
      _nextAction = 'Follow-up Call';
      _selectedTelecaller = null;
      _followUpDate = null;
      _followUpTime = null;
    });
  }

  Map<String, dynamic> _preparePayload() {
    String? formattedFollowUp;
    if (_followUpDate != null) {
      final time = _followUpTime ?? const TimeOfDay(hour: 10, minute: 30);
      final dt = DateTime(
        _followUpDate!.year,
        _followUpDate!.month,
        _followUpDate!.day,
        time.hour,
        time.minute,
      );
      formattedFollowUp = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    }

    return {
      'customer_name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      if (_altPhoneCtrl.text.trim().isNotEmpty) 'alt_phone': _altPhoneCtrl.text.trim(),
      if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
      if (_companyCtrl.text.trim().isNotEmpty) 'company_name': _companyCtrl.text.trim(),
      if (_cityCtrl.text.trim().isNotEmpty) 'city': _cityCtrl.text.trim(),
      if (_stateCtrl.text.trim().isNotEmpty) 'state': _stateCtrl.text.trim(),
      if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
      if (_pincodeCtrl.text.trim().isNotEmpty) 'pincode': _pincodeCtrl.text.trim(),
      'source': _source,
      'status': _status.toLowerCase(),
      'priority': _priority,
      if (_campaignCtrl.text.trim().isNotEmpty) 'campaign_name': _campaignCtrl.text.trim(),
      if (_requirementCtrl.text.trim().isNotEmpty) 'requirement': _requirementCtrl.text.trim(),
      if (_budgetCtrl.text.trim().isNotEmpty) 'budget': double.tryParse(_budgetCtrl.text.trim()),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      if (_selectedTelecaller != null) 'assigned_to': _selectedTelecaller,
      if (formattedFollowUp != null) ...{
        'follow_up_date': formattedFollowUp,
        'next_action': _nextAction,
      },
    };
  }

  Future<void> _submit({bool addAnother = false}) async {
    if (_submitting) return;

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      _showFeedback(
        'Please fix the highlighted errors before saving.',
        isError: true,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _submitting = true);

    try {
      final payload = _preparePayload();

      final res = isEditMode
          ? await ApiService().updateLead({'id': editId, ...payload})
          : await ApiService().createLead(payload);

      if (!mounted) return;

      if (res['success'] == true) {
        final newId = int.tryParse('${res['id'] ?? 0}') ?? 0;

        // If a follow up date was provided for a new lead, ensure follow up is also recorded
        if (!isEditMode && _followUpDate != null) {
          try {
            await ApiService().createFollowUp({
              'customer_name': _nameCtrl.text.trim(),
              'customer_phone': _phoneCtrl.text.trim(),
              'follow_up_type': _nextAction,
              'notes': _notesCtrl.text.trim().isNotEmpty
                  ? _notesCtrl.text.trim()
                  : 'Follow-up for ${_nameCtrl.text.trim()}',
            });
          } catch (_) {
            // Non-critical fallback
          }
        }

        final successMessage = isEditMode ? '✓ Lead Updated Successfully' : '✓ Lead Created Successfully';

        if (addAnother) {
          _showFeedback(successMessage, isError: false);
          _resetFormFields();
        } else {
          Navigator.pop(context, {
            'success': true,
            'isNew': !isEditMode,
            'id': newId > 0 ? newId : editId,
            'data': payload,
            'message': successMessage,
          });
        }
      } else {
        _showFeedback(res['message'] ?? 'Failed to save lead. Please try again.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to save lead.';
        if (e.toString().contains('SocketException') || e.toString().contains('internet')) {
          msg = 'No internet connection. Please check network.';
        } else if (e.toString().contains('TimeoutException')) {
          msg = 'Server request timed out. Please retry.';
        }
        _showFeedback(msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showFeedback(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeaderBanner(),
                        const SizedBox(height: 16),
                        _buildSection1BasicInfo(),
                        _buildSection2LeadDetails(),
                        _buildSection3Location(),
                        _buildSection4FollowUp(),
                        _buildSection5Notes(),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
              _buildStickyBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== APP BAR ====================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
        tooltip: 'Back',
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isEditMode ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isEditMode ? 'Edit Lead' : 'Create New Lead',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        if (isEditMode)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              label: Text(
                'ID #$editId',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  // ==================== HEADER BANNER ====================
  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditMode ? 'Update Lead Information' : 'Create New Lead',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Add lead information and keep your sales pipeline organized.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SECTION 1: BASIC INFORMATION ====================
  Widget _buildSection1BasicInfo() {
    return FormSectionCard(
      title: 'Basic Information',
      subtitle: 'Contact details of the potential customer',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          AppTextField(
            controller: _nameCtrl,
            label: 'Customer Name',
            hint: 'e.g. John Doe / Rahul Sharma',
            prefixIcon: Icons.person_rounded,
            isRequired: true,
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Customer name is required';
              }
              if (v.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _companyCtrl,
            label: 'Company / Business Name',
            hint: 'e.g. Acme Corp / Yatharth Infotech',
            prefixIcon: Icons.business_rounded,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _phoneCtrl,
            label: 'Mobile Number',
            hint: '10-digit mobile number',
            isRequired: true,
            keyboardType: TextInputType.phone,
            prefixWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_rounded, size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text(
                    '+91',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Mobile number is required';
              }
              if (v.trim().length < 10) {
                return 'Please enter a valid 10-digit mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _altPhoneCtrl,
                  label: 'Alternate Mobile',
                  hint: 'Optional phone',
                  prefixIcon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _emailCtrl,
                  label: 'Email Address',
                  hint: 'name@example.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(v.trim())) {
                      return 'Invalid email address';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== SECTION 2: LEAD DETAILS ====================
  Widget _buildSection2LeadDetails() {
    return FormSectionCard(
      title: 'Lead Details',
      subtitle: 'Source, status, priority, and requirement',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppDropdownField(
                  label: 'Lead Source',
                  value: _source,
                  items: LeadConstants.sources,
                  prefixIcon: LeadConstants.getSourceIcon(_source),
                  sheetTitle: 'Select Lead Source',
                  itemIconBuilder: LeadConstants.getSourceIcon,
                  onChanged: (v) {
                    if (v != null) setState(() => _source = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppDropdownField(
                  label: 'Lead Status',
                  value: _status,
                  items: LeadConstants.statuses,
                  prefixIcon: Icons.flag_outlined,
                  sheetTitle: 'Select Lead Status',
                  itemColorBuilder: LeadConstants.getStatusColor,
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Priority Segmented Selector
          const Text(
            'Priority Level',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: LeadConstants.priorities.map((p) {
              final isSelected = _priority.toLowerCase() == p.toLowerCase();
              final color = LeadConstants.getPriorityColor(p);
              final icon = LeadConstants.getPriorityIcon(p);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _priority = p);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? color : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: isSelected ? color : const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? color : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _requirementCtrl,
            label: 'Interested Service / Product',
            hint: 'e.g. Attendance System / Web Design / CRM Setup',
            prefixIcon: Icons.inventory_2_outlined,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _campaignCtrl,
                  label: 'Campaign Name',
                  hint: 'e.g. Google Ads Dec 2024',
                  prefixIcon: Icons.campaign_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _budgetCtrl,
                  label: 'Estimated Budget (₹)',
                  hint: 'e.g. 50000',
                  prefixIcon: Icons.currency_rupee_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== SECTION 3: LOCATION ====================
  Widget _buildSection3Location() {
    return FormSectionCard(
      title: 'Location Information',
      subtitle: 'City, state and address details',
      icon: Icons.location_on_outlined,
      child: Column(
        children: [
          AppTextField(
            controller: _addressCtrl,
            label: 'Address / Street',
            hint: 'e.g. Sector 62, Commercial Complex',
            prefixIcon: Icons.home_work_outlined,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _cityCtrl,
                  label: 'City',
                  hint: 'e.g. Noida / Delhi',
                  prefixIcon: Icons.location_city_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _pincodeCtrl,
                  label: 'PIN Code',
                  hint: '6-digit PIN',
                  prefixIcon: Icons.pin_drop_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppDropdownField(
            label: 'State',
            value: _stateCtrl.text.isNotEmpty ? _stateCtrl.text : null,
            items: LeadConstants.indianStates,
            hint: 'Select State',
            prefixIcon: Icons.map_outlined,
            sheetTitle: 'Select State',
            onChanged: (v) {
              if (v != null) {
                setState(() => _stateCtrl.text = v);
              }
            },
          ),
        ],
      ),
    );
  }

  // ==================== SECTION 4: FOLLOW-UP INFORMATION ====================
  Widget _buildSection4FollowUp() {
    return FormSectionCard(
      title: 'Next Follow-Up',
      subtitle: 'Schedule upcoming reminders and actions',
      icon: Icons.calendar_month_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateTimeSelectorCard(
            selectedDate: _followUpDate,
            selectedTime: _followUpTime,
            onDateChanged: (d) => setState(() => _followUpDate = d),
            onTimeChanged: (t) => setState(() => _followUpTime = t),
          ),
          if (_followUpDate != null) ...[
            const SizedBox(height: 14),
            AppDropdownField(
              label: 'Next Action Type',
              value: _nextAction,
              items: LeadConstants.nextActionTypes,
              prefixIcon: Icons.task_alt_rounded,
              sheetTitle: 'Select Next Action',
              onChanged: (v) {
                if (v != null) setState(() => _nextAction = v);
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==================== SECTION 5: NOTES ====================
  Widget _buildSection5Notes() {
    return FormSectionCard(
      title: 'Notes & Remarks',
      subtitle: 'Add important background information for your team',
      icon: Icons.notes_rounded,
      child: AppTextField(
        controller: _notesCtrl,
        label: 'Lead Notes',
        hint: 'Add important information, customer preferences, or key discussion points...',
        maxLines: 4,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }

  // ==================== STICKY BOTTOM ACTION BAR ====================
  Widget _buildStickyBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isEditMode) ...[
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : () => _submit(addAnother: true),
                icon: const Icon(Icons.library_add_rounded, size: 17),
                label: const Text(
                  'Save & Add',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A5F),
                  side: const BorderSide(color: Color(0xFF1E3A5F), width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _submit(addAnother: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isEditMode ? Icons.check_circle_outline_rounded : Icons.add_circle_outline_rounded,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isEditMode ? 'Update Lead' : 'Create Lead',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
