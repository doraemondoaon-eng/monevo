import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'apk_installer.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionName,
    required this.buildNumber,
    required this.apkUrl,
    required this.releaseNotes,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      versionName: (json['versionName'] ?? '').toString().trim(),
      buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 0,
      apkUrl: (json['apkUrl'] ?? '').toString().trim(),
      releaseNotes: (json['releaseNotes'] ?? '').toString().trim(),
    );
  }

  final String versionName;
  final int buildNumber;
  final String apkUrl;
  final String releaseNotes;

  bool isNewerThan(int currentBuildNumber) =>
      buildNumber > currentBuildNumber && apkUrl.isNotEmpty;
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.hasUpdate,
    this.updateInfo,
    this.errorMessage,
  });

  final bool hasUpdate;
  final AppUpdateInfo? updateInfo;
  final String? errorMessage;
}

class AppUpdateService {
  AppUpdateService({
    Dio? dio,
    ApkInstallerDriver? installer,
    String? manifestUrl,
    int? currentBuildNumber,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 10),
               followRedirects: true,
               maxRedirects: 5,
             ),
           ),
       _installer = installer ?? createPlatformApkInstaller(),
       _manifestUrl = manifestUrl ?? AppConfig.updateManifestUrl,
       _currentBuildNumber = currentBuildNumber ?? AppConfig.appBuildNumber;

  final Dio _dio;
  final ApkInstallerDriver _installer;
  final String _manifestUrl;
  final int _currentBuildNumber;

  bool get isPlatformSupported => _installer.isSupported;

  Future<AppUpdateCheckResult> checkForUpdate({bool silent = true}) async {
    try {
      final String separator = _manifestUrl.contains('?') ? '&' : '?';
      final String url =
          '$_manifestUrl${separator}t=${DateTime.now().millisecondsSinceEpoch}';
      final Response<dynamic> response = await _dio.get<dynamic>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final String rawBody = (response.data ?? '').toString().trim();
      if (rawBody.isEmpty) {
        return const AppUpdateCheckResult(hasUpdate: false);
      }
      final Object? decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) {
        return const AppUpdateCheckResult(hasUpdate: false);
      }
      final AppUpdateInfo info = AppUpdateInfo.fromJson(decoded);
      if (info.isNewerThan(_currentBuildNumber)) {
        return AppUpdateCheckResult(
          hasUpdate: true,
          updateInfo: info,
        );
      }
      return AppUpdateCheckResult(
        hasUpdate: false,
        updateInfo: info,
      );
    } on DioException catch (e) {
      if (silent) {
        return const AppUpdateCheckResult(hasUpdate: false);
      }
      return AppUpdateCheckResult(
        hasUpdate: false,
        errorMessage: e.message ?? 'Network error while checking updates',
      );
    } catch (e) {
      if (silent) {
        return const AppUpdateCheckResult(hasUpdate: false);
      }
      return AppUpdateCheckResult(
        hasUpdate: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<String> downloadUpdateApk({
    required String apkUrl,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) {
    return _installer.downloadApk(
      url: apkUrl,
      onProgress: onProgress,
    );
  }

  Future<ApkInstallResult> installDownloadedApk(String filePath) {
    return _installer.installApk(filePath);
  }
}

final Provider<AppUpdateService> appUpdateServiceProvider =
    Provider<AppUpdateService>((Ref ref) {
      return AppUpdateService();
    });

