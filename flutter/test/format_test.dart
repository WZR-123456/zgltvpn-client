import 'package:flutter_test/flutter_test.dart';
import 'package:zgltvpn/core/utils/format.dart';

void main() {
  group('Format.bytes', () {
    test('formats small values', () {
      expect(Format.bytes(0), '0 B');
      expect(Format.bytes(512), '512 B');
      expect(Format.bytes(1536), '1.5 KB');
      expect(Format.bytes(1048576), '1.0 MB');
      expect(Format.bytes(10737418240), '10.0 GB');
    });

    test('clamps dirty astronomical values', () {
      expect(Format.bytes(1 << 62), '不限量（数据异常）');
      expect(Format.isDirtyTraffic(1 << 62), isTrue);
      expect(Format.isDirtyTraffic(10737418240), isFalse);
    });

    test('negative values show a dash', () {
      expect(Format.bytes(-1), '—');
    });
  });

  group('Format.trafficGb', () {
    test('formats plan traffic', () {
      expect(Format.trafficGb(10), '10 GB');
      expect(Format.trafficGb(0.5), '0.5 GB');
    });

    test('clamps the 1e+97 dirty value', () {
      expect(Format.trafficGb(1e97), '不限量（数据异常）');
      expect(Format.isDirtyTrafficGb(1e97), isTrue);
      expect(Format.isDirtyTrafficGb(500), isFalse);
    });
  });

  group('Format.expiry', () {
    test('zero means no plan', () {
      expect(Format.expiry(0), '未开通');
      expect(Format.expiry(-5), '未开通');
    });

    test('formats a date', () {
      final ms = DateTime(2026, 12, 24).millisecondsSinceEpoch;
      expect(Format.expiry(ms), '2026/12/24');
    });

    test('daysRemaining counts days', () {
      final future = DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch;
      expect(Format.daysRemaining(future), greaterThanOrEqualTo(29));
      final past = DateTime.now()
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch;
      expect(Format.daysRemaining(past), lessThan(0));
    });
  });

  group('Format.syncTime', () {
    test('formats HH:MM', () {
      expect(Format.syncTime(DateTime(2026, 11, 24, 18, 26)), '18:26');
      expect(Format.syncTime(DateTime(2026, 11, 24, 8, 5)), '08:05');
    });
  });
}
