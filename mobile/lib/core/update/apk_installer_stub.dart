enum ApkInstallResult {
  launched,
  permissionRequired,
  unsupported,
  failed,
}

abstract class ApkInstallerDriver {
  bool get isSupported;

  Future<String> downloadApk({
    required String url,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  });

  Future<ApkInstallResult> installApk(String filePath);
}

ApkInstallerDriver createPlatformApkInstaller() => _StubApkInstallerDriver();

class _StubApkInstallerDriver implements ApkInstallerDriver {
  @override
  bool get isSupported => false;

  @override
  Future<String> downloadApk({
    required String url,
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) {
    throw UnsupportedError('APK download is only supported on Android');
  }

  @override
  Future<ApkInstallResult> installApk(String filePath) async {
    return ApkInstallResult.unsupported;
  }
}

