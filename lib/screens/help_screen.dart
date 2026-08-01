import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _tickets = [];
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _priority = 'medium';
  bool _submitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _filterIndex = 0; // 0: All, 1: Open, 2: In Progress, 3: Resolved

  final List<String> _filterLabels = ['All', 'Open', 'In Progress', 'Resolved'];

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
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('help/tickets');
      if (mounted && res['success'] == true) {
        setState(() => _tickets = res['data'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final res = await ApiService().post('help/create', {
        'subject': _subjectCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'priority': _priority,
      });

      if (mounted) {
        Navigator.pop(context);
        if (res['success'] == true) {
          _fetch();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Support ticket created successfully'),
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
              content: Text(res['message'] ?? '❌ Failed to create ticket'),
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

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.blue;
      case 'low': return Colors.grey;
      default: return Colors.blue;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority) {
      case 'urgent': return Icons.priority_high_rounded;
      case 'high': return Icons.trending_up_rounded;
      case 'medium': return Icons.trending_flat_rounded;
      case 'low': return Icons.trending_down_rounded;
      default: return Icons.circle_rounded;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'urgent': return 'Urgent';
      case 'high': return 'High';
      case 'medium': return 'Medium';
      case 'low': return 'Low';
      default: return priority;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'resolved': return 'Resolved';
      case 'in_progress': return 'In Progress';
      case 'closed': return 'Closed';
      default: return 'Open';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved': return Colors.green;
      case 'in_progress': return Colors.orange;
      case 'closed': return Colors.grey;
      default: return Colors.blue;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'resolved': return Icons.check_circle_rounded;
      case 'in_progress': return Icons.engineering_rounded;
      case 'closed': return Icons.cancel_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (_) {
      return dateStr;
    }
  }

  List<dynamic> _getFilteredTickets() {
    if (_filterIndex == 0) return _tickets;
    final statusMap = {
      1: 'open',
      2: 'in_progress',
      3: 'resolved',
    };
    final status = statusMap[_filterIndex];
    return _tickets.where((t) => (t['status'] ?? 'open') == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTickets = _getFilteredTickets();

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
              child: filteredTickets.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredTickets.length,
                  itemBuilder: (_, i) {
                    final t = filteredTickets[i];
                    return _buildGlassTicketCard(t);
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
                  Icons.support_agent_rounded,
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
                'Help & Support',
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
    String message = 'No tickets';
    String subMessage = 'Tap + to create a new support ticket';

    switch (_filterIndex) {
      case 1:
        message = 'No open tickets';
        subMessage = 'All tickets are in progress or resolved';
        break;
      case 2:
        message = 'No tickets in progress';
        subMessage = 'No tickets are currently being worked on';
        break;
      case 3:
        message = 'No resolved tickets';
        subMessage = 'No tickets have been resolved yet';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.support_agent_rounded,
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

  // ==================== GLASS TICKET CARD ====================
  Widget _buildGlassTicketCard(Map<String, dynamic> t) {
    final status = t['status'] ?? 'open';
    final priority = t['priority'] ?? 'medium';
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final statusIcon = _statusIcon(status);
    final priorityColor = _priorityColor(priority);
    final priorityLabel = _priorityLabel(priority);
    final priorityIcon = _priorityIcon(priority);

    return GestureDetector(
      onTap: () => _showTicketDetail(t),
      child: Container(
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
                          t['subject'] ?? 'Untitled',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E3A5F),
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
                              priorityIcon,
                              size: 10,
                              color: priorityColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              priorityLabel.toUpperCase(),
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
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(t['created_at'] ?? ''),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                              statusLabel.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (t['message'] != null && t['message'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      t['message'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.08),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF1E3A5F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TICKET DETAIL BOTTOM SHEET ====================
  void _showTicketDetail(Map<String, dynamic> t) {
    HapticFeedback.lightImpact();
    final status = t['status'] ?? 'open';
    final priority = t['priority'] ?? 'medium';
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final statusIcon = _statusIcon(status);
    final priorityColor = _priorityColor(priority);
    final priorityLabel = _priorityLabel(priority);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [priorityColor, priorityColor.withOpacity(0.7)],
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      boxShadow: [
                        BoxShadow(
                          color: priorityColor.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['subject'] ?? 'Ticket',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF1E3A5F),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.1),
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                              ),
                              child: Text(
                                priorityLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: priorityColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                              ),
                              child: Row(
                                children: [
                                  Icon(statusIcon, size: 12, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Message Body
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['message'] ?? 'No message content',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Footer Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Created: ${_formatDate(t['created_at'] ?? '')}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            if (t['created_at'] != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    t['created_at'],
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== SHOW FORM ====================
  void _showForm() {
    _subjectCtrl.clear();
    _messageCtrl.clear();
    _priority = 'medium';

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
                        'New Support Ticket',
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
                  _buildFormField(
                    controller: _subjectCtrl,
                    label: 'Subject',
                    icon: Icons.title_rounded,
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _messageCtrl,
                    label: 'Message',
                    icon: Icons.message_rounded,
                    maxLines: 4,
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  _buildFormDropdown(
                    value: _priority,
                    items: ['low', 'medium', 'high', 'urgent'],
                    label: 'Priority',
                    onChanged: (v) => setLocalState(() => _priority = v!),
                    getLabel: (s) => s.toUpperCase(),
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
                      'Submit Ticket',
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