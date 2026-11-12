class MoneyUtils {
  const MoneyUtils._();

  static const String defaultSymbol = '฿';

  /// Formats an integer minor-unit amount (satang, where 100 satang = 1 THB)
  /// into a human-readable currency string without using floating-point math.
  ///
  /// Examples:
  /// - `150075` -> `'฿1,500.75'`
  /// - `-150075` -> `'-฿1,500.75'`
  /// - `150075` with `showPlusSign: true` -> `'+฿1,500.75'`
  static String formatSatang(
    int satang, {
    String symbol = defaultSymbol,
    bool showPlusSign = false,
    bool alwaysShowDecimals = true,
  }) {
    final bool isNegative = satang < 0;
    final int absSatang = satang.abs();
    final int baht = absSatang ~/ 100;
    final int remSatang = absSatang % 100;

    final String formattedBaht = _formatWithCommas(baht);
    final String decimalPart = (!alwaysShowDecimals && remSatang == 0)
        ? ''
        : '.${remSatang.toString().padLeft(2, '0')}';

    final String sign = isNegative
        ? '-'
        : (showPlusSign && satang > 0 ? '+' : '');

    return '$sign$symbol$formattedBaht$decimalPart';
  }

  /// Compact formatting for chart axes (e.g. `฿12.5K`, `฿1.2M`).
  static String formatCompactSatang(
    int satang, {
    String symbol = defaultSymbol,
  }) {
    final bool isNegative = satang < 0;
    final int absBaht = satang.abs() ~/ 100;
    final String sign = isNegative ? '-' : '';

    if (absBaht >= 1000000) {
      final int millions = absBaht ~/ 1000000;
      final int tenthMillions = (absBaht % 1000000) ~/ 100000;
      final String suffix = tenthMillions > 0 ? '.$tenthMillions' : '';
      return '$sign$symbol$millions${suffix}M';
    }
    if (absBaht >= 1000) {
      final int thousands = absBaht ~/ 1000;
      final int tenthThousands = (absBaht % 1000) ~/ 100;
      final String suffix = tenthThousands > 0 ? '.$tenthThousands' : '';
      return '$sign$symbol$thousands${suffix}K';
    }
    return '$sign$symbol$absBaht';
  }

  /// Converts integer minor units (satang) to a plain decimal string suitable
  /// for pre-filling an editable input field (e.g., `150075` -> `'1500.75'`,
  /// `150000` -> `'1500'`).
  static String toEditableString(int satang, {bool keepZeroDecimals = false}) {
    final bool isNegative = satang < 0;
    final int absSatang = satang.abs();
    final int baht = absSatang ~/ 100;
    final int remSatang = absSatang % 100;
    final String sign = isNegative ? '-' : '';
    if (remSatang == 0 && !keepZeroDecimals) {
      return '$sign$baht';
    }
    return '$sign$baht.${remSatang.toString().padLeft(2, '0')}';
  }

  /// Parses a user-entered string (e.g. `'1,500.75'`, `'฿250'`, `'.50'`, `'-100.25'`)
  /// into integer minor units (satang) using ONLY integer arithmetic.
  ///
  /// Returns `null` if the input is empty, invalid, has more than 2 decimal
  /// places, or is negative when [allowNegative] is `false`.
  static int? parseToSatang(
    String rawInput, {
    bool allowNegative = false,
    bool allowZero = false,
  }) {
    String cleaned = rawInput
        .trim()
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll('฿', '')
        .replaceAll('THB', '')
        .replaceAll('thb', '');

    if (cleaned.isEmpty) {
      return null;
    }

    bool isNegative = false;
    if (cleaned.startsWith('-')) {
      if (!allowNegative) {
        return null;
      }
      isNegative = true;
      cleaned = cleaned.substring(1);
    } else if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.isEmpty || cleaned == '.') {
      return null;
    }

    final List<String> parts = cleaned.split('.');
    if (parts.length > 2) {
      return null;
    }

    final String wholeStr = parts[0].isEmpty ? '0' : parts[0];
    final String fracStr = parts.length == 2 ? parts[1] : '';

    if (!RegExp(r'^\d+$').hasMatch(wholeStr)) {
      return null;
    }
    if (fracStr.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fracStr)) {
      return null;
    }
    if (fracStr.length > 2) {
      return null;
    }

    final int? wholeBaht = int.tryParse(wholeStr);
    if (wholeBaht == null) {
      return null;
    }

    int fracSatang = 0;
    if (fracStr.length == 1) {
      fracSatang = int.parse(fracStr) * 10;
    } else if (fracStr.length == 2) {
      fracSatang = int.parse(fracStr);
    }

    final int totalSatang = (wholeBaht * 100) + fracSatang;
    final int signedSatang = isNegative ? -totalSatang : totalSatang;

    if (!allowZero && signedSatang == 0) {
      return null;
    }

    return signedSatang;
  }

  static String _formatWithCommas(int nonNegativeValue) {
    final String digits = nonNegativeValue.toString();
    if (digits.length <= 3) {
      return digits;
    }
    final StringBuffer buffer = StringBuffer();
    final int len = digits.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
