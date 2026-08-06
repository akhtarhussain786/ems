import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _documents = [];
  bool _loading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _uploading = false;
  int _filterIndex = 0;

  // Selected document type for title
  String _selectedDocumentTitle = 'My Documents';
  String _selectedDocumentIcon = '📄';

  final List<String> _filterLabels = ['All', 'ID Proof', 'Certificate', 'HR', 'Other'];

  final List<Map<String, dynamic>> _documentCategories = [
    {
      'value': 'pan_card',
      'label': 'PAN Card',
      'icon': Icons.credit_card_rounded,
      'emoji': '🪪',
      'color': Color(0xFFFF6B35),
      'category': 'id_proof',
      'description': 'Permanent Account Number',
    },
    {
      'value': 'aadhar_card',
      'label': 'Aadhar Card',
      'icon': Icons.assignment_ind_rounded,
      'emoji': '🪪',
      'color': Color(0xFF2196F3),
      'category': 'id_proof',
      'description': '12-digit Unique Identity',
    },
    {
      'value': 'bank_passbook',
      'label': 'Bank Passbook',
      'icon': Icons.account_balance_rounded,
      'emoji': '🏦',
      'color': Color(0xFF4CAF50),
      'category': 'id_proof',
      'description': 'Bank Account Details',
    },
    {
      'value': 'certificate',
      'label': 'Certificate',
      'icon': Icons.verified_rounded,
      'emoji': '📜',
      'color': Color(0xFF9C27B0),
      'category': 'certificate',
      'description': 'Educational/Professional',
    },
    {
      'value': 'hr_document',
      'label': 'HR Document',
      'icon': Icons.work_outline_rounded,
      'emoji': '📋',
      'color': Color(0xFFFF9800),
      'category': 'hr',
      'description': 'HR Related Documents',
    },
    {
      'value': 'other',
      'label': 'Other',
      'icon': Icons.description_rounded,
      'emoji': '📄',
      'color': Color(0xFF9E9E9E),
      'category': 'other',
      'description': 'Other Documents',
    },
  ];

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
    _fetchDocuments();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchDocuments() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('documents/my');
      if (mounted && res['success'] == true) {
        setState(() => _documents = res['data'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _uploadDocument() async {
    HapticFeedback.mediumImpact();

    final selectedDocType = await _showDocumentTypeDialog();
    if (selectedDocType == null) return;

    // Update title with selected document type
    setState(() {
      _selectedDocumentTitle = selectedDocType['label'];
      _selectedDocumentIcon = selectedDocType['emoji'];
    });

    final picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (photo == null) {
      // Reset title if upload cancelled
      setState(() {
        _selectedDocumentTitle = 'My Documents';
        _selectedDocumentIcon = '📄';
      });
      return;
    }

    setState(() => _uploading = true);

    try {
      final res = await ApiService().postMultipart(
          'documents/upload',
          {
            'category': selectedDocType['category'],
            'document_type': selectedDocType['value'],
            'document_label': selectedDocType['label'],
          },
          File(photo.path)
      );

      if (mounted && res['success'] == true) {
        _fetchDocuments();
        _showSnackBar('✅ ${selectedDocType['label']} uploaded successfully', Colors.green);
        // Reset title after successful upload
        setState(() {
          _selectedDocumentTitle = 'My Documents';
          _selectedDocumentIcon = '📄';
        });
      } else {
        _showSnackBar(res['message'] ?? '❌ Failed to upload document', Colors.red);
        // Reset title on error
        setState(() {
          _selectedDocumentTitle = 'My Documents';
          _selectedDocumentIcon = '📄';
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('❌ Error: ${e.toString()}', Colors.red);
        setState(() {
          _selectedDocumentTitle = 'My Documents';
          _selectedDocumentIcon = '📄';
        });
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showDocumentTypeDialog() async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
            maxWidth: 400,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Choose Document Type',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.upload_file_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Document type grid
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _documentCategories.length,
                    itemBuilder: (context, index) {
                      final doc = _documentCategories[index];
                      final color = doc['color'] as Color;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context, doc),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: color.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [color, color.withOpacity(0.7)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    doc['icon'] as IconData,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doc['label'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  doc['description'] as String,
                                  style: TextStyle(
                                    fontSize: 7,
                                    color: Colors.grey[500],
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (doc['category'] as String).toUpperCase().replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 6,
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Cancel button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    minimumSize: const Size(double.infinity, 36),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Get document label from document type value
  String _getDocumentLabelFromType(String documentType) {
    final doc = _documentCategories.firstWhere(
          (d) => d['value'] == documentType,
      orElse: () => _documentCategories.last,
    );
    return doc['label'] as String;
  }

  IconData _getDocumentIcon(String documentType) {
    final doc = _documentCategories.firstWhere(
          (d) => d['value'] == documentType,
      orElse: () => _documentCategories.last,
    );
    return doc['icon'] as IconData;
  }

  Color _getDocumentColor(String documentType) {
    final doc = _documentCategories.firstWhere(
          (d) => d['value'] == documentType,
      orElse: () => _documentCategories.last,
    );
    return doc['color'] as Color;
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'id_proof':
        return 'ID Proof';
      case 'certificate':
        return 'Certificate';
      case 'hr':
        return 'HR';
      default:
        return 'Other';
    }
  }

  List<dynamic> _getFilteredDocuments() {
    if (_filterIndex == 0) return _documents;
    final categoryMap = {
      1: 'id_proof',
      2: 'certificate',
      3: 'hr',
      4: 'other',
    };
    final category = categoryMap[_filterIndex];
    return _documents.where((d) => (d['category'] ?? 'other') == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocuments = _getFilteredDocuments();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(),
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
              onRefresh: _fetchDocuments,
              color: const Color(0xFF1E3A5F),
              child: filteredDocuments.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredDocuments.length,
                  itemBuilder: (_, i) {
                    final d = filteredDocuments[i];
                    return _buildDocumentCard(d);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 65,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: IconButton(
          onPressed: () {
            setState(() {
              _selectedDocumentTitle = 'My Documents';
              _selectedDocumentIcon = '📄';
            });
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Image.asset(
              'assets/images/logo25.png',
              height: 26,
              width: 26,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.folder_rounded,
                  color: Colors.white,
                  size: 20,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      _selectedDocumentIcon,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _selectedDocumentTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_documents.length} documents • ${_getFilteredDocuments().length} shown',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_selectedDocumentTitle != 'My Documents')
          Container(
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _selectedDocumentTitle = 'My Documents';
                  _selectedDocumentIcon = '📄';
                });
                HapticFeedback.lightImpact();
              },
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetchDocuments();
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 18,
            ),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ),
        const SizedBox(width: 4),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _uploading ? null : _uploadDocument,
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation: 8,
      shape: const CircleBorder(),
      child: _uploading
          ? const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.white,
        ),
      )
          : const Icon(Icons.add_rounded, size: 28),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: List.generate(_filterLabels.length, (index) {
          final isSelected = _filterIndex == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: FilterChip(
              label: Text(
                _filterLabels[index],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1E3A5F),
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(18)),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey[300]!,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              onSelected: (_) {
                setState(() => _filterIndex = index);
                HapticFeedback.lightImpact();
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No documents found';
    String subMessage = 'Tap the + button to upload your first document';
    IconData icon = Icons.folder_open_rounded;

    switch (_filterIndex) {
      case 1:
        message = 'No ID Proof documents';
        subMessage = 'Upload ID Proof like PAN, Aadhar, or Bank Passbook';
        icon = Icons.assignment_ind_rounded;
        break;
      case 2:
        message = 'No Certificates';
        subMessage = 'Upload your certificates here';
        icon = Icons.verified_rounded;
        break;
      case 3:
        message = 'No HR documents';
        subMessage = 'Upload HR documents here';
        icon = Icons.work_outline_rounded;
        break;
      case 4:
        message = 'No other documents';
        subMessage = 'Upload other documents here';
        icon = Icons.description_rounded;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subMessage,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            if (_filterIndex == 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: _uploadDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: const Text('Upload Document', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> d) {
    // Get document type from the data - use document_type field
    final documentType = d['document_type'] ?? 'other';

    // Get the proper label from document type
    final label = _getDocumentLabelFromType(documentType);
    final icon = _getDocumentIcon(documentType);
    final color = _getDocumentColor(documentType);
    final categoryLabel = _getCategoryLabel(d['category'] ?? 'other');
    final filename = d['filename'] ?? 'Document';
    final uploadedAt = d['uploaded_at'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showSnackBar('📄 Viewing $label', Colors.blue);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Document icon with proper color
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),

                // Document details - SHOWING PROPER LABEL
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label, // This will show "Aadhar Card", "PAN Card", etc.
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFF1E3A5F),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              categoryLabel,
                              style: TextStyle(
                                color: color,
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        filename,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 9,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatDate(uploadedAt),
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${d['size'] ?? 0} KB',
                              style: TextStyle(
                                fontSize: 7,
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Download button
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (_) {
      return dateStr;
    }
  }
}