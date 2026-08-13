import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class TelecallerScreen extends StatefulWidget {
  const TelecallerScreen({super.key});

  @override
  State<TelecallerScreen> createState() => _TelecallerScreenState();
}

class _TelecallerScreenState extends State<TelecallerScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _leads = [];
  List<dynamic> _followUps = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  int _tabIndex = 0;
  final _searchCtrl = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('telecaller/dashboard');
      if (mounted && res['success'] == true) {
        setState(() {
          _leads = (res['data'] is Map ? (res['data']!['leads'] ?? []) : []);
          _followUps = (res['data'] is Map ? (res['data']!['today_follow_ups'] ?? []) : []);
          _stats = (res['data'] is Map ? (res['data']!['stats'] ?? {}) : {});
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'won': case 'qualified': return Colors.green;
      case 'lost': case 'not_interested': case 'wrong_number': return Colors.red;
      case 'interested': return Colors.blue;
      case 'follow_up': return Colors.deepPurple;
      case 'duplicate': return Colors.grey;
      case 'new': return Colors.orange;
      default: return Colors.grey;
    }
  }

  // ==================== FIXED: DIRECT PHONE DIALER ====================
  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Clean the phone number - keep only digits
    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove leading zeros
    if (cleanedNumber.startsWith('0')) {
      cleanedNumber = cleanedNumber.substring(1);
    }

    // Check if it's a valid phone number
    if (cleanedNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid phone number: $phoneNumber'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Add country code if missing (India +91)
    if (cleanedNumber.length == 10) {
      cleanedNumber = '+91$cleanedNumber';
    } else if (!cleanedNumber.startsWith('+')) {
      cleanedNumber = '+$cleanedNumber';
    }

    print('🔵 Attempting to call: $cleanedNumber');

    try {
      // DIRECT METHOD 1: Using tel: scheme
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanedNumber);

      // Try to launch directly - this should work on most devices
      if (await canLaunchUrl(phoneUri)) {
        HapticFeedback.mediumImpact();
        await launchUrl(phoneUri);
        return;
      }
    } catch (e) {
      print('🔴 Method 1 failed: $e');
    }

    try {
      // DIRECT METHOD 2: Using tel: with encoded number
      final String encodedNumber = Uri.encodeComponent(cleanedNumber);
      final Uri encodedUri = Uri.parse('tel:$encodedNumber');

      if (await canLaunchUrl(encodedUri)) {
        HapticFeedback.mediumImpact();
        await launchUrl(encodedUri);
        return;
      }
    } catch (e) {
      print('🔴 Method 2 failed: $e');
    }

    try {
      // DIRECT METHOD 3: Using intent:// scheme (Android)
      final String intentUrl = 'intent://$cleanedNumber#Intent;action=android.intent.action.CALL;end';
      final Uri intentUri = Uri.parse(intentUrl);

      if (await canLaunchUrl(intentUri)) {
        HapticFeedback.mediumImpact();
        await launchUrl(intentUri);
        return;
      }
    } catch (e) {
      print('🔴 Method 3 failed: $e');
    }

    // If all methods fail, try with just numbers
    try {
      final String simpleNumber = cleanedNumber.replaceAll('+', '');
      final Uri simpleUri = Uri(scheme: 'tel', path: simpleNumber);

      if (await canLaunchUrl(simpleUri)) {
        HapticFeedback.mediumImpact();
        await launchUrl(simpleUri);
        return;
      }
    } catch (e) {
      print('🔴 Method 4 failed: $e');
    }

    // ULTIMATE FALLBACK: Show dialog with number
    _showCallFallbackDialog(cleanedNumber);
  }

  // ==================== FALLBACK DIALOG ====================
  void _showCallFallbackDialog(String phoneNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_android_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text('Call Number'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Phone dialer not available. Please manually call:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 2),
              ),
              child: SelectableText(
                phoneNumber,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap and hold to copy number',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Try again with a different approach
              _tryDirectCall(phoneNumber);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DIRECT CALL ATTEMPT ====================
  Future<void> _tryDirectCall(String phoneNumber) async {
    try {
      // Try with ACTION_CALL intent
      final Uri callUri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
        return;
      }
    } catch (e) {
      print('🔴 Direct call failed: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please use the number above to call manually'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // ==================== WHATSAPP FUNCTION ====================
  Future<void> _openWhatsApp(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanedNumber.startsWith('0')) {
      cleanedNumber = cleanedNumber.substring(1);
    }

    if (cleanedNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid phone number: $phoneNumber'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (cleanedNumber.length == 10) {
      cleanedNumber = '91$cleanedNumber';
    }

    try {
      // Try WhatsApp app first
      final String appUrl = 'whatsapp://send?phone=$cleanedNumber';
      final Uri appUri = Uri.parse(appUrl);
      if (await canLaunchUrl(appUri)) {
        HapticFeedback.lightImpact();
        await launchUrl(appUri);
        return;
      }
    } catch (e) {
      print('🔴 WhatsApp app failed: $e');
    }

    try {
      // Fallback to web WhatsApp
      final String webUrl = 'https://wa.me/$cleanedNumber';
      final Uri webUri = Uri.parse(webUrl);
      if (await canLaunchUrl(webUri)) {
        HapticFeedback.lightImpact();
        await launchUrl(webUri);
        return;
      }
    } catch (e) {
      print('🔴 WhatsApp web failed: $e');
    }

    // Show fallback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Open WhatsApp with number: $cleanedNumber'),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: 'COPY',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: cleanedNumber));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Number copied!'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(),
      body: SafeArea(
        // Keeps content clear of the system navigation bar
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A5F)))
            : FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              if (_stats != null) _buildStatsRow(),
              _buildTabRow(),
              _buildSearchBar(),
              Expanded(
                child: _tabIndex == 0
                    ? _buildLeads()
                    : _buildFollowUps(),
              ),
            ],
          ),
        ),
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
                  Icons.phone_android_rounded,
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
                'Telecaller Dashboard',
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
          margin: const EdgeInsets.only(right: 12),
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

  // ==================== STATS ROW ====================
  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildGlassStatCard('Assigned', '${_stats!['total_assigned'] ?? 0}', Colors.blue),
          _buildGlassStatCard("Today's Calls", '${_stats!['today_calls'] ?? 0}', Colors.orange),
          _buildGlassStatCard('Pending FUP', '${_stats!['pending_followups'] ?? 0}', Colors.red),
          _buildGlassStatCard('Converted', '${_stats!['converted'] ?? 0}', Colors.green),
        ],
      ),
    );
  }

  Widget _buildGlassStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TAB ROW ====================
  Widget _buildTabRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Row(
        children: [
          Expanded(
            child: _buildGlassTab('Leads (${_leads.length})', 0),
          ),
          Expanded(
            child: _buildGlassTab('Follow-ups (${_followUps.length})', 1),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTab(String label, int idx) {
    final isSelected = _tabIndex == idx;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _tabIndex = idx);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A5F).withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? const Color(0xFF1E3A5F) : Colors.grey,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== SEARCH BAR ====================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          onChanged: (v) async {
            if (v.length < 2) {
              _fetch();
              return;
            }
            final res = await ApiService().post('leads/search', {'query': v});
            if (mounted && res['success'] == true) {
              setState(() => _leads = res['data'] ?? []);
            }
          },
        ),
      ),
    );
  }

  // ==================== LEADS LIST ====================
  Widget _buildLeads() {
    if (_leads.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No assigned leads',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: const Color(0xFF1E3A5F),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _leads.length,
        itemBuilder: (_, i) {
          final l = _leads[i];
          final name = l['customer_name'] ?? '';
          final phone = l['phone'] ?? l['customer_phone'] ?? '';
          final status = l['status'] ?? 'new';
          final statusColor = _statusColor(status);

          return Container(
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
            child: ExpansionTile(
              leading: Container(
                width: 42,
                height: 42,
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
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              subtitle: Text(
                '$phone | ${l['source'] ?? l['lead_source'] ?? 'Unknown'}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
                maxLines: 1,
              ),
              trailing: Container(
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
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      if (l['requirement'] != null && l['requirement'].toString().isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${l['requirement']}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (l['city'] != null && l['city'].toString().isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '📍 ${l['city']} ${l['budget'] != null ? '| Budget: ₹${l['budget']}' : ''}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      // Action Buttons Row 1
                      Row(
                        children: [
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.call_rounded,
                              'Call',
                                  () => _makePhoneCall(phone),
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.message_rounded,
                              'WhatsApp',
                                  () => _openWhatsApp(phone),
                              Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.event_rounded,
                              'Follow-up',
                                  () => _showFollowUpDialog(l),
                              Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Action Buttons Row 2
                      Row(
                        children: [
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.check_circle_rounded,
                              'Qualify',
                                  () => _qualifyLead(l),
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.cancel_rounded,
                              'Not Int.',
                                  () => _updateStatus(l, 'not_interested'),
                              Colors.red,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _buildGlassActionButton(
                              Icons.report_rounded,
                              'Wrong #',
                                  () => _updateStatus(l, 'wrong_number'),
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== GLASS ACTION BUTTON ====================
  Widget _buildGlassActionButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.08), color.withOpacity(0.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FOLLOW-UPS LIST ====================
  Widget _buildFollowUps() {
    if (_followUps.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No pending follow-ups',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      color: const Color(0xFF1E3A5F),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _followUps.length,
        itemBuilder: (_, i) {
          final f = _followUps[i];
          final leadName = f['lead_name'] ?? f['customer_name'] ?? 'Unknown';
          final phone = f['phone'] ?? f['customer_phone'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
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
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.deepPurpleAccent],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.event_note_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leadName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      if (phone.isNotEmpty)
                        Text(
                          '📞 $phone',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      Text(
                        '📅 ${f['follow_up_date'] ?? ''} ${f['follow_up_time'] ?? ''}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 10,
                        ),
                      ),
                      if (f['notes'] != null && f['notes'].toString().isNotEmpty)
                        Text(
                          '📝 ${f['notes']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Call button
                    GestureDetector(
                      onTap: () => _makePhoneCall(phone),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.call_rounded,
                          color: Colors.green,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Complete button
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await ApiService().post('follow_ups/complete', {'id': f['id']});
                        _fetch();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.blue,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== CALL DIALOG ====================
  void _showCallDialog(Map<String, dynamic> l) {
    String callStatus = 'connected';
    final notesCtrl = TextEditingController();
    final phone = l['phone'] ?? l['customer_phone'] ?? '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.call_rounded, color: Colors.green),
              ),
              const SizedBox(width: 10),
              Text(
                'Call ${l['customer_name'] ?? ''}',
                style: const TextStyle(fontSize: 16, color: Color(0xFF1E3A5F)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (phone.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '📞 $phone',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _makePhoneCall(phone);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CALL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: callStatus,
                items: ['connected', 'interested', 'not_interested', 'busy', 'no_answer', 'callback', 'wrong_number']
                    .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.replaceAll('_', ' ').toUpperCase()),
                ))
                    .toList(),
                onChanged: (v) => setLocalState(() => callStatus = v!),
                decoration: const InputDecoration(
                  labelText: 'Call Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ApiService().post('telecaller/call-log', {
                  'lead_id': l['id'],
                  'call_status': callStatus,
                  'notes': notesCtrl.text,
                });
                if (ctx.mounted) Navigator.pop(context);
                _fetch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== FOLLOW-UP DIALOG ====================
  void _showFollowUpDialog(Map<String, dynamic> l) {
    String date = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];
    String time = '10:00';
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.event_rounded, color: Colors.deepPurple),
              ),
              const SizedBox(width: 10),
              const Text(
                'Schedule Follow-up',
                style: TextStyle(fontSize: 16, color: Color(0xFF1E3A5F)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  hintText: date,
                  suffixIcon: const Icon(Icons.calendar_today_rounded),
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (d != null) {
                    setLocalState(() => date = d.toIso8601String().split('T')[0]);
                  }
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ApiService().post('telecaller/follow-up', {
                  'lead_id': l['id'],
                  'follow_up_date': date,
                  'follow_up_time': time,
                  'notes': notesCtrl.text,
                });
                if (ctx.mounted) Navigator.pop(context);
                _fetch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== QUALIFY LEAD ====================
  Future<void> _qualifyLead(Map<String, dynamic> l) async {
    HapticFeedback.mediumImpact();
    final res = await ApiService().post('telecaller/qualify', {'lead_id': l['id']});
    if (mounted) {
      _fetch();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Lead qualified successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ==================== UPDATE STATUS ====================
  Future<void> _updateStatus(Map<String, dynamic> l, String status) async {
    HapticFeedback.mediumImpact();
    final res = await ApiService().post('telecaller/update-status', {
      'lead_id': l['id'],
      'status': status,
    });
    if (mounted) {
      _fetch();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Status updated successfully!'),
          backgroundColor: status == 'not_interested' || status == 'wrong_number' ? Colors.red : Colors.blue,
        ),
      );
    }
  }
}