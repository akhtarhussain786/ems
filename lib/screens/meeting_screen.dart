import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _meetings = [];
  bool _loading = true;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _filterIndex = 0; // 0: All, 1: Upcoming, 2: Past

  final List<String> _filterLabels = ['All', 'Upcoming', 'Past'];

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
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService().getAllMeetingsForAll();

      if (mounted) {
        if (res['success'] == true) {
          final data = res['data'] ?? [];
          setState(() {
            _meetings = data;
            _error = null;
          });
        } else {
          setState(() {
            _error = '❌ ${res['message'] ?? 'Unknown error'}';
            _meetings = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _meetings = [];
        });
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openMeetingLink(String? link) async {
    if (link == null || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No meeting link available'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    String url = link;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open link: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        );
      }
    }
  }

  bool _isPast(String? date, String? time) {
    if (date == null || date.isEmpty) return false;
    try {
      final dt = DateTime.parse(date);
      return dt.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return 'N/A';
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final hour12 = hour % 12 == 0 ? 12 : hour % 12;
        final amPm = hour >= 12 ? 'PM' : 'AM';
        return '$hour12:$minute $amPm';
      }
      return timeStr;
    } catch (_) {
      return timeStr;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'pending':
        return Icons.pending_rounded;
      default:
        return Icons.circle_rounded;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      default:
        return 'Not Invited';
    }
  }

  List<dynamic> _getFilteredMeetings() {
    if (_filterIndex == 0) return _meetings;
    if (_filterIndex == 1) {
      return _meetings.where((m) => !_isPast(m['meeting_date'], m['start_time'])).toList();
    } else {
      return _meetings.where((m) => _isPast(m['meeting_date'], m['start_time'])).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredMeetings = _getFilteredMeetings();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(),
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
            child: _error != null
                ? _buildErrorState()
                : RefreshIndicator(
              onRefresh: _fetch,
              color: const Color(0xFF1E3A5F),
              child: filteredMeetings.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredMeetings.length,
                  itemBuilder: (_, i) {
                    final m = filteredMeetings[i];
                    return _buildGlassMeetingCard(m);
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
                  Icons.video_call_rounded,
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
                'Meetings',
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
    String message = 'No meetings';
    String subMessage = 'No meetings scheduled';

    switch (_filterIndex) {
      case 1:
        message = 'No upcoming meetings';
        subMessage = 'All meetings are completed or none scheduled';
        break;
      case 2:
        message = 'No past meetings';
        subMessage = 'No completed meetings available';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_call_rounded,
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

  // ==================== ERROR STATE ====================
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FIXED GLASS MEETING CARD ====================
  Widget _buildGlassMeetingCard(Map<String, dynamic> m) {
    final isPast = _isPast(m['meeting_date'], m['start_time']);
    final hasLink = m['meeting_link'] != null && m['meeting_link'].toString().isNotEmpty;
    final isInvited = m['my_attendance'] != null;
    final status = m['my_attendance'];
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);
    final statusLabel = _statusLabel(status);

    return GestureDetector(
      onTap: () => _showMeetingDetails(m),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Icon and Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isPast
                        ? const LinearGradient(
                      colors: [Colors.grey, Colors.grey],
                    )
                        : const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Icon(
                    isPast ? Icons.check_circle_rounded : Icons.video_call_rounded,
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
                              m['title'] ?? 'Untitled Meeting',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isPast ? Colors.grey[600] : const Color(0xFF1E3A5F),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPast)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.12),
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                              ),
                              child: const Text(
                                'PAST',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Row for date, time, venue - FIXED: Wrapped in Expanded and used Flexible
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: isPast ? Colors.grey[400] : Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(m['meeting_date'] ?? ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isPast ? Colors.grey[400] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: isPast ? Colors.grey[400] : Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTime(m['start_time'] ?? ''),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isPast ? Colors.grey[400] : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                          if (m['venue'] != null && m['venue'].toString().isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: isPast ? Colors.grey[400] : Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 100),
                                  child: Text(
                                    m['venue'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isPast ? Colors.grey[400] : Colors.grey[500],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Status and Action
            Row(
              children: [
                // Status Badge
                Flexible(
                  child: isInvited
                      ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 12,
                          color: statusColor,
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
                  )
                      : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 12,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Not Invited',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Action Button
                if (hasLink && isInvited && !isPast)
                  GestureDetector(
                    onTap: () => _openMeetingLink(m['meeting_link']),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                        ),
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.video_call_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Join',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!isPast && !isInvited)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Text(
                      'Scheduled',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (isPast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MEETING DETAILS ====================
  void _showMeetingDetails(Map<String, dynamic> meeting) {
    HapticFeedback.lightImpact();
    final isPast = _isPast(meeting['meeting_date'], meeting['start_time']);
    final hasLink = meeting['meeting_link'] != null && meeting['meeting_link'].toString().isNotEmpty;
    final isInvited = meeting['my_attendance'] != null;
    final status = meeting['my_attendance'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isPast
                        ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                        : const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Icon(
                    isPast ? Icons.check_circle_rounded : Icons.video_call_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    meeting['title'] ?? 'Meeting Details',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                if (isPast)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Text(
                      'PAST',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Date', _formatDate(meeting['meeting_date'] ?? '')),
            _buildDetailRow('Start Time', _formatTime(meeting['start_time'] ?? '')),
            _buildDetailRow('End Time', _formatTime(meeting['end_time'] ?? '')),
            if (meeting['venue'] != null && meeting['venue'].toString().isNotEmpty)
              _buildDetailRow('Venue', meeting['venue']),
            if (meeting['status'] != null)
              _buildDetailRow('Status', meeting['status']),
            if (meeting['created_by_name'] != null)
              _buildDetailRow('Created By', meeting['created_by_name']),
            _buildDetailRow('Participants', '${meeting['participant_count'] ?? 0}'),
            _buildDetailRow('Your Status', isInvited ? _statusLabel(status) : 'Not Invited'),
            if (meeting['description'] != null && meeting['description'].toString().isNotEmpty)
              _buildDetailRow('Description', meeting['description']),
            if (hasLink)
              _buildDetailRow('Link', meeting['meeting_link']),
            const SizedBox(height: 16),
            if (hasLink && isInvited && !isPast)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _openMeetingLink(meeting['meeting_link']);
                  },
                  icon: const Icon(Icons.video_call_rounded),
                  label: const Text('Join Meeting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E3A5F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}