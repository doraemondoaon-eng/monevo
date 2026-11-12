import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/storage/local_file_driver_stub.dart';
import 'package:monevo/core/storage/local_image_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocalImageStorageService (Section 3.3)', () {
    late LocalFileDriver driver;
    late LocalImageStorageService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      driver = createPlatformFileDriver();
      service = LocalImageStorageService(prefs: prefs, fileDriver: driver);
    });

    test(
      'copies picked image into private app storage, persists mapping, and reads bytes back',
      () async {
        final Uint8List slipBytes = Uint8List.fromList(<int>[137, 80, 78, 71, 1, 2, 3]);
        final PickedLocalImage picked = PickedLocalImage(
          fileName: 'kbank_slip.png',
          bytes: slipBytes,
        );

        final LocalImageAttachment saved = await service.saveImageForTransaction(
          transactionId: 'tx-1001',
          picked: picked,
        );

        expect(saved.transactionId, 'tx-1001');
        expect(saved.originalFileName, 'kbank_slip.png');
        expect(saved.sizeBytes, slipBytes.length);
        expect(await driver.exists(saved.storedPath), isTrue);

        final Map<String, LocalImageAttachment> mappings =
            await service.loadAllMappings();
        expect(mappings.containsKey('tx-1001'), isTrue);

        final Uint8List? loadedBytes = await service.readAttachmentBytes(saved);
        expect(loadedBytes, equals(slipBytes));
      },
    );

    test(
      'replacing an attached image deletes the previous file from app storage',
      () async {
        final LocalImageAttachment first = await service.saveImageForTransaction(
          transactionId: 'tx-2002',
          picked: PickedLocalImage(
            fileName: 'old_receipt.jpg',
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        );
        expect(await driver.exists(first.storedPath), isTrue);

        final LocalImageAttachment second = await service.saveImageForTransaction(
          transactionId: 'tx-2002',
          picked: PickedLocalImage(
            fileName: 'new_receipt.png',
            bytes: Uint8List.fromList(<int>[4, 5, 6, 7]),
          ),
        );

        expect(await driver.exists(first.storedPath), isFalse);
        expect(await driver.exists(second.storedPath), isTrue);
      },
    );

    test(
      'supports deleting or keeping the local image file when a transaction is deleted',
      () async {
        final LocalImageAttachment first = await service.saveImageForTransaction(
          transactionId: 'tx-delete-file',
          picked: PickedLocalImage(
            fileName: 'slip1.jpg',
            bytes: Uint8List.fromList(<int>[10, 20]),
          ),
        );
        await service.removeAttachmentForTransaction(
          'tx-delete-file',
          deleteLocalFile: true,
        );
        expect(await driver.exists(first.storedPath), isFalse);

        final LocalImageAttachment second = await service.saveImageForTransaction(
          transactionId: 'tx-keep-file',
          picked: PickedLocalImage(
            fileName: 'slip2.jpg',
            bytes: Uint8List.fromList(<int>[30, 40]),
          ),
        );
        await service.removeAttachmentForTransaction(
          'tx-keep-file',
          deleteLocalFile: false,
        );
        expect(await driver.exists(second.storedPath), isTrue);
        final Map<String, LocalImageAttachment> mappings =
            await service.loadAllMappings();
        expect(mappings.containsKey('tx-keep-file'), isFalse);
      },
    );
  });
}

