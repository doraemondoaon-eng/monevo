import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'apk_installer_stub.dart';

export 'apk_installer_stub.dart' show ApkInstallResult, ApkInstallerDriver;

ApkInstallerDriver createPlatformApkInstaller() => _AndroidApkInstallerDriver();

class _AndroidApkInstallerDriver implements ApkInstallerDriver {
  static const MethodChannel _channel = MethodChannel('com.monevo.app/updater');

  @override
  bool get isSupported =>
      !Platform.environment.containsKey('FLUTTER_TEST') && Platform.isAndroid;

  @override
  Future<String> downloadApk({
    required String url,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    final Directory cacheDir = await getTemporaryDirectory();
    final File targetFile = File(
      '${cacheDir.path}${Platform.pathSeparator}MONEVO-update.apk',
    );
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    final Dio downloadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 5),
        followRedirects: true,
        maxRedirects: 8,
      ),
    );

    await downloadDio.download(
      url,
      targetFile.path,
      onReceiveProgress: (int received, int total) {
        onProgress(received, total);
      },
    );

    if (!await targetFile.exists() || await targetFile.length() == 0) {
      throw StateError('Downloaded APK file is empty');
    }
    return targetFile.path;
  }

  @override
  Future<ApkInstallResult> installApk(String filePath) async {
    if (!isSupported) {
      return ApkInstallResult.unsupported;
    }
    try {
      final String? status = await _channel.invokeMethod<String>(
        'installApk',
        <String, dynamic>{'path': filePath},
      );
      switch (status) {
        case 'LAUNCHED':
          return ApkInstallResult.launched;
        case 'PERMISSION_REQUIRED':
          return ApkInstallResult.permissionRequired;
        default:
          return ApkInstallResult.failed;
      }
    } on PlatformException {
      return ApkInstallResult.failed;
    }
  }
}
