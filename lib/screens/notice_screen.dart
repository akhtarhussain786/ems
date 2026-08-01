import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _notices = [];
  bool _loading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _filterIndex = 0; // 0: All, 1: Urgent, 2: High, 3: Medium, 4: Normal

  final List<String> _filterLabels = ['All', 'Urgent', 'High', 'Medium', 'Normal'];

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
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('notices');
      if (mounted && res['success'] == true) {
        setState(() => _notices = res['data'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _viewNotice(Map<String, dynamic> notice) {
    HapticFeedback.lightImpact();
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    notice['title'] ?? 'Notice',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                ),
                _buildPriorityBadge(notice['priority'] ?? 'normal', large: true),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(notice['created_at'] ?? ''),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(notice['created_at'] ?? ''),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 0.5,
                ),
              ),
              child: Text(
                notice['content'] ?? 'No content available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'normal':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority) {
      case 'urgent':
        return Icons.priority_high_rounded;
      case 'high':
        return Icons.trending_up_rounded;
      case 'medium':
        return Icons.trending_flat_rounded;
      case 'normal':
        return Icons.trending_down_rounded;
      default:
        return Icons.circle_rounded;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High';
      case 'medium':
        return 'Medium';
      case 'normal':
        return 'Normal';
      default:
        return priority;
    }
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
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return dateStr;
    }
  }

  List<dynamic> _getFilteredNotices() {
    if (_filterIndex == 0) return _notices;
    final priorityMap = {
      1: 'urgent',
      2: 'high',
      3: 'medium',
      4: 'normal',
    };
    final priority = priorityMap[_filterIndex];
    return _notices.where((n) => (n['priority'] ?? 'normal') == priority).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotices = _getFilteredNotices();

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
            child: RefreshIndicator(
              onRefresh: _fetch,
              color: const Color(0xFF1E3A5F),
              child: filteredNotices.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                opacity: _fadeAnimation,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredNotices.length,
                  itemBuilder: (_, i) {
                    final n = filteredNotices[i];
                    return _buildGlassNoticeCard(n);
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
                'Notice Board',
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
    String message = 'No notices';
    String subMessage = 'Check back later for updates';

    switch (_filterIndex) {
      case 1:
        message = 'No urgent notices';
        subMessage = 'No urgent notices available';
        break;
      case 2:
        message = 'No high priority notices';
        subMessage = 'No high priority notices available';
        break;
      case 3:
        message = 'No medium priority notices';
        subMessage = 'No medium priority notices available';
        break;
      case 4:
        message = 'No normal notices';
        subMessage = 'No normal priority notices available';
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

  // ==================== GLASS NOTICE CARD ====================
  Widget _buildGlassNoticeCard(Map<String, dynamic> n) {
    final priority = n['priority'] ?? 'normal';
    final priorityColor = _priorityColor(priority);
    final priorityIcon = _priorityIcon(priority);
    final priorityLabel = _priorityLabel(priority);

    return GestureDetector(
      onTap: () => _viewNotice(n),
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
                          n['title'] ?? 'Untitled',
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
                        _formatDate(n['created_at'] ?? ''),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(n['created_at'] ?? ''),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  if (n['content'] != null && n['content'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      n['content'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // View button
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

  // ==================== PRIORITY BADGE ====================
  Widget _buildPriorityBadge(String priority, {bool large = false}) {
    final color = _priorityColor(priority);
    final label = _priorityLabel(priority);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 10 : 6,
        vertical: large ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(large ? 10 : 8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: large ? 1 : 0.5,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: large ? 11 : 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}