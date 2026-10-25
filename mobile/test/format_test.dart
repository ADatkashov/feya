import 'package:feya/core/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test(
    'formatMoney groups thousands with non-breaking spaces and the tenge sign',
    () {
      expect(formatMoney(23900), '23 900 ₸');
      expect(formatMoney(0), '0 ₸');
      expect(formatMoney(1234567.4), '1 234 567 ₸');
      expect(formatMoney(999), '999 ₸');
      expect(formatMoney(-4190), '−4 190 ₸');
      expect(formatMoney(100, currency: 'USD'), '100 USD');
    },
  );

  test('formatPhone formats Kazakhstan numbers and leaves others alone', () {
    expect(formatPhone('+77011234567'), '+7 701 123 45 67');
    expect(formatPhone('+447911123456'), '+447911123456');
    expect(formatPhone(null), '');
  });

  test(
    'instants are shown in Almaty time (UTC+5) whatever the device zone',
    () {
      final utc = DateTime.utc(2026, 11, 3, 9, 0);
      expect(formatTime(utc), '14:00');
      expect(formatDateTime(utc, 'en'), 'Nov 3, 14:00');
      // late evening UTC rolls over to the next local day
      expect(
        formatDateTime(DateTime.utc(2026, 11, 3, 20, 30), 'en'),
        'Nov 4, 01:30',
      );
      // date-only (non-UTC) values are not shifted
      expect(formatDate(DateTime(2026, 11, 3), 'en'), 'Nov 3');
    },
  );

  test('shortTime trims seconds', () {
    expect(shortTime('10:00:00'), '10:00');
    expect(shortTime(null), '');
  });
}
