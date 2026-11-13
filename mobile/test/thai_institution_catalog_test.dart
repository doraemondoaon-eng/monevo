import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/widgets/account_badge.dart';
import 'package:monevo/core/widgets/icon_mapper.dart';
import 'package:monevo/core/widgets/thai_institution_catalog.dart';

void main() {
  group('ThaiInstitutionCatalog integrity & backend compatibility', () {
    test('all entries have unique ids, valid colors, <=80 chars and valid ICON_KEYS', () {
      final Set<String> ids = <String>{};
      final Set<String> storedNames = <String>{};
      final RegExp hexPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
      final Set<String> validIcons = IconMapper.allKeys.toSet();

      expect(ThaiInstitutionCatalog.all.length, greaterThanOrEqualTo(70));

      for (final ThaiInstitution item in ThaiInstitutionCatalog.all) {
        expect(
          ids.add(item.id),
          isTrue,
          reason: 'Duplicate institution id: ${item.id}',
        );
        expect(
          storedNames.add(item.storedName),
          isTrue,
          reason: 'Duplicate storedName: ${item.storedName}',
        );
        expect(
          item.storedName.length,
          lessThanOrEqualTo(80),
          reason: 'storedName exceeds backend 80-char limit: ${item.storedName}',
        );
        expect(
          hexPattern.hasMatch(item.primaryHex),
          isTrue,
          reason: 'Invalid primaryHex for ${item.id}: ${item.primaryHex}',
        );
        expect(
          hexPattern.hasMatch(item.secondaryHex),
          isTrue,
          reason: 'Invalid secondaryHex for ${item.id}: ${item.secondaryHex}',
        );
        if (item.accentHex != null) {
          expect(
            hexPattern.hasMatch(item.accentHex!),
            isTrue,
            reason: 'Invalid accentHex for ${item.id}: ${item.accentHex}',
          );
        }
        expect(
          validIcons.contains(item.fallbackIconKey),
          isTrue,
          reason:
              'Invalid fallbackIconKey for ${item.id}: ${item.fallbackIconKey}',
        );

        // Round-trip lookup via storedName must return the exact institution.
        final ThaiInstitution? resolved = ThaiInstitutionCatalog.match(
          item.storedName,
        );
        expect(
          resolved?.id,
          equals(item.id),
          reason: 'Round-trip match failed for ${item.storedName}',
        );
      }
    });

    test('matches Thai banks, loans, e-wallets, credit cards without collisions', () {
      expect(ThaiInstitutionCatalog.match('กสิกรไทย')?.id, 'kbank');
      expect(ThaiInstitutionCatalog.match('KBANK')?.id, 'kbank');
      expect(ThaiInstitutionCatalog.match('ไทยพาณิชย์')?.id, 'scb');
      expect(ThaiInstitutionCatalog.match('ttb')?.id, 'ttb');
      expect(ThaiInstitutionCatalog.match('ออมสิน')?.id, 'gsb');
      expect(ThaiInstitutionCatalog.match('ธ.ก.ส.')?.id, 'baac');
      expect(ThaiInstitutionCatalog.match('ธอส.')?.id, 'ghb');
      expect(ThaiInstitutionCatalog.match('TrueMoney')?.id, 'truemoney');
      expect(ThaiInstitutionCatalog.match('เป๋าตัง')?.id, 'paotang');
      expect(ThaiInstitutionCatalog.match('KTC')?.id, 'ktc');
      expect(ThaiInstitutionCatalog.match('เฟิร์สช้อยส์')?.id, 'firstchoice');
      expect(ThaiInstitutionCatalog.match('เงินติดล้อ')?.id, 'tidlor');
      expect(ThaiInstitutionCatalog.match('tidlor')?.id, 'tidlor');
      expect(ThaiInstitutionCatalog.match('กยศ.')?.id, 'slf');
      expect(ThaiInstitutionCatalog.match('กยศ')?.id, 'slf');
      expect(ThaiInstitutionCatalog.match('ฟินนิกซ์')?.id, 'finnix');
      expect(ThaiInstitutionCatalog.match('เงินทันเด้อ')?.id, 'moneythunder');
      expect(ThaiInstitutionCatalog.match('LINE BK')?.id, 'linebk');
      expect(ThaiInstitutionCatalog.match('LINE Pay')?.id, 'linepay');
      expect(ThaiInstitutionCatalog.match('วงเงินให้ยืม LINE BK')?.id, 'linebk_loan');
      expect(ThaiInstitutionCatalog.match('SPayLater')?.id, 'spaylater');
      expect(ThaiInstitutionCatalog.match('ShopeePay')?.id, 'shopeepay');

      // Fallback to accountName when institution is blank
      expect(
        ThaiInstitutionCatalog.match(null, accountName: 'บัญชีออมทรัพย์ SCB')?.id,
        'scb',
      );
      // Generic wallet names do not false-match banks
      expect(
        ThaiInstitutionCatalog.match(null, accountName: 'กระเป๋าเงินสด'),
        isNull,
      );
    });
  });

  group('AccountBrandAvatar & ThaiInstitutionPickerSheet widgets', () {
    testWidgets('AccountBrandAvatar renders brand shortLabel when matched and icon fallback when unmatched', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                AccountBrandAvatar(
                  institution: 'กสิกรไทย (KBank)',
                  iconKey: 'account_balance',
                  colorHex: '#138F2D',
                  size: 46,
                ),
                AccountBrandAvatar(
                  institution: null,
                  accountName: 'เงินสดติดตัว',
                  iconKey: 'payments',
                  colorHex: '#10B981',
                  size: 46,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('KBANK'), findsOneWidget);
      expect(find.byIcon(Icons.payments_rounded), findsOneWidget);
    });

    testWidgets('ThaiInstitutionPickerSheet searches and filters loans cleanly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThaiInstitutionPickerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ติดล้อ');
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ThaiInstitutionBadge),
          matching: find.text('ติดล้อ'),
        ),
        findsOneWidget,
      );
      expect(find.text('เงินติดล้อ'), findsOneWidget);
      expect(find.text('KBANK'), findsNothing);
    });
  });
}

