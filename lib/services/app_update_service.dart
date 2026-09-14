import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// What the server says about the newest release.
class AppUpdateInfo {
  final String latestVersion;
  final String minimumVersion;
  final String apkUrl;
  final String title;
  final String message;
  final String fileSize;
  final int fileSizeBytes;
  final String? sha256;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.minimumVersion,
    required this.apkUrl,
    required this.title,
    required this.message,
    required this.fileSize,
    required this.fileSizeBytes,
    required this.forceUpdate,
    this.sha256,
  });

  /// Null when the payload is unusable, so a malformed response can never
  /// produce an update prompt pointing at nothing.
  static AppUpdateInfo? fromJson(Map<String, dynamic> json) {
    final version = (json['latest_version'] ?? '').toString().trim();
    final url = (json['apk_url'] ?? '').toString().trim();

    if (version.isEmpty || url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;

    return AppUpdateInfo(
      latestVersion: version,
      minimumVersion: (json['minimum_version'] ?? '0.0.0').toString().trim(),
      apkUrl: url,
      title: (json['update_title'] ?? 'New Update Available').toString(),
      message: (json['update_message'] ?? '').toString(),
      fileSize: (json['file_size'] ?? '').toString(),
      fileSizeBytes: int.tryParse('${json['file_size_bytes'] ?? 0}') ?? 0,
      sha256: (json['sha256']?.toString().isNotEmpty ?? false)
          ? json['sha256'].toString()
          : null,
      forceUpdate: json['force_update'] == true ||
          json['force_update'] == 1 ||
          json['force_update'] == '1',
    );
  }
}

/// The outcome of a check, so callers do not re-derive it.
enum UpdateDecision { upToDate, optional, mandatory }

class AppUpdateCheck {
  final UpdateDecision decision;
  final AppUpdateInfo info;
  final String installedVersion;

  const AppUpdateCheck({
    required this.decision,
    required this.info,
    required this.installedVersion,
  });

  bool get isMandatory => decision == UpdateDecision.mandatory;
}

/// The single place that decides whether the app needs updating.
///
/// The app ships outside the Play Store, so it asks the backend on launch. All
/// of the version logic lives here rather than in any screen.
class AppUpdateService {
  AppUpdateService._internal();
  static final AppUpdateService instance = AppUpdateService._internal();

  static const String _dismissedKey = 'dismissed_update_version';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ));

  CancelToken? _downloadToken;

  /// Version actually installed, read from the package — never hardcoded.
  Future<String> installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Compares dotted versions numerically: 1.0.9 < 1.0.10, 1.9.0 < 1.10.0.
  ///
  /// Returns <0 when [a] is older, 0 when equal, >0 when newer. Missing
  /// segments count as zero, so 1.2 and 1.2.0 are the same version.
  static int compareVersions(String a, String b) {
    List<int> parse(String v) {
      final cleaned = v.trim().split('+').first.split('-').first;
      return cleaned
          .split('.')
          .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .toList();
    }

    final pa = parse(a);
    final pb = parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;

    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x < y ? -1 : 1;
    }
    return 0;
  }

  /// Asks the server what the newest release is.
  ///
  /// Returns null when there is nothing to do — including when the check itself
  /// fails, because a broken update check must never stop the app being used.
  Future<AppUpdateCheck?> check({bool ignoreDismissed = false}) async {
    try {
      final response = await _dio.get(
        '${AppConstants.baseUrl}/app_update',
        options: Options(
          responseType: ResponseType.json,
          // Anything other than 2xx is handled below rather than thrown.
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final body = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;

      if (body is! Map || body['success'] != true) return null;

      final info = AppUpdateInfo.fromJson(Map<String, dynamic>.from(body));
      if (info == null) return null;

      final current = await installedVersion();

      // Below the minimum, or explicitly forced, cannot be dismissed.
      final belowMinimum = compareVersions(current, info.minimumVersion) < 0;
      final newer = compareVersions(current, info.latestVersion) < 0;

      if (info.forceUpdate && newer || belowMinimum) {
        return AppUpdateCheck(
          decision: UpdateDecision.mandatory,
          info: info,
          installedVersion: current,
        );
      }

      if (!newer) return null;

      if (!ignoreDismissed && await _wasDismissed(info.latestVersion)) {
        return null;
      }

      return AppUpdateCheck(
        decision: UpdateDecision.optional,
        info: info,
        installedVersion: current,
      );
    } catch (e) {
      debugPrint('Update check failed, continuing without it: $e');
      return null;
    }
  }

  /// Remembers that this exact version was dismissed. A later release prompts again.
  Future<void> dismiss(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, version);
  }

  Future<bool> _wasDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(_dismissedKey);
    if (dismissed == null || dismissed.isEmpty) return false;
    // Only the same version stays dismissed; anything newer asks again.
    return compareVersions(dismissed, version) >= 0;
  }

  /// Downloads the APK, reporting progress as a 0..1 fraction.
  ///
  /// Throws with a readable message on failure so the dialog can offer a retry.
  Future<File> downloadApk(
    AppUpdateInfo info, {
    required void Function(int received, int total) onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/update-v${info.latestVersion}.apk');

    // A partial file from an interrupted attempt must not be reused.
    if (await file.exists()) await file.delete();

    _downloadToken = CancelToken();

    try {
      await _dio.download(
        info.apkUrl,
        file.path,
        cancelToken: _downloadToken,
        onReceiveProgress: onProgress,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          followRedirects: true,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
    } on DioException catch (e) {
      if (await file.exists()) await file.delete();
      if (CancelToken.isCancel(e)) throw Exception('Download cancelled');
      throw Exception(_readableDioError(e));
    }

    if (!await file.exists() || await file.length() == 0) {
      throw Exception('The downloaded file was empty. Please try again.');
    }

    // Integrity check: a corrupted or tampered APK must never reach the installer.
    if (info.sha256 != null) {
      final digest = await _sha256OfFile(file);
      if (digest.toLowerCase() != info.sha256!.toLowerCase()) {
        await file.delete();
        throw Exception(
            'The downloaded file failed its integrity check and was discarded.');
      }
    }

    return file;
  }

  void cancelDownload() {
    _downloadToken?.cancel('cancelled by user');
    _downloadToken = null;
  }

  Future<String> _sha256OfFile(File file) async {
    // Streamed, so even a large APK is never held in memory all at once.
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  String _readableDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The download timed out. Please check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'Download failed. Please check your internet connection and try again.';
      case DioExceptionType.badResponse:
        return 'The update file could not be found on the server (${e.response?.statusCode}).';
      default:
        return 'Download failed. Please check your internet connection and try again.';
    }
  }
}
