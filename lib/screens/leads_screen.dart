import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _leads = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _statusFilter = '';
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _campaignCtrl = TextEditingController();
  final _requirementCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _source = 'Website';
  String _priority = 'Medium';
  int? _editId;
  int? _selectedTelecaller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _sources = ['Facebook', 'Google', 'Instagram', 'Website', 'WhatsApp', 'Referral', 'Manual', 'Other'];
  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];

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
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    _cityCtrl.dispose();
    _campaignCtrl.dispose();
    _requirementCtrl.dispose();
    _budgetCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().post('leads/list', {'status': _statusFilter});
      if (mounted && res['success'] == true) setState(() => _leads = res['data'] ?? []);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _search(String q) async {
    if (q.length < 2) { _fetch(); return; }
    setState(() => _loading = true);
    try {
      final res = await ApiService().searchLeads({'query': q});
      if (mounted && res['success'] == true) setState(() => _leads = res['data'] ?? []);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _resetForm() {
    _editId = null;
    _selectedTelecaller = null;
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _companyCtrl.clear();
    _cityCtrl.clear();
    _campaignCtrl.clear();
    _requirementCtrl.clear();
    _budgetCtrl.clear();
    _notesCtrl.clear();
    _source = 'Website';
    _priority = 'Medium';
  }

  void _editLead(Map<String, dynamic> l) async {
    _editId = l['id'];
    _nameCtrl.text = l['customer_name'] ?? '';
    _phoneCtrl.text = l['phone'] ?? l['customer_phone'] ?? '';
    _emailCtrl.text = l['email'] ?? l['customer_email'] ?? '';
    _companyCtrl.text = l['company_name'] ?? '';
    _cityCtrl.text = l['city'] ?? '';
    _campaignCtrl.text = l['campaign_name'] ?? '';
    _requirementCtrl.text = l['requirement'] ?? '';
    _budgetCtrl.text = l['budget']?.toString() ?? '';
    _notesCtrl.text = l['notes'] ?? '';
    _source = l['source'] ?? l['lead_source'] ?? 'Website';
    _priority = l['priority'] ?? 'Medium';
    _selectedTelecaller = l['assigned_to'];
    _showForm();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final data = {
        'customer_name': _nameCtrl.text,
        'phone': _phoneCtrl.text,
        'email': _emailCtrl.text,
        'company_name': _companyCtrl.text,
        'city': _cityCtrl.text,
        'source': _source,
        'campaign_name': _campaignCtrl.text,
        'requirement': _requirementCtrl.text,
        'budget': double.tryParse(_budgetCtrl.text),
        'priority': _priority,
        'notes': _notesCtrl.text,
        if (_selectedTelecaller != null) 'assigned_to': _selectedTelecaller,
      };

      final res = _editId != null
          ? await ApiService().updateLead({'id': _editId, ...data})
          : await ApiService().createLead(data);

      if (mounted) {
        Navigator.pop(context);
        if (res['success'] == true) {
          _fetch();
          _showMsg(_editId != null ? '✅ Lead updated successfully' : '✅ Lead created successfully');
        } else {
          _showMsg(res['message'] ?? '❌ Failed');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showMsg('❌ Error: ${e.toString().substring(0, 100)}');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: msg.contains('Error') || msg.contains('Failed') ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _deleteLead(int id) async {
    HapticFeedback.mediumImpact();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Lead'),
          ],
        ),
        content: const Text('Are you sure you want to delete this lead?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService().deleteLead({'id': id});
    if (mounted && res['success'] == true) {
      _fetch();
      _showMsg('✅ Lead deleted successfully');
    }
  }

  void _showHistory(Map<String, dynamic> lead) async {
    HapticFeedback.lightImpact();
    final res = await ApiService().getLeadHistory({'lead_id': lead['id']});
    if (!mounted) return;
    final data = res['success'] == true ? res['data'] : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, s) => Padding(
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
                      Icons.history_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Lead History',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(),
              if (data != null) ...[
                _buildHistorySection('Calls', data['calls'] as List? ?? [], Icons.phone_rounded, Colors.blue),
                const SizedBox(height: 8),
                _buildHistorySection('Follow-ups', data['follow_ups'] as List? ?? [], Icons.event_note_rounded, Colors.deepPurple),
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text(
                      'No history available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(String title, List items, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                '$title (${items.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        items.isEmpty
            ? Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No $title',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        )
            : ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length > 5 ? 5 : items.length,
          separatorBuilder: (_, __) => const Divider(height: 4),
          itemBuilder: (_, i) {
            final item = items[i];
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              title: Text(
                title == 'Calls'
                    ? (item['call_status'] ?? item['status'] ?? '')
                    : (item['follow_up_date'] ?? ''),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              subtitle: Text(
                item['notes'] ?? '',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
        if (items.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+${items.length - 5} more...',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'won':
        return Colors.green;
      case 'lost':
      case 'not_interested':
      case 'wrong_number':
        return Colors.red;
      case 'duplicate':
        return Colors.grey;
      case 'qualified':
        return Colors.teal;
      case 'interested':
        return Colors.blue;
      case 'follow_up':
        return Colors.deepPurple;
      case 'new':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
            _buildSearchBar(),
            _buildFilterChips(),
            Expanded(
              child: _loading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1E3A5F),
                  strokeWidth: 3,
                ),
              )
                  : _leads.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                onRefresh: _fetch,
                color: const Color(0xFF1E3A5F),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _leads.length,
                    itemBuilder: (_, i) {
                      final l = _leads[i];
                      final name = l['customer_name'] ?? '';
                      final phone = l['phone'] ?? l['customer_phone'] ?? 'N/A';
                      final status = l['status'] ?? 'new';
                      final statusColor = _statusColor(status);
  
                      return _buildGlassLeadCard(l, name, phone, status, statusColor);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
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
                  Icons.people_rounded,
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
                'Leads Management',
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
            borderRadius: BorderRadius.circular(14),
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

  // ==================== SEARCH BAR ====================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
          decoration: InputDecoration(
            hintText: 'Search leads...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear_rounded, color: Colors.grey[400]),
              onPressed: () {
                _searchCtrl.clear();
                _fetch();
              },
            )
                : null,
          ),
          onChanged: (v) => _search(v),
        ),
      ),
    );
  }

  // ==================== FILTER CHIPS ====================
  Widget _buildFilterChips() {
    final filters = [
      {'label': 'All', 'value': ''},
      {'label': 'New', 'value': 'new'},
      {'label': 'Follow-up', 'value': 'follow_up'},
      {'label': 'Interested', 'value': 'interested'},
      {'label': 'Qualified', 'value': 'qualified'},
      {'label': 'Won', 'value': 'won'},
      {'label': 'Lost', 'value': 'lost'},
    ];

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: filters.map((f) {
          final active = _statusFilter == f['value'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(
                f['label']!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active ? Colors.white : Colors.grey[700],
                ),
              ),
              selected: active,
              selectedColor: const Color(0xFF1E3A5F),
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: active ? const Color(0xFF1E3A5F) : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              onSelected: (_) {
                setState(() => _statusFilter = f['value']!);
                _fetch();
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==================== GLASS LEAD CARD ====================
  Widget _buildGlassLeadCard(Map<String, dynamic> l, String name, String phone, String status, Color statusColor) {
    return GestureDetector(
      onTap: () => _showHistory(l),
      onLongPress: () => _showOptions(l),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
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
                    fontSize: 18,
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
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E3A5F),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (l['city'] != null && l['city']!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l['city'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (l['source'] != null && l['source']!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l['source'],
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
            Icons.people_outline_rounded,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            'No leads found',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusFilter.isEmpty ? 'Tap + to add a new lead' : 'Try changing the filter',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== FLOATING ACTION BUTTON ====================
  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () {
        HapticFeedback.mediumImpact();
        _resetForm();
        _showForm();
      },
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }

  // ==================== OPTIONS BOTTOM SHEET ====================
  void _showOptions(Map<String, dynamic> l) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
            top: 8, bottom: 8 + MediaQuery.of(ctx).viewPadding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded, color: Colors.blue),
              ),
              title: const Text('Edit Lead'),
              onTap: () {
                Navigator.pop(context);
                _editLead(l);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded, color: Colors.deepPurple),
              ),
              title: const Text('View History'),
              onTap: () {
                Navigator.pop(context);
                _showHistory(l);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.red),
              ),
              title: const Text('Delete Lead', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteLead(l['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FORM BOTTOM SHEET ====================
  void _showForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            top: 16,
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _editId != null ? Icons.edit_rounded : Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _editId != null ? 'Edit Lead' : 'New Lead',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: _nameCtrl,
                    label: 'Customer Name',
                    icon: Icons.person_rounded,
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _phoneCtrl,
                    label: 'Phone',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          controller: _emailCtrl,
                          label: 'Email',
                          icon: Icons.email_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFormField(
                          controller: _companyCtrl,
                          label: 'Company',
                          icon: Icons.business_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          controller: _cityCtrl,
                          label: 'City',
                          icon: Icons.location_city_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFormDropdown(
                          value: _source,
                          items: _sources,
                          label: 'Source',
                          onChanged: (v) => setLocalState(() => _source = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField(
                          controller: _campaignCtrl,
                          label: 'Campaign',
                          icon: Icons.campaign_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFormField(
                          controller: _budgetCtrl,
                          label: 'Budget',
                          icon: Icons.currency_rupee_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _requirementCtrl,
                    label: 'Requirement',
                    icon: Icons.description_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormDropdown(
                          value: _priority,
                          items: _priorities,
                          label: 'Priority',
                          onChanged: (v) => setLocalState(() => _priority = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _notesCtrl,
                    label: 'Notes',
                    icon: Icons.note_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                        : Text(
                      _editId != null ? 'Update Lead' : 'Create Lead',
                      style: const TextStyle(
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
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((s) => DropdownMenuItem(
        value: s,
        child: Text(
          s,
          overflow: TextOverflow.ellipsis,
        ),
      )).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}