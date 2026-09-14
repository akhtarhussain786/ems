import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/app_update_service.dart';

/// The update prompt, download progress and installer hand-off.
///
/// A mandatory update cannot be dismissed: there is no close control, the
/// barrier ignores taps and the system back button is blocked.
class UpdateDialog extends StatefulWidget {
  final AppUpdateCheck check;

  const UpdateDialog({super.key, required this.check});

  /// Shows the prompt. Returns once the user dismisses it, which a mandatory
  /// update never allows.
  static Future<void> show(BuildContext context, AppUpdateCheck check) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !check.isMandatory,
      builder: (_) => UpdateDialog(check: check),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _Stage { prompt, downloading, failed, ready }

class _UpdateDialogState extends State<UpdateDialog> {
  static const Color _navy = Color(0xFF1E3A5F);

  _Stage _stage = _Stage.prompt;
  double _progress = 0;
  int _received = 0;
  int _total = 0;
  String _error = '';
  File? _apk;

  AppUpdateInfo get _info => widget.check.info;
  bool get _mandatory => widget.check.isMandatory;

  String _mb(int bytes) => bytes <= 0 ? '' : '${(bytes / 1048576).toStringAsFixed(1)} MB';

  Future<void> _startDownload() async {
    setState(() {
      _stage = _Stage.downloading;
      _progress = 0;
      _received = 0;
      _total = _info.fileSizeBytes;
      _error = '';
    });

    try {
      final file = await AppUpdateService.instance.downloadApk(
        _info,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total > 0 ? total : _info.fileSizeBytes;
            _progress = total > 0 ? received / total : 0;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _apk = file;
        _stage = _Stage.ready;
      });
      await _install();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Hands the file to Android's package installer. Installation is never
  /// silent — the user confirms in the system dialog.
  Future<void> _install() async {
    final apk = _apk;
    if (apk == null) return;

    // Android 8+ requires per-app consent to install from this source.
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final asked = await Permission.requestInstallPackages.request();
        if (!asked.isGranted) {
          if (!mounted) return;
          setState(() {
            _stage = _Stage.failed;
            _error = 'Allow "Install unknown apps" for this app, then tap Retry.';
          });
          return;
        }
      }
    }

    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );

    if (result.type != ResultType.done && mounted) {
      setState(() {
        _stage = _Stage.failed;
        _error = 'Could not open the installer: ${result.message}';
      });
    }
  }

  void _later() {
    AppUpdateService.instance.dismiss(_info.latestVersion);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Blocks the hardware back button for a mandatory update.
    return PopScope(
      canPop: !_mandatory,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: switch (_stage) {
                  _Stage.prompt => _promptBody(),
                  _Stage.downloading => _downloadingBody(),
                  _Stage.failed => _failedBody(),
                  _Stage.ready => _readyBody(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_navy, Color(0xFF2A5298)]),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _mandatory ? Icons.priority_high_rounded : Icons.system_update_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _mandatory ? 'Update Required' : _info.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _promptBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Text(
          _mandatory
              ? 'Your current version is no longer supported. Please update the application to continue.'
              : (_info.message.isNotEmpty
                  ? _info.message
                  : 'A new version of the app is available.'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
        ),
        const SizedBox(height: 16),
        _versionRow(),
        const SizedBox(height: 20),
        Row(
          children: [
            if (!_mandatory) ...[
              Expanded(
                child: TextButton(
                  onPressed: _later,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Later'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: _mandatory ? 1 : 1,
              child: ElevatedButton(
                onPressed: _startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Update Now',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _versionRow() {
    Widget cell(String label, String value, Color colour) => Expanded(
          child: Column(
            children: [
              Text(label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: colour)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          cell('Current Version', widget.check.installedVersion, Colors.grey[700]!),
          Container(width: 1, height: 28, color: Colors.grey[300]),
          cell('Latest Version', _info.latestVersion, _navy),
        ],
      ),
    );
  }

  Widget _downloadingBody() {
    final pct = (_progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 14),
        Text('Downloading update…',
            style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            minHeight: 8,
            backgroundColor: const Color(0xFFF0F4F8),
            valueColor: const AlwaysStoppedAnimation<Color>(_navy),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$pct%',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: _navy)),
            Text(
              _total > 0 ? '${_mb(_received)} of ${_mb(_total)}' : _mb(_received),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!_mandatory)
          TextButton(
            onPressed: () {
              AppUpdateService.instance.cancelDownload();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('Cancel'),
          ),
      ],
    );
  }

  Widget _failedBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Icon(Icons.error_outline_rounded, color: Colors.red[400], size: 34),
        const SizedBox(height: 10),
        Text(
          _error.isNotEmpty
              ? _error
              : 'Download failed. Please check your internet connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            // Cancel must never be an escape hatch from a mandatory update.
            if (!_mandatory) ...[
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: _startDownload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _readyBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Icon(Icons.check_circle_rounded, color: Colors.green[500], size: 34),
        const SizedBox(height: 10),
        Text(
          'Download complete. Confirm the installation when Android asks.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _install,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Open Installer',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
