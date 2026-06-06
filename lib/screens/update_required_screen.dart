import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:audit_pro_mobile/logging/apm_feedback.dart';

import '../apm/models/update_check_result.dart';
import '../apm/services/apk_download_service.dart';

class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({
    super.key,
    required this.checkResult,
    required this.apkDownloadService,
    required this.continueRouteName,
    required this.onRecheck,
  });

  final UpdateCheckResult checkResult;
  final ApkDownloadService apkDownloadService;
  final String continueRouteName;
  final Future<UpdateCheckResult> Function() onRecheck;

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  static const MethodChannel _installerChannel = MethodChannel(
    'com.auditproltd.auditpromobile/installer',
  );

  bool _isChecking = false;
  bool _isDownloading = false;
  double? _downloadProgress;

  Future<void> _installApk(String localPath) async {
    if (Platform.isAndroid) {
      await _installerChannel.invokeMethod('installApk', {'path': localPath});
      return;
    }

    await OpenFilex.open(
      localPath,
      type: 'application/vnd.android.package-archive',
    );
  }

  Future<void> _downloadAndInstall(BuildContext context) async {
    if (_isDownloading) return;

    final downloadUrl = widget.checkResult.downloadUrl;
    if (downloadUrl == null || downloadUrl.trim().isEmpty) {
      ApmFeedback.warning(context, 'No download link available yet.');
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = null;
    });

    try {
      final result = await widget.apkDownloadService.downloadApk(
        downloadUrl: downloadUrl,
        versionName: widget.checkResult.latestVersionName,
        versionCode: widget.checkResult.latestVersionCode,
        onProgress: (received, total) {
          if (!mounted) return;
          if (total <= 0) {
            setState(() => _downloadProgress = null);
            return;
          }
          setState(() => _downloadProgress = received / total);
        },
      );

      if (!mounted) return;

      final file = File(result.localPath);
      if (!await file.exists()) {
        ApmFeedback.error(context, 'Download failed: file not found.');
        return;
      }

      // Prefer native installer on Android (FileProvider + content URI).
      try {
        await _installApk(result.localPath);
      } on PlatformException catch (e) {
        if (!mounted) return;

        // Android fallback: try OpenFilex if the native path fails.
        final openResult = await OpenFilex.open(
          result.localPath,
          type: 'application/vnd.android.package-archive',
        );

        if (!mounted) return;
        if (openResult.type != ResultType.done) {
          ApmFeedback.error(
            context,
            'Unable to start installer: ${e.message ?? e.code}',
          );
        }
      } catch (e) {
        if (!mounted) return;
        ApmFeedback.error(context, 'Unable to start installer: $e');
      }
    } catch (e) {
      if (!mounted) return;
      ApmFeedback.error(context, 'Download failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _recheck() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final navigator = Navigator.of(context);

    try {
      final result = await widget.onRecheck();
      if (!mounted) return;

      if (!result.isUpdateRequired) {
        navigator.pushReplacementNamed(widget.continueRouteName);
        return;
      }

      ApmFeedback.warning(context, 'Update still required.');
    } catch (_) {
      if (!mounted) return;
      ApmFeedback.error(context, 'Recheck failed. Try again later.');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.checkResult;

    return Scaffold(
      appBar: AppBar(title: const Text('Update Required')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A newer version of this app is required to continue.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Latest: ${result.latestVersionName} (${result.latestVersionCode})',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isDownloading
                        ? null
                        : () => _downloadAndInstall(context),
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt),
                    label: Text(
                      _isDownloading
                          ? (_downloadProgress == null
                                ? 'Downloading...'
                                : 'Downloading ${(100 * _downloadProgress!).toStringAsFixed(0)}%')
                          : 'Download & install',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isChecking ? null : _recheck,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      _isChecking ? 'Checking...' : 'I updated, recheck',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Release notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (result.releaseNotes != null &&
                  result.releaseNotes!.isNotEmpty)
                Text(result.releaseNotes!)
              else
                const Text('Release notes not available yet.'),
            ],
          ),
        ),
      ),
    );
  }
}
