import '../../l10n/app_strings.dart';

class AppDateUtils {
  const AppDateUtils._();

  static const List<String> _thaiMonthsShort = <String>[
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  static const List<String> _thaiMonthsFull = <String>[
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  static const List<String> _enMonthsShort = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _enMonthsFull = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _thaiWeekdays = <String>[
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์',
    'อาทิตย์',
  ];

  static const List<String> _enWeekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static int displayYear(int ceYear, {required bool useBuddhistEra}) {
    return useBuddhistEra ? ceYear + 543 : ceYear;
  }

  /// Returns `YYYY-MM` for API query parameters.
  static String toApiMonth(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// Returns `YYYY-MM-DD` for API date comparisons.
  static String toApiDate(DateTime date) {
    final String y = date.year.toString().padLeft(4, '0');
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses `YYYY-MM` into a `DateTime(year, month, 1)`.
  static DateTime parseApiMonth(String yyyyMm) {
    final List<String> parts = yyyyMm.split('-');
    if (parts.length == 2) {
      final int? y = int.tryParse(parts[0]);
      final int? m = int.tryParse(parts[1]);
      if (y != null && m != null && m >= 1 && m <= 12) {
        return DateTime(y, m, 1);
      }
    }
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Formats a `YYYY-MM` string into a full localized month + year label.
  static String formatMonthYear(
    String yyyyMm, {
    required AppLanguage language,
    required bool useBuddhistEra,
    bool shortMonth = false,
  }) {
    final DateTime dt = parseApiMonth(yyyyMm);
    final int idx = (dt.month - 1).clamp(0, 11);
    final int yr = displayYear(dt.year, useBuddhistEra: useBuddhistEra);
    if (language == AppLanguage.th) {
      final String mName =
          shortMonth ? _thaiMonthsShort[idx] : _thaiMonthsFull[idx];
      final String yStr = shortMonth ? (yr % 100).toString().padLeft(2, '0') : '$yr';
      return '$mName $yStr';
    } else {
      final String mName =
          shortMonth ? _enMonthsShort[idx] : _enMonthsFull[idx];
      final String yStr = shortMonth ? (yr % 100).toString().padLeft(2, '0') : '$yr';
      return '$mName $yStr';
    }
  }

  /// Formats a [DateTime] into a short date string (e.g. `12 พ.ย. 2569` or `12 Nov 2026`).
  static String formatShortDate(
    DateTime dateTime, {
    required AppLanguage language,
    required bool useBuddhistEra,
  }) {
    final DateTime local = dateTime.toLocal();
    final int idx = (local.month - 1).clamp(0, 11);
    final int yr = displayYear(local.year, useBuddhistEra: useBuddhistEra);
    final String mName = language == AppLanguage.th
        ? _thaiMonthsShort[idx]
        : _enMonthsShort[idx];
    return '${local.day} $mName $yr';
  }

  /// Formats a [DateTime] into a full date string (e.g. `12 พฤศจิกายน 2569` or `12 November 2026`).
  static String formatFullDate(
    DateTime dateTime, {
    required AppLanguage language,
    required bool useBuddhistEra,
  }) {
    final DateTime local = dateTime.toLocal();
    final int idx = (local.month - 1).clamp(0, 11);
    final int yr = displayYear(local.year, useBuddhistEra: useBuddhistEra);
    final String mName = language == AppLanguage.th
        ? _thaiMonthsFull[idx]
        : _enMonthsFull[idx];
    return '${local.day} $mName $yr';
  }

  /// Formats a [DateTime] into a date + time string (`12 พ.ย. 2569, 14:30`).
  static String formatDateTime(
    DateTime dateTime, {
    required AppLanguage language,
    required bool useBuddhistEra,
  }) {
    final DateTime local = dateTime.toLocal();
    final String datePart = formatShortDate(
      local,
      language: language,
      useBuddhistEra: useBuddhistEra,
    );
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mm = local.minute.toString().padLeft(2, '0');
    return '$datePart · $hh:$mm';
  }

  /// Formats `HH:mm` from a [DateTime].
  static String formatTimeOnly(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Formats a day section header for grouped transaction lists.
  static String formatDayHeader(
    DateTime dateTime, {
    required AppStrings strings,
    required bool useBuddhistEra,
  }) {
    final DateTime local = dateTime.toLocal();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(local.year, local.month, local.day);
    final int diffDays = today.difference(target).inDays;

    final String shortDate = formatShortDate(
      local,
      language: strings.language,
      useBuddhistEra: useBuddhistEra,
    );

    if (diffDays == 0) {
      return '${strings.today} · $shortDate';
    }
    if (diffDays == 1) {
      return '${strings.yesterday} · $shortDate';
    }

    final int weekdayIdx = (local.weekday - 1).clamp(0, 6);
    final String weekday = strings.isThai
        ? 'วัน${_thaiWeekdays[weekdayIdx]}'
        : _enWeekdays[weekdayIdx];
    return '$weekday · $shortDate';
  }
}
