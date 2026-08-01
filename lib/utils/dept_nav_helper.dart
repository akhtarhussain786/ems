import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import '../screens/tasks_screen.dart';
import '../screens/daily_work_report_screen.dart';
import '../screens/leads_screen.dart';
import '../screens/campaigns_screen.dart';
import '../screens/call_report_screen.dart';
import '../screens/follow_up_screen.dart';
import '../screens/hr_activities_screen.dart';
import '../screens/travel_screen.dart';
import '../screens/expense_screen.dart';
import '../screens/document_screen.dart';
import '../screens/notice_screen.dart';
import '../screens/meeting_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/notification_screen.dart';
import '../screens/help_screen.dart';
import '../screens/marketing_screen.dart';
import '../screens/telecaller_screen.dart';
import '../screens/sales_screen.dart';
import '../screens/it_team_screen.dart';
import '../screens/download_screen.dart';
import '../screens/leave_management_screen.dart';
import '../screens/lead_detail_screen.dart';
import '../screens/salary_report_screen.dart';

// ==================== REMOVED: dashboard, attendance, history, profile ====================
enum DeptFeature {
  dailyWorkReport, tasks, leads, campaigns, callReports, followUps, hrActivities,
  travel, expenses, documents, notices, meetings, chat, notifications, help,
  marketing, telecaller, salesPipeline, itTeam, downloads, leaveManagement,
  leadDetail, salaryReport
}

class DeptNavHelper {
  static Future<bool> isRole(List<String> roles) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConstants.userKey);
    if (userJson == null) return false;
    try {
      final data = jsonDecode(userJson);
      final dept = (data['department_name'] ?? '').toString().toLowerCase();
      final role = (data['role'] ?? '').toString().toLowerCase();
      return roles.any((r) => dept.contains(r.toLowerCase()) || role.contains(r.toLowerCase()));
    } catch (_) {
      return false;
    }
  }

  static List<DeptFeature> getFeaturesForRole(String? roleName, String? deptName) {
    final role = roleName?.toString().toLowerCase() ?? '';
    final dept = deptName?.toString().toLowerCase() ?? '';

    // Super Admin - All features (except dashboard, attendance, history, profile)
    if (role.contains('super_admin') || role.contains('admin')) {
      return DeptFeature.values.toList();
    }

    // Digital Marketing
    if (role.contains('digital_marketing') || role == 'digital_marketing_admin') {
      return [
        DeptFeature.leaveManagement,
        DeptFeature.leads, DeptFeature.campaigns, DeptFeature.marketing,
        DeptFeature.dailyWorkReport, DeptFeature.travel, DeptFeature.expenses,
      ];
    }

    // Telecaller
    if (role.contains('telecaller') || role == 'telecaller_admin') {
      return [
        DeptFeature.leaveManagement,
        DeptFeature.telecaller, DeptFeature.callReports, DeptFeature.followUps,
        DeptFeature.dailyWorkReport,
      ];
    }

    // Sales
    if (role.contains('sales') || role == 'sales_admin') {
      return [
        DeptFeature.leaveManagement,
        DeptFeature.salesPipeline, DeptFeature.followUps, DeptFeature.marketing,
        DeptFeature.travel, DeptFeature.expenses, DeptFeature.dailyWorkReport,
        DeptFeature.leads, DeptFeature.leadDetail
      ];
    }

    // HR
    if (role.contains('hr') || role == 'hr_admin') {
      return [
        DeptFeature.leaveManagement,
        DeptFeature.hrActivities, DeptFeature.dailyWorkReport, DeptFeature.documents,
        DeptFeature.notices, DeptFeature.notifications,
        DeptFeature.salaryReport
      ];
    }

    // Accounts
    if (role.contains('accounts') || role == 'accounts_admin') {
      return [
        DeptFeature.leaveManagement,
        DeptFeature.expenses, DeptFeature.dailyWorkReport, DeptFeature.documents,
        DeptFeature.notices,
        DeptFeature.salaryReport
      ];
    }

    // Project Manager
    if (role.contains('project_manager') || role.contains('manager')) {
      return [
        DeptFeature.leaveManagement,
        DeptFeature.tasks, DeptFeature.dailyWorkReport, DeptFeature.notices,
        DeptFeature.meetings, DeptFeature.chat,
      ];
    }

    // Default - Department based
    return getFeaturesForDepartment(deptName);
  }

  static List<DeptFeature> getFeaturesForDepartment(String? deptName) {
    switch (deptName?.toLowerCase()) {
      case 'development':
      case 'it':
        return [
          DeptFeature.tasks,
          DeptFeature.dailyWorkReport, DeptFeature.itTeam, DeptFeature.documents,
          DeptFeature.notices, DeptFeature.meetings, DeptFeature.chat,
          DeptFeature.notifications,
        ];
      case 'hr':
        return [
          DeptFeature.leaveManagement,
          DeptFeature.hrActivities, DeptFeature.dailyWorkReport, DeptFeature.documents,
          DeptFeature.notices, DeptFeature.notifications,
          DeptFeature.salaryReport
        ];
      case 'digital marketing':
      case 'marketing':
        return [
          DeptFeature.leaveManagement,
          DeptFeature.marketing, DeptFeature.leads, DeptFeature.campaigns,
          DeptFeature.dailyWorkReport, DeptFeature.travel, DeptFeature.expenses,
          DeptFeature.leadDetail
        ];
      case 'telecaller':
        return [
          DeptFeature.leaveManagement,
          DeptFeature.telecaller, DeptFeature.callReports, DeptFeature.followUps,
          DeptFeature.dailyWorkReport,
        ];
      case 'accounts':
        return [
          DeptFeature.leaveManagement,
          DeptFeature.expenses, DeptFeature.dailyWorkReport, DeptFeature.documents,
          DeptFeature.notices,
          DeptFeature.salaryReport
        ];
      case 'sales':
        return [
          DeptFeature.leaveManagement,
          DeptFeature.salesPipeline, DeptFeature.followUps, DeptFeature.marketing,
          DeptFeature.travel, DeptFeature.expenses, DeptFeature.dailyWorkReport,
          DeptFeature.leads, DeptFeature.leadDetail
        ];
      default:
        return [
          DeptFeature.leaveManagement,
          DeptFeature.dailyWorkReport, DeptFeature.notices, DeptFeature.notifications,
          DeptFeature.meetings, DeptFeature.chat, DeptFeature.help, DeptFeature.downloads,
        ];
    }
  }

  static String getFeatureLabel(DeptFeature f) {
    switch (f) {
      case DeptFeature.dailyWorkReport: return 'Daily Report';
      case DeptFeature.tasks: return 'Tasks';
      case DeptFeature.leads: return 'Leads';
      case DeptFeature.campaigns: return 'Campaigns';
      case DeptFeature.callReports: return 'Call Reports';
      case DeptFeature.followUps: return 'Follow Ups';
      case DeptFeature.hrActivities: return 'HR Activities';
      case DeptFeature.travel: return 'Travel';
      case DeptFeature.expenses: return 'Expenses';
      case DeptFeature.documents: return 'Documents';
      case DeptFeature.notices: return 'Notices';
      case DeptFeature.meetings: return 'Meetings';
      case DeptFeature.chat: return 'Chat';
      case DeptFeature.notifications: return 'Notifications';
      case DeptFeature.help: return 'Help & Support';
      case DeptFeature.marketing: return 'Marketing';
      case DeptFeature.telecaller: return 'Telecaller';
      case DeptFeature.salesPipeline: return 'Sales Pipeline';
      case DeptFeature.itTeam: return 'IT Team';
      case DeptFeature.downloads: return 'Downloads';
      case DeptFeature.leaveManagement: return 'Leave Management';
      case DeptFeature.leadDetail: return 'Lead Detail';
      case DeptFeature.salaryReport: return 'Salary Report';
    }
  }

  static IconData getFeatureIcon(DeptFeature f) {
    switch (f) {
      case DeptFeature.dailyWorkReport: return Icons.article_rounded;
      case DeptFeature.tasks: return Icons.task_rounded;
      case DeptFeature.leads: return Icons.group_add_rounded;
      case DeptFeature.campaigns: return Icons.campaign_rounded;
      case DeptFeature.callReports: return Icons.phone_rounded;
      case DeptFeature.followUps: return Icons.timeline_rounded;
      case DeptFeature.hrActivities: return Icons.handshake_rounded;
      case DeptFeature.travel: return Icons.flight_rounded;
      case DeptFeature.expenses: return Icons.receipt_rounded;
      case DeptFeature.documents: return Icons.description_rounded;
      case DeptFeature.notices: return Icons.campaign_rounded;
      case DeptFeature.meetings: return Icons.event_rounded;
      case DeptFeature.chat: return Icons.chat_rounded;
      case DeptFeature.notifications: return Icons.notifications_rounded;
      case DeptFeature.help: return Icons.support_rounded;
      case DeptFeature.marketing: return Icons.trending_up_rounded;
      case DeptFeature.telecaller: return Icons.headset_mic_rounded;
      case DeptFeature.salesPipeline: return Icons.trending_up_rounded;
      case DeptFeature.itTeam: return Icons.computer_rounded;
      case DeptFeature.downloads: return Icons.download_rounded;
      case DeptFeature.leaveManagement: return Icons.event_rounded;
      case DeptFeature.leadDetail: return Icons.person_search_rounded;
      case DeptFeature.salaryReport: return Icons.payments_rounded;
    }
  }

  // ==================== BUILD FEATURE SCREEN ====================
  static Widget buildFeatureScreen(DeptFeature feature) {
    try {
      switch (feature) {
        case DeptFeature.tasks:
          return const TasksScreen();
        case DeptFeature.dailyWorkReport:
          return const DailyWorkReportScreen();
        case DeptFeature.leads:
          return const LeadsScreen();
        case DeptFeature.campaigns:
          return const CampaignsScreen();
        case DeptFeature.callReports:
          return const CallReportScreen();
        case DeptFeature.followUps:
          return const FollowUpScreen();
        case DeptFeature.hrActivities:
          return const HRActivitiesScreen();
        case DeptFeature.travel:
          return const TravelScreen();
        case DeptFeature.expenses:
          return const ExpenseScreen();
        case DeptFeature.documents:
          return const DocumentScreen();
        case DeptFeature.notices:
          return const NoticeScreen();
        case DeptFeature.meetings:
          return const MeetingScreen();
        case DeptFeature.chat:
          return const ChatScreen();
        case DeptFeature.notifications:
          return const NotificationScreen();
        case DeptFeature.help:
          return const HelpScreen();
        case DeptFeature.marketing:
          return const MarketingScreen();
        case DeptFeature.telecaller:
          return const TelecallerScreen();
        case DeptFeature.salesPipeline:
          return const SalesScreen();
        case DeptFeature.leaveManagement:
          return const LeaveManagementScreen();
        case DeptFeature.itTeam:
          return const ITTeamScreen();
        case DeptFeature.downloads:
          return const DownloadScreen();
        case DeptFeature.leadDetail:
          return const LeadDetailScreen();
        case DeptFeature.salaryReport:
          return const SalaryReportScreen();

        default:
          return _buildPlaceholderScreen(
            getFeatureLabel(feature),
            getFeatureIcon(feature),
            'This feature is coming soon!',
          );
      }
    } catch (e) {
      return _buildPlaceholderScreen(
        getFeatureLabel(feature),
        getFeatureIcon(feature),
        'Feature under development',
      );
    }
  }

  // ==================== PLACEHOLDER SCREEN ====================
  static Widget _buildPlaceholderScreen(String title, IconData icon, String message) {
    return Builder(
      builder: (context) => Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: const Color(0xFF1E3A5F).withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}