import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/update/apk_installer_stub.dart';
import 'package:monevo/core/update/app_update_service.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeInstaller implements ApkInstallerDriver {
  @override
  bool get isSupported => true;

  @override
  Future<String> downloadApk({
    required String url,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    return '/tmp/MONEVO-update.apk';
  }

  @override
  Future<ApkInstallResult> installApk(String filePath) async {
    return ApkInstallResult.launched;
  }
}

void main() {
  group('AppUpdateService', () {
    test('detects newer buildNumber from version.json', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions options) async {
        expect(options.uri.toString(), contains('version.json'));
        return ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'versionName': '1.0.15',
            'buildNumber': 15,
            'apkUrl':
                'https://github.com/doraemondoaon-eng/monevo/releases/download/v1.0.0/MONEVO.apk',
            'releaseNotes': 'New app icon & auto updater',
          }),
          200,
        );
      });

      final AppUpdateService service = AppUpdateService(
        dio: dio,
        installer: _FakeInstaller(),
        manifestUrl: 'https://example.com/version.json',
        currentBuildNumber: 10,
      );

      final AppUpdateCheckResult result = await service.checkForUpdate(
        silent: false,
      );
      expect(result.hasUpdate, isTrue);
      expect(result.updateInfo?.versionName, '1.0.15');
      expect(result.updateInfo?.buildNumber, 15);
    });

    test('returns hasUpdate=false when current build is up to date', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions _) async {
        return ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'versionName': '1.0.10',
            'buildNumber': 10,
            'apkUrl': 'https://example.com/MONEVO.apk',
            'releaseNotes': 'Latest',
          }),
          200,
        );
      });

      final AppUpdateService service = AppUpdateService(
        dio: dio,
        installer: _FakeInstaller(),
        manifestUrl: 'https://example.com/version.json',
        currentBuildNumber: 10,
      );

      final AppUpdateCheckResult result = await service.checkForUpdate(
        silent: false,
      );
      expect(result.hasUpdate, isFalse);
      expect(result.errorMessage, isNull);
    });

    test('handles 404 or network failure gracefully in silent vs manual mode', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((RequestOptions _) async {
        return ResponseBody.fromString('Not Found', 404);
      });

      final AppUpdateService service = AppUpdateService(
        dio: dio,
        installer: _FakeInstaller(),
        manifestUrl: 'https://example.com/version.json',
        currentBuildNumber: 1,
      );

      final AppUpdateCheckResult silentRes = await service.checkForUpdate(
        silent: true,
      );
      expect(silentRes.hasUpdate, isFalse);
      expect(silentRes.errorMessage, isNull);

      final AppUpdateCheckResult manualRes = await service.checkForUpdate(
        silent: false,
      );
      expect(manualRes.hasUpdate, isFalse);
      expect(manualRes.errorMessage, isNotNull);
    });
  });
}

