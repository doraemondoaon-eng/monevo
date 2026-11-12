import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../config/app_config.dart';
import '../theme/app_colors.dart';
import 'apk_installer.dart';
import 'app_update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.info,
    required this.service,
  });

  final AppUpdateInfo info;
  final AppUpdateService service;

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo info,
    required AppUpdateService service,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppUpdateDialog(info: info, service: service),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _downloadedApkPath;
  String? _statusMessage;
  bool _permissionNeeded = false;

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _receivedBytes = 0;
      _totalBytes = 0;
      _statusMessage = null;
      _permissionNeeded = false;
    });

    try {
      final String filePath = await widget.service.downloadUpdateApk(
        apkUrl: widget.info.apkUrl,
        onProgress: (int received, int total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _receivedBytes = received;
            _totalBytes = total;
          });
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isDownloading = false;
        _downloadedApkPath = filePath;
      });
      await _triggerInstall(filePath);
    } catch (e) {
      if (!mounted) {
        return;
      }
      final AppStrings strings = AppStrings.of(context);
      setState(() {
        _isDownloading = false;
        _statusMessage = strings.tr(
          'ดาวน์โหลดไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
          'Download failed. Please try again.',
        );
      });
    }
  }

  Future<void> _triggerInstall(String filePath) async {
    final AppStrings strings = AppStrings.of(context);
    final ApkInstallResult result = await widget.service.installDownloadedApk(
      filePath,
    );
    if (!mounted) {
      return;
    }
    if (result == ApkInstallResult.permissionRequired) {
      setState(() {
        _permissionNeeded = true;
        _statusMessage = strings.tr(
          'กรุณาเปิดสวิตช์ "อนุญาตจากแหล่งนี้" ในหน้าต่างที่เด้งขึ้นมา แล้วกลับมากดปุ่ม "ติดตั้งอัปเดต" อีกครั้ง (ทำแค่ครั้งแรกครั้งเดียว)',
          'Please enable "Allow from this source" in the Settings screen, then return and tap "Install Update".',
        );
      });
      return;
    }
    if (result == ApkInstallResult.failed) {
      setState(() {
        _statusMessage = strings.tr(
          'ไม่สามารถเปิดหน้าติดตั้งอัปเดตได้ กรุณาลองกดอีกครั้ง',
          'Could not open Android installer. Please try again.',
        );
      });
    }
  }

  String _formatMb(int bytes) {
    final double mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    final double? progress = (_totalBytes > 0)
        ? (_receivedBytes / _totalBytes).clamp(0.0, 1.0)
        : null;
    final int percent = progress != null ? (progress * 100).round() : 0;

    return AlertDialog(
      icon: const Icon(
        Icons.system_update_rounded,
        size: 40,
        color: AppColors.primaryEmerald,
      ),
      title: Text(
        strings.tr('พบอัปเดตเวอร์ชันใหม่!', 'New Update Available!'),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            strings.tr(
              'เวอร์ชันใหม่ v${widget.info.versionName} (Build ${widget.info.buildNumber}) พร้อมติดตั้งทับแอปเดิมแล้ว ข้อมูลในเครื่องไม่หาย',
              'Version v${widget.info.versionName} (Build ${widget.info.buildNumber}) is ready to update over your current app.',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            strings.tr(
              'เวอร์ชันปัจจุบัน: v${AppConfig.appVersion} (Build ${AppConfig.appBuildNumber})',
              'Current version: v${AppConfig.appVersion} (Build ${AppConfig.appBuildNumber})',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (widget.info.releaseNotes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(150),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.info.releaseNotes,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          if (_isDownloading) ...<Widget>[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              _totalBytes > 0
                  ? strings.tr(
                      'กำลังดาวน์โหลด... $percent% (${_formatMb(_receivedBytes)} / ${_formatMb(_totalBytes)})',
                      'Downloading... $percent% (${_formatMb(_receivedBytes)} / ${_formatMb(_totalBytes)})',
                    )
                  : strings.tr(
                      'กำลังเชื่อมต่อเพื่อดาวน์โหลดไฟล์...',
                      'Connecting to download update...',
                    ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_statusMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _statusMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _permissionNeeded
                    ? AppColors.primaryEmerald
                    : AppColors.expense,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.tr('ไว้ทีหลัง', 'Later')),
          ),
        if (!_isDownloading && _downloadedApkPath != null)
          FilledButton.icon(
            onPressed: () => _triggerInstall(_downloadedApkPath!),
            icon: const Icon(Icons.install_mobile_rounded),
            label: Text(strings.tr('ติดตั้งอัปเดต', 'Install Update')),
          )
        else if (!_isDownloading)
          FilledButton.icon(
            onPressed: _startDownloadAndInstall,
            icon: const Icon(Icons.download_rounded),
            label: Text(strings.tr('อัปเดตเลย', 'Update Now')),
          ),
      ],
    );
  }
}
