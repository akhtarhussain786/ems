import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class HRActivitiesScreen extends StatefulWidget {
  const HRActivitiesScreen({super.key});

  @override
  State<HRActivitiesScreen> createState() => _HRActivitiesScreenState();
}

class _HRActivitiesScreenState extends State<HRActivitiesScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _activities = [];
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'meeting';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _submitting = false;
  int _filterIndex = 0; // 0: All, 1: Pending, 2: Completed, 3: Cancelled

  final List<String> _filterLabels = ['All', 'Pending', 'Completed', 'Cancelled'];
  final List<String> _typeOptions = ['interview', 'training', 'onboarding', 'meeting', 'review', 'other'];

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
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getMyHRActivities();
      if (mounted && res['success'] == true) {
        setState(() => _activities = res['data'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final res = await ApiService().createHRActivity({
        'activity_type': _type,
        'title': _titleCtrl.text,
        'description': _descCtrl.text,
      });

      if (mounted) {
        Navigator.pop(context);
        if (res['success'] == true) {
          _fetch();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ HR Activity created successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? '❌ Failed to create activity'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'interview':
        return Colors.deepPurple;
      case 'training':
        return Colors.blue;
      case 'onboarding':
        return Colors.green;
      case 'meeting':
        return Colors.orange;
      case 'review':
        return Colors.red;
      case 'other':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'interview':
        return Icons.people_rounded;
      case 'training':
        return Icons.school_rounded;
      case 'onboarding':
        return Icons.how_to_reg_rounded;
      case 'meeting':
        return Icons.meeting_room_rounded;
      case 'review':
        return Icons.assessment_rounded;
      case 'other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.work_rounded;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'interview':
        return 'Interview';
      case 'training':
        return 'Training';
      case 'onboarding':
        return 'Onboarding';
      case 'meeting':
        return 'Meeting';
      case 'review':
        return 'Review';
      case 'other':
        return 'Other';
      default:
        return t;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  List<dynamic> _getFilteredActivities() {
    if (_filterIndex == 0) return _activities;
    final statusMap = {
      1: 'pending',
      2: 'completed',
      3: 'cancelled',
    };
    final status = statusMap[_filterIndex];
    return _activities.where((a) => (a['status'] ?? 'pending') == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredActivities = _getFilteredActivities();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(),
      floatingActionButton: _buildFAB(),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1E3A5F),
          strokeWidth: 3,
        ),
      )
          : Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetch,
              color: const Color(0xFF1E3A5F),
              child: filteredActivities.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredActivities.length,
                  itemBuilder: (_, i) {
                    final a = filteredActivities[i];
                    return _buildGlassActivityCard(a);
                  },
                ),
              ),
            ),
          ),
        ],
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
                  Icons.work_rounded,
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
                'HR Activities',
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
              _fetch();
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

  // ==================== FLOATING ACTION BUTTON ====================
  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {
        HapticFeedback.mediumImpact();
        _showForm();
      },
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }

  // ==================== FILTER CHIPS ====================
  Widget _buildFilterChips() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: List.generate(_filterLabels.length, (index) {
          final isSelected = _filterIndex == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(
                _filterLabels[index],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1E3A5F),
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              onSelected: (_) {
                setState(() => _filterIndex = index);
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          );
        }),
      ),
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState() {
    String message = 'No HR activities';
    String subMessage = 'Tap + to create a new activity';

    switch (_filterIndex) {
      case 1:
        message = 'No pending activities';
        subMessage = 'All activities are completed or cancelled';
        break;
      case 2:
        message = 'No completed activities';
        subMessage = 'Complete activities to see them here';
        break;
      case 3:
        message = 'No cancelled activities';
        subMessage = 'No activities have been cancelled';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work_rounded,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subMessage,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== GLASS ACTIVITY CARD ====================
  Widget _buildGlassActivityCard(Map<String, dynamic> a) {
    final type = a['activity_type'] ?? 'meeting';
    final typeColor = _typeColor(type);
    final typeIcon = _typeIcon(type);
    final typeLabel = _typeLabel(type);
    final status = a['status'] ?? 'pending';
    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';

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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [typeColor, typeColor.withOpacity(0.7)],
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(
              typeIcon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a['title'] ?? 'Untitled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isCompleted || isCancelled ? Colors.grey[500] : const Color(0xFF1E3A5F),
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Text(
                        typeLabel.toUpperCase(),
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      a['activity_date'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCompleted || isCancelled ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            statusIcon,
                            size: 10,
                            color: statusColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (a['description'] != null && a['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      border: Border.all(
                        color: Colors.grey[200]!,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      a['description'],
                      style: TextStyle(
                        fontSize: 11,
                        color: isCompleted || isCancelled ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SHOW FORM ====================
  void _showForm() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _type = 'meeting';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: _formKey,
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                          ),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'New HR Activity',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFormDropdown(
                    value: _type,
                    items: _typeOptions,
                    label: 'Activity Type',
                    onChanged: (v) => setLocalState(() => _type = v!),
                    getLabel: (s) => _typeLabel(s),
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _titleCtrl,
                    label: 'Title',
                    icon: Icons.title_rounded,
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _descCtrl,
                    label: 'Description',
                    icon: Icons.description_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(14)),
                      ),
                      elevation: 4,
                    ),
                    child: _submitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Save Activity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== FORM FIELD ====================
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    bool required = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey[500]) : null,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF1E3A5F)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: required
          ? (v) => v?.isEmpty == true ? '$label is required' : null
          : null,
    );
  }

  // ==================== FORM DROPDOWN ====================
  Widget _buildFormDropdown({
    required String value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
    String Function(String)? getLabel,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((s) => DropdownMenuItem(
        value: s,
        child: Text(getLabel?.call(s) ?? s),
      )).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF1E3A5F)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}