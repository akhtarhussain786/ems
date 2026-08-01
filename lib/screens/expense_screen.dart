import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _expenses = [];
  bool _loading = true;
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'travel';
  String _expenseDate = DateTime.now().toIso8601String().split('T')[0];
  File? _billPhoto;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _submitting = false;
  int _filterIndex = 0; // 0: All, 1: Pending, 2: Approved, 3: Rejected

  final List<String> _filterLabels = ['All', 'Pending', 'Approved', 'Rejected'];
  final List<String> _categories = ['travel', 'food', 'stationery', 'fuel', 'accommodation', 'other'];

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
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('expenses/my');
      if (mounted && res['success'] == true) {
        setState(() => _expenses = res['data'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final fields = {
        'category': _category,
        'amount': _amountCtrl.text,
        'expense_date': _expenseDate,
        'description': _descCtrl.text,
      };
      final res = await ApiService().postMultipart('expenses/create', fields, _billPhoto, fileField: 'bill_photo');

      if (mounted) {
        Navigator.pop(context);
        if (res['success'] == true) {
          _fetch();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Expense submitted successfully'),
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
              content: Text(res['message'] ?? '❌ Failed to submit expense'),
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

  Future<void> _pickPhoto() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (photo != null) setState(() => _billPhoto = File(photo.path));
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'submitted':
        return 'Submitted';
      default:
        return 'Pending';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'submitted':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'submitted':
        return Icons.send_rounded;
      default:
        return Icons.pending_rounded;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'fuel':
        return Icons.local_gas_station_rounded;
      case 'accommodation':
        return Icons.hotel_rounded;
      case 'stationery':
        return Icons.edit_rounded;
      case 'other':
        return Icons.receipt_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'travel':
        return Colors.blue;
      case 'food':
        return Colors.orange;
      case 'fuel':
        return Colors.red;
      case 'accommodation':
        return Colors.deepPurple;
      case 'stationery':
        return Colors.teal;
      case 'other':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'travel':
        return 'Travel';
      case 'food':
        return 'Food';
      case 'fuel':
        return 'Fuel';
      case 'accommodation':
        return 'Accommodation';
      case 'stationery':
        return 'Stationery';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  List<dynamic> _getFilteredExpenses() {
    if (_filterIndex == 0) return _expenses;
    final statusMap = {
      1: 'pending',
      2: 'approved',
      3: 'rejected',
    };
    final status = statusMap[_filterIndex];
    return _expenses.where((e) => (e['status'] ?? 'pending') == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = _getFilteredExpenses();

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
              child: filteredExpenses.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredExpenses.length,
                  itemBuilder: (_, i) {
                    final e = filteredExpenses[i];
                    return _buildGlassExpenseCard(e);
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
                  Icons.receipt_rounded,
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
                'Expenses',
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
    String message = 'No expenses';
    String subMessage = 'Tap + to add a new expense';

    switch (_filterIndex) {
      case 1:
        message = 'No pending expenses';
        subMessage = 'All expenses are approved or rejected';
        break;
      case 2:
        message = 'No approved expenses';
        subMessage = 'No expenses have been approved yet';
        break;
      case 3:
        message = 'No rejected expenses';
        subMessage = 'No expenses have been rejected';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_rounded,
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

  // ==================== GLASS EXPENSE CARD ====================
  Widget _buildGlassExpenseCard(Map<String, dynamic> e) {
    final category = e['category'] ?? 'other';
    final categoryIcon = _categoryIcon(category);
    final categoryColor = _categoryColor(category);
    final categoryLabel = _categoryLabel(category);
    final status = e['status'] ?? 'pending';
    final statusLabel = _statusLabel(status);
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);
    final amount = e['amount'] ?? 0;
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

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
              color: categoryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: categoryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Icon(
              categoryIcon,
              color: categoryColor,
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
                        categoryLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isApproved || isRejected ? Colors.grey[500] : const Color(0xFF1E3A5F),
                          decoration: isRejected ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
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
                      e['expense_date'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 11,
                        color: isApproved || isRejected ? Colors.grey[400] : Colors.grey[500],
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
                if (e['description'] != null && e['description'].toString().isNotEmpty) ...[
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
                      e['description'],
                      style: TextStyle(
                        fontSize: 11,
                        color: isApproved || isRejected ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (e['bill_photo'] != null && e['bill_photo'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.attach_file_rounded,
                          size: 12,
                          color: Colors.blue.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bill attached',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SHOW FORM ====================
  void _showForm() {
    _amountCtrl.clear();
    _descCtrl.clear();
    _billPhoto = null;
    _category = 'travel';
    _expenseDate = DateTime.now().toIso8601String().split('T')[0];

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
                        'Add Expense',
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
                    value: _category,
                    items: _categories,
                    label: 'Category',
                    onChanged: (v) => setLocalState(() => _category = v!),
                    getLabel: (s) => _categoryLabel(s),
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _amountCtrl,
                    label: 'Amount',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                    required: true,
                  ),
                  const SizedBox(height: 10),
                  _buildFormField(
                    controller: _descCtrl,
                    label: 'Description',
                    icon: Icons.description_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  _buildDateField(
                    label: 'Expense Date',
                    date: _expenseDate,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 7)),
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
                      if (d != null) {
                        setLocalState(() {
                          _expenseDate = d.toIso8601String().split('T')[0];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _billPhoto != null ? Colors.green.shade50 : Colors.grey.shade50,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(
                          color: _billPhoto != null ? Colors.green.shade200 : Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_rounded,
                            color: _billPhoto != null ? Colors.green : Colors.grey[500],
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _billPhoto != null
                                  ? '📄 Bill photo captured: ${_billPhoto!.path.split('/').last}'
                                  : 'Tap to capture bill photo',
                              style: TextStyle(
                                color: _billPhoto != null ? Colors.green.shade700 : Colors.grey[600],
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_billPhoto != null)
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey[400]),
                              onPressed: () => setLocalState(() => _billPhoto = null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
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
                      'Submit Expense',
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
        child: Text(getLabel?.call(s) ?? s.toUpperCase()),
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

  // ==================== DATE FIELD ====================
  Widget _buildDateField({
    required String label,
    required String date,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[600]),
        suffixIcon: const Icon(
          Icons.calendar_today_rounded,
          color: Color(0xFF1E3A5F),
          size: 18,
        ),
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
      controller: TextEditingController(text: date),
      onTap: onTap,
    );
  }
}