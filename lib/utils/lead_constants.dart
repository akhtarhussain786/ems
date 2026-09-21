import 'package:flutter/material.dart';

class LeadConstants {
  static const List<String> sources = [
    'Website',
    'Google Ads',
    'Google',
    'Facebook',
    'Instagram',
    'WhatsApp',
    'Phone Call',
    'Referral',
    'Walk-In',
    'Manual',
    'Other',
  ];

  static const List<String> priorities = [
    'Low',
    'Medium',
    'High',
    'Urgent',
  ];

  static const List<String> statuses = [
    'New',
    'Follow-up',
    'Interested',
    'Qualified',
    'Won',
    'Lost',
    'Duplicate',
    'Not Interested',
  ];

  static const List<String> nextActionTypes = [
    'Follow-up Call',
    'Meeting / Demo',
    'Send Proposal',
    'Send WhatsApp',
    'Site Visit',
    'Email Information',
    'Final Discussion',
  ];

  static const List<String> indianStates = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  static Color getPriorityColor(String? priority) {
    switch ((priority ?? '').toLowerCase()) {
      case 'urgent':
        return const Color(0xFFEF4444); // Red
      case 'high':
        return const Color(0xFFF97316); // Orange
      case 'medium':
        return const Color(0xFFF59E0B); // Amber
      case 'low':
        return const Color(0xFF10B981); // Emerald Green
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  static Color getPriorityBgColor(String? priority) {
    return getPriorityColor(priority).withValues(alpha: 0.12);
  }

  static IconData getPriorityIcon(String? priority) {
    switch ((priority ?? '').toLowerCase()) {
      case 'urgent':
        return Icons.warning_rounded;
      case 'high':
        return Icons.arrow_upward_rounded;
      case 'medium':
        return Icons.drag_handle_rounded;
      case 'low':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.circle;
    }
  }

  static Color getStatusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'won':
        return const Color(0xFF10B981); // Green
      case 'qualified':
        return const Color(0xFF0D9488); // Teal
      case 'interested':
        return const Color(0xFF3B82F6); // Blue
      case 'follow_up':
      case 'follow-up':
        return const Color(0xFF8B5CF6); // Purple
      case 'new':
        return const Color(0xFFF59E0B); // Amber
      case 'lost':
      case 'not_interested':
      case 'wrong_number':
        return const Color(0xFFEF4444); // Red
      case 'duplicate':
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  static IconData getSourceIcon(String? source) {
    switch ((source ?? '').toLowerCase()) {
      case 'website':
        return Icons.language_rounded;
      case 'google':
      case 'google ads':
        return Icons.search_rounded;
      case 'facebook':
        return Icons.facebook_rounded;
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'whatsapp':
        return Icons.chat_bubble_outline_rounded;
      case 'phone call':
      case 'manual':
        return Icons.phone_in_talk_rounded;
      case 'referral':
        return Icons.handshake_outlined;
      case 'walk-in':
        return Icons.directions_walk_rounded;
      default:
        return Icons.source_rounded;
    }
  }
}
