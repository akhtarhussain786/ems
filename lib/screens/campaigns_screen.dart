import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _campaigns = [];
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _platformCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _resultsCtrl = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _submitting = false;
  int _filterIndex = 0; // 0: All, 1: Active, 2: Planning, 3: Completed

  final List<String> _filterLabels = ['All', 'Active', 'Planning', 'Completed'];

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
    _nameCtrl.dispose();
    _platformCtrl.dispose();
    _budgetCtrl.dispose();
    _resultsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getMyCampaigns();
      if (mounted && res['success'] == true) {
        setState(() => _campaigns = res['data'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final res = await ApiService().createCampaign({
        'campaign_name': _nameCtrl.text,
        'platform': _platformCtrl.text,
        'budget': double.tryParse(_budgetCtrl.text) ?? 0,
        'results': double.tryParse(_resultsCtrl.text) ?? 0,
      });

      if (mounted) {
        Navigator.pop(context);
        if (res['success'] == true) {
          _fetch();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Campaign created successfully'),
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
              content: Text(res['message'] ?? '❌ Failed to create campaign'),
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

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return Colors.green;
      case 'planning':
        return Colors.blue;
      case 'paused':
        return Colors.orange;
      case 'completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'active':
        return Icons.play_circle_rounded;
      case 'planning':
        return Icons.edit_calendar_rounded;
      case 'paused':
        return Icons.pause_circle_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.circle_rounded;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'Active';
      case 'planning':
        return 'Planning';
      case 'paused':
        return 'Paused';
      case 'completed':
        return 'Completed';
      default:
        return s;
    }
  }

  List<dynamic> _getFilteredCampaigns() {
    if (_filterIndex == 0) return _campaigns;
    final statusMap = {
      1: 'active',
      2: 'planning',
      3: 'completed',
    };
    final status = statusMap[_filterIndex];
    return _campaigns.where((c) => (c['status'] ?? '') == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCampaigns = _getFilteredCampaigns();

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
              child: filteredCampaigns.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredCampaigns.length,
                  itemBuilder: (_, i) {
                    final c = filteredCampaigns[i];
                    return _buildGlassCampaignCard(c);
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
                  Icons.campaign_rounded,
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
                'Campaigns',
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
    String message = 'No campaigns';
    String subMessage = 'Tap + to create your first campaign';

    switch (_filterIndex) {
      case 1:
        message = 'No active campaigns';
        subMessage = 'All campaigns are planning or completed';
        break;
      case 2:
        message = 'No campaigns in planning';
        subMessage = 'All campaigns are active or completed';
        break;
      case 3:
        message = 'No completed campaigns';
        subMessage = 'Complete campaigns to see them here';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_rounded,
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

  // ==================== GLASS CAMPAIGN CARD ====================
  Widget _buildGlassCampaignCard(Map<String, dynamic> c) {
    final status = c['status'] ?? 'planning';
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);
    final statusLabel = _statusLabel(status);
    final budget = c['budget'] ?? 0;
    final results = c['results'] ?? 0;
    final progress = budget > 0 ? (results / budget * 100).clamp(0, 100) : 0;

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
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['campaign_name'] ?? 'Untitled',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1E3A5F),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.devices_rounded,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          c['platform'] ?? 'N/A',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.currency_rupee_rounded,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '₹${budget.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Row(
                  children: [
                    Icon(
                      statusIcon,
                      color: statusColor,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (results > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${progress.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.grey[200],
                          color: statusColor,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        results.toStringAsFixed(0),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      Text(
                        'Results',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ==================== SHOW FORM ====================
  void _showForm() {
    _nameCtrl.clear();
    _platformCtrl.clear();
    _budgetCtrl.clear();
    _resultsCtrl.clear();

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
                        'New Campaign',
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
                    controller: _nameCtrl,
                    label: 'Campaign Name',
                    icon: Icons.title_rounded,
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _platformCtrl,
                    label: 'Platform',
                    icon: Icons.devices_rounded,
                    hintText: 'e.g., Facebook, Google, Instagram',
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _budgetCtrl,
                    label: 'Budget',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                    hintText: 'Enter budget amount',
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _resultsCtrl,
                    label: 'Results (Optional)',
                    icon: Icons.analytics_rounded,
                    keyboardType: TextInputType.number,
                    hintText: 'Enter results amount',
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
                      'Save Campaign',
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
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hintText,
        labelStyle: TextStyle(color: Colors.grey[600]),
        hintStyle: TextStyle(color: Colors.grey[400]),
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
}