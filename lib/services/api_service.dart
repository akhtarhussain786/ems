import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'session_manager.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();

  Future<String?> getToken() => SessionManager.instance.getToken();

  Future<void> setToken(String token, {int? expiresIn}) =>
      SessionManager.instance.saveSession(token, expiresIn: expiresIn);

  Future<void> clearToken() => SessionManager.instance.clear();

  /// Returns a token that is present and not yet expired, otherwise forces a
  /// logout. Stops expired sessions before they ever reach the network.
  Future<String> _requireValidToken() async {
    final token = await SessionManager.instance.getToken();

    if (token == null || token.isEmpty) {
      await SessionManager.instance.forceLogout(
        reason: 'Please login to continue.',
      );
      throw UnauthorizedException('No authentication token');
    }

    if (SessionManager.instance.isExpired) {
      await SessionManager.instance.forceLogout();
      throw UnauthorizedException('Session expired. Please login again.');
    }

    return token;
  }

  Map<String, String> _headers({bool auth = true, String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Empty response from server'};
    }
    return jsonDecode(response.body);
  }

  /// Any 401 — or an explicit `force_logout` from the backend — ends the
  /// session here, so no individual screen has to remember to handle it.
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final decoded = _decodeResponse(response);
    if (response.statusCode == 401 || decoded['force_logout'] == true) {
      final message = decoded['message'] ?? 'Session expired. Please login again.';
      await SessionManager.instance.forceLogout(reason: message);
      throw UnauthorizedException(message);
    }
    return decoded;
  }

  // ============================================================
  // ✅ GET REQUEST
  // ============================================================
  Future<Map<String, dynamic>> get(String endpoint) async {
    final token = await _requireValidToken();

    final uri = Uri.parse('${AppConstants.baseUrl}/$endpoint')
        .replace(queryParameters: {'token': token});

    final headers = _headers(token: token);
    print('🟢 GET URL: $uri');

    var response = await _client
        .get(uri, headers: headers)
        .timeout(AppConstants.httpTimeout);

    if (response.statusCode == 302 || response.statusCode == 301) {
      final location = response.headers['location'];
      if (location != null) {
        print('🟢 Redirecting to: $location');
        response = await _client.get(
          Uri.parse(location),
          headers: headers,
        ).timeout(AppConstants.httpTimeout);
      }
    }

    print('🟢 Status: ${response.statusCode}');
    final bodyPreview = response.body.isNotEmpty
        ? response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)
        : '(empty)';
    print('🟢 Body: $bodyPreview');
    return _handleResponse(response);
  }

  // ============================================================
  // ✅ POST REQUEST
  // ============================================================
  Future<Map<String, dynamic>> post(
      String endpoint,
      Map<String, dynamic> data, {
        bool auth = true,
      }) async {
    String? token;
    if (auth) {
      token = await _requireValidToken();
      data['_token'] = token;
    }

    final uri = Uri.parse('${AppConstants.baseUrl}/$endpoint');

    print('🟢 POST URL: $uri');
    print('🟢 DATA: $data');

    var response = await _client.post(
      uri,
      headers: _headers(auth: auth, token: token),
      body: jsonEncode(data),
    ).timeout(AppConstants.httpTimeout);

    if (response.statusCode == 302 || response.statusCode == 301) {
      final location = response.headers['location'];
      if (location != null) {
        print('🟢 Redirecting to: $location');
        response = await _client.post(
          Uri.parse(location),
          headers: _headers(auth: auth, token: token),
          body: jsonEncode(data),
        ).timeout(AppConstants.httpTimeout);
      }
    }

    print('🟢 STATUS: ${response.statusCode}');
    final bodyPreview = response.body.isNotEmpty
        ? response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)
        : '(empty)';
    print('🟢 RESPONSE: $bodyPreview');

    if (!auth) {
      return _decodeResponse(response);
    }
    return _handleResponse(response);
  }

  // ============================================================
  // ✅ MULTIPART REQUEST
  // ============================================================
  Future<Map<String, dynamic>> postMultipart(
      String endpoint,
      Map<String, String> fields,
      File? file, {
        String fileField = 'photo',
      }) async {
    final token = await _requireValidToken();

    // Never mutate the caller's map: a const literal would throw, and a reused
    // map would silently accumulate stale tokens across retries.
    fields = Map<String, String>.of(fields)..['_token'] = token;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.baseUrl}/$endpoint'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields.addAll(fields);

    if (file != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    }

    print('🟢 Multipart URL: ${request.url}');

    var streamedResponse = await request.send().timeout(AppConstants.httpTimeout);
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 302 || response.statusCode == 301) {
      final location = response.headers['location'];
      if (location != null) {
        print('🟢 Redirecting to: $location');
        final redirectRequest = http.MultipartRequest(
          'POST',
          Uri.parse(location),
        );
        redirectRequest.headers.addAll(request.headers);
        redirectRequest.fields.addAll(fields);
        if (file != null) {
          redirectRequest.files.add(
            await http.MultipartFile.fromPath(fileField, file.path),
          );
        }

        final redirectResponse = await redirectRequest.send().timeout(
          AppConstants.httpTimeout,
        );
        response = await http.Response.fromStream(redirectResponse);
      }
    }

    print('🟢 Multipart Status: ${response.statusCode}');
    final bodyPreview = response.body.isNotEmpty
        ? response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)
        : '(empty)';
    print('🟢 Multipart Response: $bodyPreview');

    return _handleResponse(response);
  }

  // ============================================================
  // ✅ PUT REQUEST
  // ============================================================
  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> data) async {
    final token = await _requireValidToken();
    data['_token'] = token;

    final uri = Uri.parse('${AppConstants.baseUrl}/$endpoint');

    var response = await _client.put(
      uri,
      headers: _headers(token: token),
      body: jsonEncode(data),
    ).timeout(AppConstants.httpTimeout);

    if (response.statusCode == 302 || response.statusCode == 301) {
      final location = response.headers['location'];
      if (location != null) {
        print('🟢 Redirecting to: $location');
        response = await _client.put(
          Uri.parse(location),
          headers: _headers(token: token),
          body: jsonEncode(data),
        ).timeout(AppConstants.httpTimeout);
      }
    }

    return _handleResponse(response);
  }

  // ============================================================
  // ✅ AUTH
  // ============================================================
  Future<Map<String, dynamic>> login(String employeeId, String password, {bool remember = false}) async {
    return post('auth/login', {
      'employee_id': employeeId,
      'password': password,
      'remember': remember,
    }, auth: false);
  }

  /// Ends the server-side session, then clears the local one.
  ///
  /// Without the server call, `user_sessions.is_active` and `users.is_logged_in`
  /// stayed set after logout, so the admin panel kept showing the user online.
  Future<void> logout() async {
    try {
      await post('auth/logout', {});
    } catch (_) {
      // An expired or unreachable session still has to log out locally.
    }
    await clearToken();
  }

  // ============================================================
  // ✅ DASHBOARD
  // ============================================================
  Future<Map<String, dynamic>> getEmployeeDashboard() async {
    return get('dashboard/employee');
  }

  // ============================================================
  // ✅ ATTENDANCE
  // ============================================================
  Future<Map<String, dynamic>> getTodayAttendance() async {
    return get('attendance/today');
  }

  Future<Map<String, dynamic>> checkIn(
      double lat,
      double lng,
      String address,
      File? photo,
      String? photoBase64,
      ) async {
    final fields = {
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'address': address,
    };
    if (photoBase64 != null) fields['photo_base64'] = photoBase64;
    if (photo != null) return postMultipart('attendance/checkin', fields, photo);
    return post('attendance/checkin', {'latitude': lat, 'longitude': lng, 'address': address});
  }

  Future<Map<String, dynamic>> checkOut(
      double lat,
      double lng,
      String address,
      File? photo,
      String? photoBase64,
      ) async {
    final fields = {
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'address': address,
    };
    if (photoBase64 != null) fields['photo_base64'] = photoBase64;
    if (photo != null) return postMultipart('attendance/checkout', fields, photo);
    return post('attendance/checkout', {'latitude': lat, 'longitude': lng, 'address': address});
  }

  Future<Map<String, dynamic>> getAttendanceHistory([String? month]) async {
    return get('attendance/history/${month ?? ''}');
  }

  Future<Map<String, dynamic>> getDailyAttendance(String date) async {
    return get('attendance/daily/$date');
  }

  Future<Map<String, dynamic>> getMonthlyAttendance(String month) async {
    return get('attendance/monthly/$month');
  }

  Future<Map<String, dynamic>> getLateAttendance(String month) async {
    return get('attendance/late/$month');
  }

  Future<Map<String, dynamic>> getAbsentAttendance(String month) async {
    return get('attendance/absent/$month');
  }

  // ============================================================
  // ✅ PROFILE
  // ============================================================
  Future<Map<String, dynamic>> getProfile() async {
    return get('employee/profile');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return post('employee/update', data);
  }

  Future<Map<String, dynamic>> updateProfilePhoto(
    File file, {
    Map<String, String> fields = const {},
  }) async {
    // Copied because postMultipart adds the token to the map it is given, and
    // the default here is a const (unmodifiable) map — which made every photo
    // upload throw before it reached the network.
    return postMultipart('employee/update', Map<String, String>.of(fields), file,
        fileField: 'profile_photo');
  }

  Future<Map<String, dynamic>> changePassword(
      String currentPassword, String newPassword) async {
    return post('employee/change_password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // ============================================================
  // ✅ SETTINGS
  // ============================================================
  Future<Map<String, dynamic>> getOfficeSettings() async {
    return get('settings/office');
  }

  // ============================================================
  // ✅ WORK REPORTS
  // ============================================================
  Future<Map<String, dynamic>> getMyWorkReports([String? month]) async {
    return get('work_reports/my/${month ?? ''}');
  }

  Future<Map<String, dynamic>> createWorkReport(Map<String, dynamic> data) async {
    return post('work_reports/create', data);
  }

  // ============================================================
  // ✅ TASKS
  // ============================================================
  Future<Map<String, dynamic>> getMyTasks() async {
    return get('tasks/my');
  }

  Future<Map<String, dynamic>> completeTask(int id) async {
    return get('tasks/complete/$id');
  }

  // ============================================================
  // ✅ LEADS
  // ============================================================
  Future<Map<String, dynamic>> getMyLeads() async {
    return get('leads/my');
  }

  Future<Map<String, dynamic>> createLead(Map<String, dynamic> data) async {
    return post('leads/create', data);
  }

  Future<Map<String, dynamic>> updateLead(Map<String, dynamic> data) async {
    return post('leads/update', data);
  }

  Future<Map<String, dynamic>> deleteLead(Map<String, dynamic> data) async {
    return post('leads/delete', data);
  }

  Future<Map<String, dynamic>> searchLeads(Map<String, dynamic> data) async {
    return post('leads/search', data);
  }

  Future<Map<String, dynamic>> getLeadHistory(Map<String, dynamic> data) async {
    return post('leads/history', data);
  }

  // ============================================================
  // ✅ LEAVES
  // ============================================================
  Future<Map<String, dynamic>> applyLeave(Map<String, dynamic> data) async {
    return post('leaves/apply', data);
  }

  Future<Map<String, dynamic>> getMyLeaves() async {
    return get('leaves/my');
  }

  Future<Map<String, dynamic>> getLeaveBalance() async {
    return get('leaves/balance');
  }

  Future<Map<String, dynamic>> getLeaveDetails(Map<String, dynamic> data) async {
    return post('leaves/details', data);
  }

  // ============================================================
  // ✅ NOTIFICATIONS
  // ============================================================
  Future<Map<String, dynamic>> getNotifications() async {
    return get('notifications/list');
  }

  Future<Map<String, dynamic>> markNotificationRead(int id) async {
    return post('notifications/read/$id', {});
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    return post('notifications/read-all', {});
  }

  Future<Map<String, dynamic>> getUnreadCount() async {
    return get('notifications/unread_count');
  }

  // ============================================================
  // ✅ TELECALLER
  // ============================================================
  Future<Map<String, dynamic>> getTelecallerDashboard() async {
    return get('telecaller/dashboard');
  }

  // ============================================================
  // ✅ CAMPAIGNS
  // ============================================================
  Future<Map<String, dynamic>> getMyCampaigns() async {
    return get('campaigns/my');
  }

  Future<Map<String, dynamic>> createCampaign(Map<String, dynamic> data) async {
    return post('campaigns/create', data);
  }

  // ============================================================
  // ✅ CALL REPORTS
  // ============================================================
  Future<Map<String, dynamic>> getMyCallReports([String? date]) async {
    return get('call_reports/my/${date ?? ''}');
  }

  Future<Map<String, dynamic>> createCallReport(Map<String, dynamic> data) async {
    return post('call_reports/create', data);
  }

  // ============================================================
  // ✅ FOLLOW UPS
  // ============================================================
  Future<Map<String, dynamic>> getMyFollowUps() async {
    return get('follow_ups/my');
  }

  Future<Map<String, dynamic>> createFollowUp(Map<String, dynamic> data) async {
    return post('follow_ups/create', data);
  }

  // ============================================================
  // ✅ SALES
  // ============================================================
  Future<Map<String, dynamic>> getSalesLeads(Map<String, dynamic> data) async {
    return post('sales/list', data);
  }

  Future<Map<String, dynamic>> getSalesPipeline() async {
    return get('sales/pipeline');
  }

  Future<Map<String, dynamic>> updateSalesStage(Map<String, dynamic> data) async {
    return post('sales/update-stage', data);
  }

  Future<Map<String, dynamic>> createPayment(Map<String, dynamic> data) async {
    return post('sales/create-payment', data);
  }

  Future<Map<String, dynamic>> createProjectFromLead(Map<String, dynamic> data) async {
    return post('sales/create-project', data);
  }

  // ============================================================
  // ✅ MEETINGS - Fixed router-based calls
  // ============================================================

  Future<Map<String, dynamic>> getAllMeetingsForAll() async {
    return get('meetings/my');
  }

  Future<Map<String, dynamic>> getMyMeetings() async {
    return get('meetings/my');
  }

  Future<Map<String, dynamic>> getMeetingsList() async {
    return get('meetings/list');
  }

  Future<Map<String, dynamic>> createMeeting(Map<String, dynamic> data) async {
    return post('meetings/create', data);
  }

  Future<Map<String, dynamic>> updateMeeting(int id, Map<String, dynamic> data) async {
    return post('meetings/update/$id', data);
  }

  Future<Map<String, dynamic>> deleteMeeting(int id) async {
    return post('meetings/delete/$id', {});
  }

  Future<Map<String, dynamic>> getMeetingDetails(int id) async {
    return get('meetings/details/$id');
  }

  Future<Map<String, dynamic>> updateMeetingStatus(int id, String status) async {
    return post('meetings/update_status/$id', {'status': status});
  }

  Future<Map<String, dynamic>> markMeetingAttendance(int id, String attendance) async {
    return post('meetings/mark_attendance/$id', {'attendance': attendance});
  }

  // ============================================================
  // ✅ HR ACTIVITIES
  // ============================================================
  Future<Map<String, dynamic>> getMyHRActivities([String? month]) async {
    return get('hr_activities/my/${month ?? ''}');
  }

  Future<Map<String, dynamic>> createHRActivity(Map<String, dynamic> data) async {
    return post('hr_activities/create', data);
  }
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => message;
}