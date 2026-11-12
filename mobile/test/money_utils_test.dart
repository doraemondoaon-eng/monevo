import 'package:flutter_test/flutter_test.dart';
import 'package:monevo/core/utils/money_utils.dart';

void main() {
  group('MoneyUtils.formatSatang', () {
    test('formats standard satang values to THB with commas and 2 decimals', () {
      expect(MoneyUtils.formatSatang(0), '฿0.00');
      expect(MoneyUtils.formatSatang(75), '฿0.75');
      expect(MoneyUtils.formatSatang(150075), '฿1,500.75');
      expect(MoneyUtils.formatSatang(123456789), '฿1,234,567.89');
    });

    test('formats negative and signed satang values accurately', () {
      expect(MoneyUtils.formatSatang(-150075), '-฿1,500.75');
      expect(
        MoneyUtils.formatSatang(150075, showPlusSign: true),
        '+฿1,500.75',
      );
      expect(
        MoneyUtils.formatSatang(0, showPlusSign: true),
        '฿0.00',
      );
    });

    test('supports hiding .00 when alwaysShowDecimals is false', () {
      expect(
        MoneyUtils.formatSatang(150000, alwaysShowDecimals: false),
        '฿1,500',
      );
      expect(
        MoneyUtils.formatSatang(150050, alwaysShowDecimals: false),
        '฿1,500.50',
      );
    });
  });

  group('MoneyUtils.parseToSatang', () {
    test('parses valid user inputs to integer satang without floats', () {
      expect(MoneyUtils.parseToSatang('1500.75'), 150075);
      expect(MoneyUtils.parseToSatang('1,500.75'), 150075);
      expect(MoneyUtils.parseToSatang('฿ 2,500'), 250000);
      expect(MoneyUtils.parseToSatang('19.5'), 1950);
      expect(MoneyUtils.parseToSatang('.75'), 75);
      expect(MoneyUtils.parseToSatang('0.01'), 1);
    });

    test('respects allowZero and allowNegative flags', () {
      expect(MoneyUtils.parseToSatang('0'), isNull);
      expect(MoneyUtils.parseToSatang('0', allowZero: true), 0);
      expect(MoneyUtils.parseToSatang('-500.25'), isNull);
      expect(
        MoneyUtils.parseToSatang('-500.25', allowNegative: true),
        -50025,
      );
    });

    test('rejects >2 decimal places and malformed strings', () {
      expect(MoneyUtils.parseToSatang(''), isNull);
      expect(MoneyUtils.parseToSatang('.'), isNull);
      expect(MoneyUtils.parseToSatang('10.123'), isNull);
      expect(MoneyUtils.parseToSatang('10.1.2'), isNull);
      expect(MoneyUtils.parseToSatang('abc'), isNull);
    });
  });

  group('MoneyUtils.toEditableString & formatCompactSatang', () {
    test('converts satang to editable string', () {
      expect(MoneyUtils.toEditableString(150075), '1500.75');
      expect(MoneyUtils.toEditableString(150000), '1500');
      expect(
        MoneyUtils.toEditableString(150000, keepZeroDecimals: true),
        '1500.00',
      );
      expect(MoneyUtils.toEditableString(-50050), '-500.50');
    });

    test('formats compact satang for chart axes', () {
      expect(MoneyUtils.formatCompactSatang(50000), '฿500');
      expect(MoneyUtils.formatCompactSatang(1250000), '฿12.5K');
      expect(MoneyUtils.formatCompactSatang(150000000), '฿1.5M');
    });
  });
}
