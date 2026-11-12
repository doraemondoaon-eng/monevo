export 'apk_installer_stub.dart' show ApkInstallResult, ApkInstallerDriver;
export 'apk_installer_stub.dart'
    if (dart.library.io) 'apk_installer_io.dart'
    show createPlatformApkInstaller;

