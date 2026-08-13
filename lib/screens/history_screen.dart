import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService().getAttendanceHistory(_selectedMonth);
      if (mounted && response['success'] == true) {
        setState(() {
          _records = List<Map<String, dynamic>>.from(response['data'] ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int offset) {
    final parts = _selectedMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final date = DateTime(year, month + offset, 1);
    setState(() {
      _selectedMonth = DateFormat('yyyy-MM').format(date);
    });
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        // Keeps content clear of the system navigation bar
        top: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(DateFormat('yyyy-MM').parse(_selectedMonth)),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _records.isEmpty
                      ? const Center(child: Text('No attendance records found'))
                      : RefreshIndicator(
                          onRefresh: _fetchHistory,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _records.length,
                            itemBuilder: (_, i) => _buildRecord(_records[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecord(Map<String, dynamic> record) {
    final status = record['status'] ?? '';
    final statusColor = Helpers.getStatusColor(status) == '#22c55e'
        ? Colors.green
        : Helpers.getStatusColor(status) == '#f59e0b'
            ? Colors.orange
            : Helpers.getStatusColor(status) == '#ef4444'
                ? Colors.red
                : Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  Helpers.getStatusEmoji(status),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Helpers.formatDate(record['attendance_date']),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('In: ${Helpers.formatTime(record['check_in'])}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(width: 12),
                      Text('Out: ${Helpers.formatTime(record['check_out'])}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Helpers.formatDuration(record['working_hours']),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if ((record['late_minutes'] ?? 0) > 0)
                  Text('${record['late_minutes']} min late',
                      style: TextStyle(color: Colors.orange[700], fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
