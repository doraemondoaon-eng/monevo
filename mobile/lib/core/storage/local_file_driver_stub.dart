import 'dart:typed_data';

/// Platform-neutral interface for storing transaction attachment files inside
/// the application's private Local Application Storage directory.
abstract class LocalFileDriver {
  /// Copies [bytes] (or the file at [sourcePath]) into the app's private
  /// attachments directory under [targetFileName] and returns the absolute
  /// path inside Local Application Storage.
  Future<String> copyToAppStorage({
    required String targetFileName,
    String? sourcePath,
    Uint8List? bytes,
  });

  /// Reads the file bytes from the app's private storage at [storedPath].
  Future<Uint8List?> readBytes(String storedPath);

  /// Checks whether the file at [storedPath] exists in app storage.
  Future<bool> exists(String storedPath);

  /// Deletes the file at [storedPath] from app storage if it exists.
  Future<void> deleteFile(String storedPath);

  /// Writes [bytes] to an explicit user-selected file path on the device.
  Future<void> writeExternalFile(String targetPath, Uint8List bytes);
}

LocalFileDriver createPlatformFileDriver() => InMemoryFileDriver();

class InMemoryFileDriver implements LocalFileDriver {
  final Map<String, Uint8List> _files = <String, Uint8List>{};

  @override
  Future<String> copyToAppStorage({
    required String targetFileName,
    String? sourcePath,
    Uint8List? bytes,
  }) async {
    final String key = 'app_storage/monevo_attachments/$targetFileName';
    _files[key] = bytes ?? Uint8List(0);
    return key;
  }

  @override
  Future<Uint8List?> readBytes(String storedPath) async => _files[storedPath];

  @override
  Future<bool> exists(String storedPath) async =>
      _files.containsKey(storedPath);

  @override
  Future<void> deleteFile(String storedPath) async {
    _files.remove(storedPath);
  }

  @override
  Future<void> writeExternalFile(String targetPath, Uint8List bytes) async {
    _files[targetPath] = bytes;
  }
}

