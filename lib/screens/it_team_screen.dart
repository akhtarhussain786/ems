import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ITTeamScreen extends StatefulWidget {
  const ITTeamScreen({super.key});

  @override
  State<ITTeamScreen> createState() => _ITTeamScreenState();
}

class _ITTeamScreenState extends State<ITTeamScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _tasks = [];
  Map<String, dynamic>? _points;
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  File? _workFile;
  String? _selectedTaskId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _submitting = false;
  int _filterIndex = 0; // 0: All, 1: Pending, 2: In Progress, 3: Completed

  final List<String> _filterLabels = ['All', 'Pending', 'In Progress', 'Completed'];

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
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('it/dashboard');
      if (mounted && res['success'] == true) {
        setState(() {
          _tasks = res['data']?['tasks'] ?? [];
          _points = res['data']?['points'];
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submitWork() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final fields = {
        'task_id': _selectedTaskId ?? '',
        'description': _descCtrl.text,
      };
      final res = await ApiService().postMultipart('it/submit-work', fields, _workFile, fileField: 'work_file');

      if (mounted) {
        Navigator.pop(context);
        if (res['success'] == true) {
          _fetch();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Work submitted successfully'),
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
              content: Text(res['message'] ?? '❌ Failed to submit work'),
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

  Future<void> _pickFile() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file != null) setState(() => _workFile = File(file.path));
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority) {
      case 'urgent': return Icons.priority_high_rounded;
      case 'high': return Icons.trending_up_rounded;
      case 'medium': return Icons.trending_flat_rounded;
      default: return Icons.trending_down_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed': return 'Completed';
      case 'in_progress': return 'In Progress';
      default: return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'in_progress': return Colors.orange;
      default: return Colors.blue;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed': return Icons.check_circle_rounded;
      case 'in_progress': return Icons.access_time_rounded;
      default: return Icons.pending_rounded;
    }
  }

  List<dynamic> _getFilteredTasks() {
    if (_filterIndex == 0) return _tasks;
    final statusMap = {
      1: 'pending',
      2: 'in_progress',
      3: 'completed',
    };
    final status = statusMap[_filterIndex];
    return _tasks.where((t) => (t['status'] ?? 'pending') == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _getFilteredTasks();

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
          _buildPointsCard(),
          const SizedBox(height: 8),
          _buildFilterChips(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetch,
              color: const Color(0xFF1E3A5F),
              child: filteredTasks.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filteredTasks.length,
                  itemBuilder: (_, i) {
                    final t = filteredTasks[i];
                    return _buildGlassTaskCard(t);
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
                  Icons.computer_rounded,
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
                'IT Dashboard',
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
        _showSubmitForm();
      },
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(Icons.upload_file_rounded, size: 28),
    );
  }

  // ==================== POINTS CARD ====================
  Widget _buildPointsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildPointsItem(
            label: 'Points',
            value: '${_points?['total'] ?? 0}',
            icon: Icons.star_rounded,
            color: Colors.amber,
          ),
          _buildPointsItem(
            label: 'Completed',
            value: '${_points?['completed'] ?? 0}',
            icon: Icons.check_circle_rounded,
            color: Colors.green,
          ),
          _buildPointsItem(
            label: 'Pending',
            value: '${_points?['pending'] ?? 0}',
            icon: Icons.pending_rounded,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildPointsItem({required String label, required String value, required IconData icon, required Color color}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ==================== FILTER CHIPS ====================
  Widget _buildFilterChips() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
    String message = 'No tasks assigned';
    String subMessage = 'Check back later for updates';

    switch (_filterIndex) {
      case 1:
        message = 'No pending tasks';
        subMessage = 'All tasks are in progress or completed';
        break;
      case 2:
        message = 'No tasks in progress';
        subMessage = 'All tasks are pending or completed';
        break;
      case 3:
        message = 'No completed tasks';
        subMessage = 'Complete tasks to see them here';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.computer_rounded,
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

  // ==================== GLASS TASK CARD ====================
  Widget _buildGlassTaskCard(Map<String, dynamic> t) {
    final priority = t['priority'] ?? 'medium';
    final priorityColor = _priorityColor(priority);
    final status = t['status'] ?? 'pending';
    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);
    final isCompleted = status == 'completed';

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
          // Priority Indicator
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [priorityColor, priorityColor.withOpacity(0.5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t['title'] ?? 'Untitled',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isCompleted ? Colors.grey[500] : const Color(0xFF1E3A5F),
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.12),
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _priorityIcon(priority),
                            size: 10,
                            color: priorityColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            priority.toUpperCase(),
                            style: TextStyle(
                              color: priorityColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: isCompleted ? Colors.grey[400] : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${t['due_date'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCompleted ? Colors.grey[400] : Colors.grey[600],
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
                if (t['description'] != null && t['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    t['description'],
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Status Icon
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
            color: isCompleted ? Colors.green : Colors.grey[400],
            size: isCompleted ? 20 : 14,
          ),
        ],
      ),
    );
  }

  // ==================== SUBMIT WORK FORM ====================
  void _showSubmitForm() {
    _selectedTaskId = _tasks.isNotEmpty ? _tasks[0]['id'].toString() : null;
    _descCtrl.clear();
    _workFile = null;

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
                          Icons.upload_file_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Submit Work',
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
                    value: _selectedTaskId,
                    items: _tasks.map((t) => t['id'].toString()).toList(),
                    label: 'Select Task',
                    onChanged: (v) => setLocalState(() => _selectedTaskId = v),
                    getLabel: (v) {
                      final task = _tasks.firstWhere((t) => t['id'].toString() == v, orElse: () => null);
                      return task != null ? task['title'] ?? 'Task' : 'Select Task';
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _descCtrl,
                    label: 'Work Description',
                    icon: Icons.description_rounded,
                    maxLines: 3,
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _workFile != null ? Colors.green.shade50 : Colors.grey.shade50,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(
                          color: _workFile != null ? Colors.green.shade200 : Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            color: _workFile != null ? Colors.green : Colors.grey[500],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _workFile != null
                                  ? '📎 File attached: ${_workFile!.path.split('/').last}'
                                  : 'Tap to attach file (Image/PDF)',
                              style: TextStyle(
                                color: _workFile != null ? Colors.green.shade700 : Colors.grey[600],
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_workFile != null)
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                              onPressed: () => setLocalState(() => _workFile = null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitWork,
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
                      'Submit Work',
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
    required String? value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
    required String Function(String) getLabel,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((s) => DropdownMenuItem(
        value: s,
        child: Text(getLabel(s)),
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