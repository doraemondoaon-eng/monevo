import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'local_file_driver_stub.dart';
export 'local_file_driver_stub.dart' show LocalFileDriver, InMemoryFileDriver;

LocalFileDriver createPlatformFileDriver() {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return InMemoryFileDriver();
  }
  return _IoLocalFileDriver();
}

class _IoLocalFileDriver implements LocalFileDriver {
  static const String _subDir = 'monevo_attachments';

  Future<Directory> _attachmentsDirectory() async {
    final Directory appDocs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(
      '${appDocs.path}${Platform.pathSeparator}$_subDir',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<String> copyToAppStorage({
    required String targetFileName,
    String? sourcePath,
    Uint8List? bytes,
  }) async {
    final Directory dir = await _attachmentsDirectory();
    final String destPath =
        '${dir.path}${Platform.pathSeparator}$targetFileName';
    final File destFile = File(destPath);

    // Always copy into the app's private storage directory (Section 3.3);
    // never keep a reference to a temporary gallery/picker URI.
    if (bytes != null && bytes.isNotEmpty) {
      await destFile.writeAsBytes(bytes, flush: true);
      return destFile.path;
    }
    if (sourcePath != null && sourcePath.isNotEmpty) {
      final File srcFile = File(sourcePath);
      final File copied = await srcFile.copy(destPath);
      return copied.path;
    }
    throw StateError('Neither sourcePath nor bytes provided for image copy');
  }

  @override
  Future<Uint8List?> readBytes(String storedPath) async {
    try {
      final File file = File(storedPath);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> exists(String storedPath) async {
    try {
      return await File(storedPath).exists();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> deleteFile(String storedPath) async {
    try {
      final File file = File(storedPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore file deletion errors if already removed by OS.
    }
  }

  @override
  Future<void> writeExternalFile(String targetPath, Uint8List bytes) async {
    final File file = File(targetPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
  }
}

