import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_file_driver.dart';

enum LocalImagePickSource {
  photoLibrary,
  camera,
  filePicker,
}

class LocalImagePermissionException implements Exception {
  const LocalImagePermissionException(this.code, this.message);

  final String code;
  final String message;
}

class PickedLocalImage {
  const PickedLocalImage({
    required this.fileName,
    required this.bytes,
    this.sourcePath,
  });

  final String fileName;
  final Uint8List bytes;
  final String? sourcePath;

  int get sizeBytes => bytes.lengthInBytes;
}

class LocalImageAttachment {
  const LocalImageAttachment({
    required this.transactionId,
    required this.storedPath,
    required this.originalFileName,
    required this.sizeBytes,
    required this.attachedAt,
  });

  factory LocalImageAttachment.fromJson(Map<String, dynamic> json) {
    return LocalImageAttachment(
      transactionId: (json['transactionId'] ?? '').toString(),
      storedPath: (json['storedPath'] ?? '').toString(),
      originalFileName: (json['originalFileName'] ?? 'image.jpg').toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      attachedAt:
          DateTime.tryParse((json['attachedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String transactionId;
  final String storedPath;
  final String originalFileName;
  final int sizeBytes;
  final DateTime attachedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'transactionId': transactionId,
    'storedPath': storedPath,
    'originalFileName': originalFileName,
    'sizeBytes': sizeBytes,
    'attachedAt': attachedAt.toUtc().toIso8601String(),
  };
}

/// Section 3.3 Local Image Storage:
/// Manages transaction images (slips, receipts, payment proofs, documents)
/// strictly inside the device's private Local Application Storage.
/// Images are NEVER uploaded to the server or PostgreSQL.
class LocalImageStorageService {
  LocalImageStorageService({
    SharedPreferences? prefs,
    LocalFileDriver? fileDriver,
    ImagePicker? imagePicker,
  }) : _prefs = prefs,
       _fileDriver = fileDriver ?? createPlatformFileDriver(),
       _imagePicker = imagePicker ?? ImagePicker();

  SharedPreferences? _prefs;
  final LocalFileDriver _fileDriver;
  final ImagePicker _imagePicker;

  static const String _registryKey = 'monevo_local_tx_images_v1';

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Map<String, LocalImageAttachment>> loadAllMappings() async {
    try {
      final SharedPreferences prefs = await _instance();
      final String? raw = prefs.getString(_registryKey);
      if (raw == null || raw.isEmpty) {
        return <String, LocalImageAttachment>{};
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, LocalImageAttachment>{};
      }
      final Map<String, LocalImageAttachment> result =
          <String, LocalImageAttachment>{};
      for (final MapEntry<String, dynamic> entry in decoded.entries) {
        if (entry.value is Map<String, dynamic>) {
          result[entry.key] = LocalImageAttachment.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
      return result;
    } catch (_) {
      return <String, LocalImageAttachment>{};
    }
  }

  Future<void> _saveAllMappings(
    Map<String, LocalImageAttachment> mappings,
  ) async {
    final SharedPreferences prefs = await _instance();
    final Map<String, dynamic> serializable = <String, dynamic>{
      for (final MapEntry<String, LocalImageAttachment> e in mappings.entries)
        e.key: e.value.toJson(),
    };
    await prefs.setString(_registryKey, jsonEncode(serializable));
  }

  /// Opens the native iOS/Android picker (Photo Library, Camera, or File Picker),
  /// reads the selected image bytes immediately so the app does not depend on
  /// a temporary content/photo URI, and returns a [PickedLocalImage].
  Future<PickedLocalImage?> pickImageFromDevice(
    LocalImagePickSource source,
  ) async {
    try {
      if (source == LocalImagePickSource.filePicker) {
        final FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (result == null || result.files.isEmpty) {
          return null;
        }
        final PlatformFile file = result.files.first;
        Uint8List? bytes = file.bytes;
        if ((bytes == null || bytes.isEmpty) && file.path != null) {
          bytes = await _fileDriver.readBytes(file.path!);
        }
        if (bytes == null || bytes.isEmpty) {
          return null;
        }
        return PickedLocalImage(
          fileName: file.name.isNotEmpty ? file.name : 'receipt.jpg',
          bytes: bytes,
          sourcePath: file.path,
        );
      }

      final XFile? xfile = await _imagePicker.pickImage(
        source: source == LocalImagePickSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (xfile == null) {
        return null;
      }
      final Uint8List bytes = await xfile.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      return PickedLocalImage(
        fileName: xfile.name.isNotEmpty ? xfile.name : 'slip.jpg',
        bytes: bytes,
        sourcePath: xfile.path,
      );
    } on PlatformException catch (e) {
      throw LocalImagePermissionException(
        e.code,
        e.message ?? 'Permission denied while accessing device files/photos',
      );
    }
  }

  /// Copies [picked] into the app's private storage directory, deletes any
  /// previous image file for [transactionId], and saves the mapping in Local Storage.
  Future<LocalImageAttachment> saveImageForTransaction({
    required String transactionId,
    required PickedLocalImage picked,
  }) async {
    final Map<String, LocalImageAttachment> mappings = await loadAllMappings();
    final LocalImageAttachment? previous = mappings[transactionId];

    final String ext = _sanitizeExtension(picked.fileName);
    final int ts = DateTime.now().millisecondsSinceEpoch;
    final String safeTxId = transactionId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '',
    );
    final String targetFileName = 'tx_${safeTxId}_$ts.$ext';

    final String storedPath = await _fileDriver.copyToAppStorage(
      targetFileName: targetFileName,
      sourcePath: picked.sourcePath,
      bytes: picked.bytes,
    );

    if (previous != null && previous.storedPath != storedPath) {
      await _fileDriver.deleteFile(previous.storedPath);
    }

    final LocalImageAttachment attachment = LocalImageAttachment(
      transactionId: transactionId,
      storedPath: storedPath,
      originalFileName: picked.fileName,
      sizeBytes: picked.sizeBytes,
      attachedAt: DateTime.now(),
    );

    mappings[transactionId] = attachment;
    await _saveAllMappings(mappings);
    return attachment;
  }

  /// Reads the stored image bytes from the app's private storage directory.
  Future<Uint8List?> readAttachmentBytes(LocalImageAttachment attachment) {
    return _fileDriver.readBytes(attachment.storedPath);
  }

  /// Removes the transaction-to-image mapping. If [deleteLocalFile] is true,
  /// also deletes the copied image file from Local Application Storage.
  Future<void> removeAttachmentForTransaction(
    String transactionId, {
    bool deleteLocalFile = true,
  }) async {
    final Map<String, LocalImageAttachment> mappings = await loadAllMappings();
    final LocalImageAttachment? existing = mappings.remove(transactionId);
    if (existing != null) {
      await _saveAllMappings(mappings);
      if (deleteLocalFile) {
        await _fileDriver.deleteFile(existing.storedPath);
      }
    }
  }

  /// Section 13 Offline Sync Support:
  /// Rebinds a locally attached image from an offline temporary transaction ID
  /// to the permanent server UUID once the offline queue flushes to the backend.
  Future<LocalImageAttachment?> rebindTransactionId({
    required String oldTransactionId,
    required String newTransactionId,
  }) async {
    if (oldTransactionId == newTransactionId) {
      return null;
    }
    final Map<String, LocalImageAttachment> mappings = await loadAllMappings();
    final LocalImageAttachment? existing = mappings.remove(oldTransactionId);
    if (existing == null) {
      return null;
    }
    final LocalImageAttachment rebound = LocalImageAttachment(
      transactionId: newTransactionId,
      storedPath: existing.storedPath,
      originalFileName: existing.originalFileName,
      sizeBytes: existing.sizeBytes,
      attachedAt: existing.attachedAt,
    );
    mappings[newTransactionId] = rebound;
    await _saveAllMappings(mappings);
    return rebound;
  }

  String _sanitizeExtension(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) {
      return 'jpg';
    }
    final String raw = fileName.substring(dot + 1).toLowerCase();
    const Set<String> allowed = <String>{
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'gif',
    };
    return allowed.contains(raw) ? raw : 'jpg';
  }
}

class LocalImageAttachmentsController
    extends StateNotifier<Map<String, LocalImageAttachment>> {
  LocalImageAttachmentsController(this._service)
    : super(const <String, LocalImageAttachment>{}) {
    reload();
  }

  final LocalImageStorageService _service;

  Future<void> reload() async {
    final Map<String, LocalImageAttachment> loaded =
        await _service.loadAllMappings();
    if (mounted) {
      state = loaded;
    }
  }

  LocalImageAttachment? getForTransaction(String? transactionId) {
    if (transactionId == null) {
      return null;
    }
    return state[transactionId];
  }

  Future<PickedLocalImage?> pickImage(LocalImagePickSource source) {
    return _service.pickImageFromDevice(source);
  }

  Future<LocalImageAttachment> attachImage({
    required String transactionId,
    required PickedLocalImage picked,
  }) async {
    final LocalImageAttachment saved = await _service.saveImageForTransaction(
      transactionId: transactionId,
      picked: picked,
    );
    if (mounted) {
      state = <String, LocalImageAttachment>{
        ...state,
        transactionId: saved,
      };
    }
    return saved;
  }

  Future<Uint8List?> readBytes(LocalImageAttachment attachment) {
    return _service.readAttachmentBytes(attachment);
  }

  Future<void> removeForTransaction(
    String transactionId, {
    bool deleteLocalFile = true,
  }) async {
    await _service.removeAttachmentForTransaction(
      transactionId,
      deleteLocalFile: deleteLocalFile,
    );
    if (mounted) {
      final Map<String, LocalImageAttachment> next =
          Map<String, LocalImageAttachment>.from(state)
            ..remove(transactionId);
      state = next;
    }
  }

  Future<void> rebindTransactionId({
    required String oldTransactionId,
    required String newTransactionId,
  }) async {
    final LocalImageAttachment? rebound = await _service.rebindTransactionId(
      oldTransactionId: oldTransactionId,
      newTransactionId: newTransactionId,
    );
    if (rebound != null && mounted) {
      final Map<String, LocalImageAttachment> next =
          Map<String, LocalImageAttachment>.from(state)
            ..remove(oldTransactionId);
      next[newTransactionId] = rebound;
      state = next;
    }
  }
}

final Provider<LocalImageStorageService> localImageStorageServiceProvider =
    Provider<LocalImageStorageService>((Ref ref) {
      return LocalImageStorageService();
    });

final StateNotifierProvider<
  LocalImageAttachmentsController,
  Map<String, LocalImageAttachment>
>
localImageAttachmentsProvider =
    StateNotifierProvider<
      LocalImageAttachmentsController,
      Map<String, LocalImageAttachment>
    >((Ref ref) {
      return LocalImageAttachmentsController(
        ref.watch(localImageStorageServiceProvider),
      );
    });

