import 'package:intl/intl.dart';

/// Formats a KZT amount as "23 900 ₸" (non-breaking spaces so the symbol never wraps).
String formatMoney(num amount, {String currency = 'KZT'}) {
  final whole = amount.round();
  final digits = whole.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  final symbol = currency == 'KZT' ? '₸' : currency;
  return '${whole < 0 ? '−' : ''}$buf $symbol';
}

/// Delivery happens in Kazakhstan (UTC+5, no DST), so instants from the API are always shown in that zone
/// regardless of the device's own time zone. Date-only values (local DateTimes) are left untouched.
DateTime toAlmaty(DateTime d) => d.isUtc ? d.add(const Duration(hours: 5)) : d;

String formatTime(DateTime t) => DateFormat('HH:mm').format(toAlmaty(t));

/// "10:00:00" → "10:00".
String shortTime(String? hhmmss) {
  if (hhmmss == null || hhmmss.length < 5) return '';
  return hhmmss.substring(0, 5);
}

String formatDate(DateTime d, String locale) =>
    DateFormat.MMMd(locale).format(toAlmaty(d));

String formatDateLong(DateTime d, String locale) =>
    DateFormat.MMMMEEEEd(locale).format(d);

String formatDateTime(DateTime d, String locale) =>
    '${DateFormat.MMMd(locale).format(toAlmaty(d))}, ${formatTime(d)}';

/// Formats a phone like +7 701 123 45 67 for display.
String formatPhone(String? e164) {
  if (e164 == null) return '';
  final d = e164.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length == 11 && d.startsWith('7')) {
    return '+7 ${d.substring(1, 4)} ${d.substring(4, 7)} ${d.substring(7, 9)} ${d.substring(9)}';
  }
  return e164;
}
