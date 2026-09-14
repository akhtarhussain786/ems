class AppConstants {
  static const String appName = 'EAMS';
  static const String appVersion = '1.0.0';
  static const int version = 1;

  static const String baseUrl = 'https://ems.yatharthinstitution.in/ems/backend';
  static const String tokenKey = 'auth_token';
  static const String loginKey = 'auth_token';
  static const String rememberKey = 'remember_login';
  static const String userKey = 'user_data';
  static const String savedEmployeeIdKey = 'saved_employee_id';
  static const String tokenExpiryKey = 'token_expiry';
  static const String loginTimestampKey = 'login_timestamp';
  static const String autoLogoutFlagKey = 'was_auto_logout';
  static const String autoLogoutReasonKey = 'auto_logout_reason';

  static const String loginRoute = '/login';

  static const Duration httpTimeout = Duration(seconds: 15);

  /// Uploads get longer than an ordinary call.
  ///
  /// Fifteen seconds is fine for a JSON request, but a check-in carries a
  /// photo and is taken by field staff on whatever signal they happen to have.
  /// The same limit was cutting those off mid-transfer, and the attendance was
  /// simply lost — the employee saw "Failed to upload" and no record was made.
  static const Duration uploadTimeout = Duration(seconds: 90);
}
