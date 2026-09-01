import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ==================== TAB 1: EXCEL & PDF REPORTS STATE ====================
  String _selectedReportType = 'leads'; // 'leads', 'attendance', 'call_reports', 'work_reports', 'salary', 'expenses', 'travel', 'campaigns'
  String _activePreset = 'this_month';
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  String _statusFilter = '';
  bool _fetchingReport = false;
  bool _exporting = false;
  bool _exportingPdf = false;
  List<dynamic> _reportHeaders = [];
  List<dynamic> _reportRows = [];
  int _totalCount = 0;
  String? _lastSavedFilePath;
  String? _lastSavedFileType; // 'excel' or 'pdf'
  bool _hasFetched = false;

  // ==================== TAB 2: COMPANY FILES STATE ====================
  List<dynamic> _files = [];
  bool _loadingFiles = true;
  int _fileFilterIndex = 0; // 0: All, 1: Forms, 2: Policies, 3: Templates, 4: Reports
  final List<String> _fileFilterLabels = ['All', 'Forms', 'Policies', 'Templates', 'Reports'];

  final List<Map<String, dynamic>> _reportTypes = [
    {
      'id': 'leads',
      'title': 'Leads Report',
      'subtitle': 'Customer details, status, source & budget',
      'icon': Icons.group_add_rounded,
      'color': Color(0xFF1E88E5),
    },
    {
      'id': 'attendance',
      'title': 'Attendance Report',
      'subtitle': 'Punch in/out, working hours, late & status',
      'icon': Icons.timer_rounded,
      'color': Color(0xFF00897B),
    },
    {
      'id': 'call_reports',
      'title': 'Call Reports',
      'subtitle': 'Telecaller logs, call status & follow-ups',
      'icon': Icons.phone_in_talk_rounded,
      'color': Color(0xFF5E35B1),
    },
    {
      'id': 'work_reports',
      'title': 'Daily Work Report',
      'subtitle': 'Employee daily tasks, hours & remarks',
      'icon': Icons.article_rounded,
      'color': Color(0xFF3949AB),
    },
    {
      'id': 'salary',
      'title': 'Salary & Deductions',
      'subtitle': 'Base pay, present days, deductions & net',
      'icon': Icons.payments_rounded,
      'color': Color(0xFF43A047),
    },
    {
      'id': 'expenses',
      'title': 'Expenses Report',
      'subtitle': 'Claim amounts, categories, dates & approval',
      'icon': Icons.receipt_long_rounded,
      'color': Color(0xFFFB8C00),
    },
    {
      'id': 'travel',
      'title': 'Travel Requests',
      'subtitle': 'Kilometres, start/end location & allowance',
      'icon': Icons.directions_car_rounded,
      'color': Color(0xFF00ACC1),
    },
    {
      'id': 'campaigns',
      'title': 'Marketing Campaigns',
      'subtitle': 'Budget, spent, platform & leads generated',
      'icon': Icons.campaign_rounded,
      'color': Color(0xFFD81B60),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fetchFiles();
    _fetchReportData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ==================== FETCH REPORT DATA ====================
  Future<void> _fetchReportData() async {
    setState(() {
      _fetchingReport = true;
      _hasFetched = true;
    });

    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_dateRange.start);
      final endStr = DateFormat('yyyy-MM-dd').format(_dateRange.end);

      final reqData = {
        'report_type': _selectedReportType,
        'start_date': startStr,
        'end_date': endStr,
        if (_statusFilter.isNotEmpty) 'status': _statusFilter,
      };

      final res = await ApiService().exportReportData(reqData);
      if (mounted && res['success'] == true) {
        setState(() {
          _reportHeaders = res['headers'] ?? [];
          _reportRows = res['rows'] ?? [];
          _totalCount = res['total_count'] ?? _reportRows.length;
        });
      } else {
        if (mounted) {
          setState(() {
            _reportHeaders = [];
            _reportRows = [];
            _totalCount = 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching export report data: $e');
    } finally {
      if (mounted) setState(() => _fetchingReport = false);
    }
  }

  // ==================== EXCEL CSV GENERATION & DOWNLOAD ====================
  String _generateCsvContent(List<dynamic> headers, List<dynamic> rows) {
    final buffer = StringBuffer();
    // UTF-8 BOM so Excel recognizes characters properly
    buffer.write('\uFEFF');

    // Headers
    buffer.writeln(headers.map((h) => _escapeCsvCell(h.toString())).join(','));

    // Rows
    for (final row in rows) {
      if (row is List) {
        buffer.writeln(row.map((cell) => _escapeCsvCell(cell?.toString() ?? '')).join(','));
      }
    }

    return buffer.toString();
  }

  String _escapeCsvCell(String cell) {
    if (cell.contains(',') || cell.contains('"') || cell.contains('\n') || cell.contains('\r')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }

  Future<void> _downloadExcelReport() async {
    if (_reportRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records available for the selected dates. Change date range to export.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _exporting = true);

    try {
      final csvData = _generateCsvContent(_reportHeaders, _reportRows);
      final dir = await getApplicationDocumentsDirectory();
      final startStr = DateFormat('yyyy-MM-dd').format(_dateRange.start);
      final endStr = DateFormat('yyyy-MM-dd').format(_dateRange.end);
      final filename = '${_selectedReportType.toUpperCase()}_Report_${startStr}_to_${endStr}.csv';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csvData);

      if (mounted) {
        setState(() {
          _lastSavedFilePath = file.path;
          _lastSavedFileType = 'excel';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.table_chart_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ Excel file downloaded (${_reportRows.length} rows)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF107C41),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () {
                OpenFilex.open(file.path);
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );

        // Attempt to open the generated file in Excel / Sheets
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _downloadPdfReport() async {
    if (_reportRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No records available for the selected dates. Please adjust date range.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _exportingPdf = true);

    try {
      final doc = pw.Document();
      final startStr = DateFormat('dd MMM yyyy').format(_dateRange.start);
      final endStr = DateFormat('dd MMM yyyy').format(_dateRange.end);
      final genDateStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

      final activeReport = _reportTypes.firstWhere(
        (r) => r['id'] == _selectedReportType,
        orElse: () => _reportTypes.first,
      );

      final headersList = _reportHeaders.map((h) => h.toString()).toList();
      final rowsList = _reportRows.map((r) {
        if (r is List) {
          return r.map((c) => c?.toString() ?? '').toList();
        }
        return <String>[];
      }).toList();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF1E3A5F), width: 1.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'YATHARTH INSTITUTION & EMS',
                        style: pw.TextStyle(
                          color: const PdfColor.fromInt(0xFF1E3A5F),
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${activeReport['title']} • Date Range: $startStr - $endStr',
                        style: const pw.TextStyle(
                          color: PdfColors.grey700,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Records: ${_reportRows.length}',
                        style: pw.TextStyle(
                          color: const PdfColor.fromInt(0xFF1E3A5F),
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Generated: $genDateStr',
                        style: const pw.TextStyle(
                          color: PdfColors.grey600,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          footer: (pw.Context context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              padding: const pw.EdgeInsets.only(top: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Confidential • Generated by Yatharth EMS Mobile App',
                    style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                  ),
                ],
              ),
            );
          },
          build: (pw.Context context) {
            return [
              pw.TableHelper.fromTextArray(
                headers: headersList,
                data: rowsList,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1E3A5F),
                ),
                cellStyle: const pw.TextStyle(
                  color: PdfColors.black,
                  fontSize: 7,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                rowDecoration: const pw.BoxDecoration(
                  color: PdfColors.white,
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF7F9FC),
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
              ),
            ];
          },
        ),
      );

      final pdfBytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final sStr = DateFormat('yyyy-MM-dd').format(_dateRange.start);
      final eStr = DateFormat('yyyy-MM-dd').format(_dateRange.end);
      final filename = '${_selectedReportType.toUpperCase()}_Report_${sStr}_to_${eStr}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        setState(() {
          _lastSavedFilePath = file.path;
          _lastSavedFileType = 'pdf';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✅ PDF Report downloaded (${_reportRows.length} records)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () {
                OpenFilex.open(file.path);
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );

        // Automatically open the generated PDF
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  // ==================== DATE RANGE PICKERS ====================
  Future<void> _pickStartDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateRange.start,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'SELECT FROM / START DATE',
      confirmText: 'SET START DATE',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A5F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E3A5F),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      DateTime newEnd = _dateRange.end;
      if (newEnd.isBefore(picked)) {
        newEnd = picked;
      }
      setState(() {
        _activePreset = 'custom';
        _dateRange = DateTimeRange(start: picked, end: newEnd);
      });
      _fetchReportData();
    }
  }

  Future<void> _pickEndDate() async {
    HapticFeedback.selectionClick();
    final initial = _dateRange.end.isBefore(_dateRange.start) ? _dateRange.start : _dateRange.end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _dateRange.start,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'SELECT TO / END DATE',
      confirmText: 'SET END DATE',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A5F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E3A5F),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activePreset = 'custom';
        _dateRange = DateTimeRange(start: _dateRange.start, end: picked);
      });
      _fetchReportData();
    }
  }

  Future<void> _pickDateRange() async {
    HapticFeedback.selectionClick();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
      helpText: 'SELECT REPORT DATE RANGE',
      confirmText: 'APPLY DATES',
      saveText: 'SELECT',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A5F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E3A5F),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _activePreset = 'custom';
        _dateRange = picked;
      });
      _fetchReportData();
    }
  }

  void _setDatePreset(String preset) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day);

    switch (preset) {
      case 'today':
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day);
        break;
      case 'yesterday':
        final yest = now.subtract(const Duration(days: 1));
        start = DateTime(yest.year, yest.month, yest.day);
        end = DateTime(yest.year, yest.month, yest.day);
        break;
      case 'this_week':
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'this_month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'last_month':
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 0);
        break;
      case 'last_90':
        start = now.subtract(const Duration(days: 90));
        start = DateTime(start.year, start.month, start.day);
        break;
      default:
        start = now.subtract(const Duration(days: 30));
        start = DateTime(start.year, start.month, start.day);
    }

    setState(() {
      _activePreset = preset;
      _dateRange = DateTimeRange(start: start, end: end);
    });
    _fetchReportData();
  }

  // ==================== TAB 2: COMPANY FILES FETCH ====================
  Future<void> _fetchFiles() async {
    setState(() => _loadingFiles = true);
    try {
      final res = await ApiService().get('downloads');
      if (mounted && res['success'] == true) {
        setState(() => _files = res['data'] ?? []);
      }
    } catch (e) {
      debugPrint('download_screen: $e');
    }
    if (mounted) setState(() => _loadingFiles = false);
  }

  Future<void> _downloadCompanyFile(Map<String, dynamic> file) async {
    HapticFeedback.mediumImpact();
    final url = file['file_url'] ?? file['file_path'] ?? '';
    final filename = file['filename'] ?? file['title'] ?? 'document';

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File download link not available'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening file $filename...'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<dynamic> _getFilteredFiles() {
    if (_fileFilterIndex == 0) return _files;
    final categoryMap = {
      1: 'forms',
      2: 'policies',
      3: 'templates',
      4: 'reports',
    };
    final category = categoryMap[_fileFilterIndex];
    return _files.where((f) => (f['category'] ?? 'other') == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(),
      body: SafeArea(
        top: false,
        child: TabBarView(
          controller: _tabController,
          children: [
            // TAB 1: EXCEL REPORTS GENERATOR & DOWNLOAD
            _buildExcelReportsTab(),

            // TAB 2: COMPANY FILES & DOCUMENTS
            _buildCompanyFilesTab(),
          ],
        ),
      ),
    );
  }

  // ==================== APP BAR WITH TABS ====================
  PreferredSizeWidget _buildAppBar() {
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
                  Icons.file_download_rounded,
                  color: Colors.white,
                  size: 24,
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Reports & Downloads',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Excel Export & Document Center',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
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
              if (_tabController.index == 0) {
                _fetchReportData();
              } else {
                _fetchFiles();
              }
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
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.amberAccent,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(
            icon: Icon(Icons.description_rounded, size: 18),
            text: 'Excel & PDF Reports',
          ),
          Tab(
            icon: Icon(Icons.folder_shared_rounded, size: 18),
            text: 'Company Files',
          ),
        ],
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      centerTitle: false,
    );
  }

  // ==================== TAB 1: EXCEL REPORTS TAB ====================
  Widget _buildExcelReportsTab() {
    final activeReport = _reportTypes.firstWhere(
          (r) => r['id'] == _selectedReportType,
      orElse: () => _reportTypes.first,
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Report Type Selector Card
          _buildReportTypeSelectorCard(),
          const SizedBox(height: 16),

          // 2. Calendar Date Range Selector Card
          _buildDateRangeSelectorCard(),
          const SizedBox(height: 16),

          // 3. Action Buttons (Fetch & Download Excel)
          _buildActionButtonsCard(activeReport),
          const SizedBox(height: 16),

          // 4. Data Summary & Table Preview
          _buildPreviewAndDataSection(activeReport),
        ],
      ),
    );
  }

  // ==================== 1. REPORT TYPE SELECTOR CARD ====================
  Widget _buildReportTypeSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                child: const Icon(Icons.category_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Report Module',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  Text(
                    'Choose data module to export to Excel',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Horizontal scroll of report types
          SizedBox(
            height: 94,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _reportTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final r = _reportTypes[i];
                final isSelected = r['id'] == _selectedReportType;
                final color = r['color'] as Color;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedReportType = r['id'];
                      _reportHeaders = [];
                      _reportRows = [];
                    });
                    _fetchReportData();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 130,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E3A5F) : color.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1E3A5F) : color.withOpacity(0.25),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                        BoxShadow(
                          color: const Color(0xFF1E3A5F).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          r['icon'] as IconData,
                          size: 24,
                          color: isSelected ? Colors.white : color,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r['title'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF1E3A5F),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 2. DATE RANGE SELECTOR CARD ====================
  Widget _buildDateRangeSelectorCard() {
    final startStr = DateFormat('dd MMM yyyy').format(_dateRange.start);
    final endStr = DateFormat('dd MMM yyyy').format(_dateRange.end);
    final daysCount = _dateRange.end.difference(_dateRange.start).inDays + 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                child: const Icon(Icons.date_range_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Report Date Range',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    Text(
                      'Choose quick presets or tap From/To dates',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick Presets
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDatePresetChip('This Month', 'this_month'),
                const SizedBox(width: 6),
                _buildDatePresetChip('Today', 'today'),
                const SizedBox(width: 6),
                _buildDatePresetChip('Yesterday', 'yesterday'),
                const SizedBox(width: 6),
                _buildDatePresetChip('This Week', 'this_week'),
                const SizedBox(width: 6),
                _buildDatePresetChip('Last Month', 'last_month'),
                const SizedBox(width: 6),
                _buildDatePresetChip('Last 90 Days', 'last_90'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Dual Date Pickers (From Date & To Date)
          Row(
            children: [
              // FROM DATE
              Expanded(
                child: GestureDetector(
                  onTap: _pickStartDate,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF1E3A5F).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF1E3A5F)),
                            const SizedBox(width: 5),
                            Text(
                              'FROM DATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          startStr,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap to select',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ARROW & DURATION
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF1E3A5F), size: 16),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        daysCount == 1 ? '1 Day' : '$daysCount Days',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // TO DATE
              Expanded(
                child: GestureDetector(
                  onTap: _pickEndDate,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A5F).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF1E3A5F).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available_rounded, size: 13, color: Color(0xFF1E3A5F)),
                            const SizedBox(width: 5),
                            Text(
                              'TO DATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          endStr,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap to select',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Dedicated Full Range Calendar Button
          GestureDetector(
            onTap: _pickDateRange,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF1E3A5F).withOpacity(0.15),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.date_range_rounded, size: 15, color: Color(0xFF1E3A5F)),
                  SizedBox(width: 6),
                  Text(
                    'Or Open Full Calendar Date Range',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A5F),
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

  Widget _buildDatePresetChip(String label, String key) {
    final isSelected = _activePreset == key;

    return GestureDetector(
      onTap: () => _setDatePreset(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: const Color(0xFF1E3A5F).withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle_rounded, color: Colors.amberAccent, size: 13),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 3. ACTION BUTTONS CARD ====================
  Widget _buildActionButtonsCard(Map<String, dynamic> activeReport) {
    final hasData = _reportRows.isNotEmpty && !_fetchingReport;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Dual Download Buttons (Excel & PDF)
          Row(
            children: [
              // 1. Download Excel Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_exporting || _exportingPdf || !hasData)
                      ? null
                      : _downloadExcelReport,
                  icon: _exporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.table_chart_rounded, size: 18),
                  label: Text(
                    _exporting ? 'Exporting...' : 'Excel (.csv)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF107C41), // Excel Green
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Download PDF Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_exporting || _exportingPdf || !hasData)
                      ? null
                      : _downloadPdfReport,
                  icon: _exportingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(
                    _exportingPdf ? 'Exporting...' : 'PDF Report',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F), // PDF Red
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Refresh Data button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _fetchingReport ? null : _fetchReportData,
              icon: _fetchingReport
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E3A5F)),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                _fetchingReport ? 'Fetching live data...' : 'Refresh Report Records',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E3A5F),
                side: const BorderSide(color: Color(0xFF1E3A5F), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          if (_lastSavedFilePath != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => OpenFilex.open(_lastSavedFilePath!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _lastSavedFileType == 'pdf' ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _lastSavedFileType == 'pdf' ? Colors.red.shade200 : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _lastSavedFileType == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
                      color: _lastSavedFileType == 'pdf' ? Colors.red.shade700 : Colors.green.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _lastSavedFileType == 'pdf'
                            ? 'PDF report ready! Tap to view document'
                            : 'Excel file ready! Tap to open in Sheets',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _lastSavedFileType == 'pdf' ? Colors.red.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: _lastSavedFileType == 'pdf' ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== 4. PREVIEW & DATA SECTION ====================
  Widget _buildPreviewAndDataSection(Map<String, dynamic> activeReport) {
    if (_fetchingReport) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: Color(0xFF1E3A5F), strokeWidth: 3),
              SizedBox(height: 12),
              Text(
                'Fetching report records from server...',
                style: TextStyle(fontSize: 13, color: Color(0xFF1E3A5F), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasFetched && _reportRows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              'No records found for ${activeReport['title']}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
            ),
            const SizedBox(height: 4),
            Text(
              'Try choosing a wider date range or selecting another report type.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_reportRows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Summary details
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (activeReport['color'] as Color).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  activeReport['icon'] as IconData,
                  color: activeReport['color'] as Color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${activeReport['title']} Preview',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    Text(
                      'Showing $_totalCount records ready for download',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '$_totalCount Rows',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Scrollable Preview Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFF1E3A5F).withOpacity(0.06)),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF1E3A5F),
              ),
              dataTextStyle: const TextStyle(fontSize: 11, color: Colors.black87),
              columnSpacing: 16,
              horizontalMargin: 12,
              columns: _reportHeaders.map((h) {
                return DataColumn(label: Text(h.toString()));
              }).toList(),
              rows: _reportRows.take(15).map((row) {
                final list = row as List;
                return DataRow(
                  cells: list.map((cell) {
                    final str = cell?.toString() ?? '';
                    return DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          str,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),

          if (_reportRows.length > 15) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                '+ ${_reportRows.length - 15} more rows included in the downloaded Excel file',
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==================== TAB 2: COMPANY FILES & DOCUMENTS ====================
  Widget _buildCompanyFilesTab() {
    final filteredFiles = _getFilteredFiles();

    return _loadingFiles
        ? const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF1E3A5F),
        strokeWidth: 3,
      ),
    )
        : Column(
      children: [
        _buildCompanyFileFilterChips(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchFiles,
            color: const Color(0xFF1E3A5F),
            child: filteredFiles.isEmpty
                ? _buildCompanyFileEmptyState()
                : FadeTransition(
              opacity: _fadeAnimation,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredFiles.length,
                itemBuilder: (_, i) {
                  final f = filteredFiles[i];
                  return _buildGlassFileCard(f);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyFileFilterChips() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: List.generate(_fileFilterLabels.length, (index) {
          final isSelected = _fileFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(
                _fileFilterLabels[index],
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
                setState(() => _fileFilterIndex = index);
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

  Widget _buildCompanyFileEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            'No company documents available',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
          ),
          const SizedBox(height: 4),
          Text(
            'Uploaded templates and policies will appear here',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassFileCard(Map<String, dynamic> f) {
    final title = f['title'] ?? f['filename'] ?? 'Document';
    final category = f['category'] ?? 'general';
    final size = f['file_size']?.toString() ?? '';
    final date = f['created_at']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: Color(0xFF1E3A5F),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A5F),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    if (size.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        size,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                    if (date.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        date.split(' ')[0],
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _downloadCompanyFile(f),
            icon: const Icon(Icons.download_rounded, color: Color(0xFF1E3A5F)),
            tooltip: 'Download File',
          ),
        ],
      ),
    );
  }
}